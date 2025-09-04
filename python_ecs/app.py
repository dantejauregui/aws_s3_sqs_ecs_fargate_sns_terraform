import os, json, time, logging, io, sys
from urllib.parse import unquote_plus
import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
from PIL import Image

# ---------- Config via env vars ----------
QUEUE_URL = os.environ["QUEUE_URL"]                    # e.g. https://sqs.eu-central-1.amazonaws.com/123456789012/image-processing-queue
BUCKET     = os.environ["BUCKET"]                      # e.g. image-upload-bucket-xxxxxx
THUMB_PREFIX = os.environ.get("THUMB_PREFIX", "thumbnails/")
UPLOADS_PREFIX = os.environ.get("UPLOADS_PREFIX", "uploads/")
THUMB_MAX_WIDTH = int(os.environ.get("THUMB_MAX_WIDTH", "512"))  # px
WAIT_TIME_SECONDS = int(os.environ.get("WAIT_TIME_SECONDS", "20"))  # SQS long poll
MAX_MESSAGES = int(os.environ.get("MAX_MESSAGES", "1"))
VISIBILITY_BUFFER = int(os.environ.get("VISIBILITY_BUFFER", "30"))  # safety seconds

# Optional: SNS notify
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")

# ---------- Clients ----------
session = boto3.session.Session()
region = session.region_name or os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION", "eu-central-1")

cfg = Config(retries={"max_attempts": 10, "mode": "standard"})
s3  = boto3.client("s3", config=cfg, region_name=region)
sqs = boto3.client("sqs", config=cfg, region_name=region)
sns = boto3.client("sns", config=cfg, region_name=region) if SNS_TOPIC_ARN else None

# ---------- Logging ----------
logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("worker")
# ---------- 


def derive_thumb_key(orig_key: str) -> str:
    # keep path, swap prefix "uploads/"→"thumbnails/", preserve filename+ext
    if orig_key.startswith(UPLOADS_PREFIX):
        tail = orig_key[len(UPLOADS_PREFIX):]
    else:
        tail = orig_key
    return f"{THUMB_PREFIX}{tail}"

def object_exists(bucket, key) -> bool:
    try:
        s3.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] in ("404", "NotFound"):
            return False
        raise

def make_thumbnail(image_bytes: bytes, max_width: int) -> (bytes, str):
    with Image.open(io.BytesIO(image_bytes)) as img:
        img_format = (img.format or "JPEG").upper()
        # Convert mode to avoid issues saving PNG/JPEG
        if img.mode not in ("RGB", "RGBA"):
            img_converted = img.convert("RGB")
        else:
            img_converted = img

        w, h = img_converted.size
        if w > max_width:
            new_h = int(h * (max_width / float(w)))
            img_converted = img_converted.resize((max_width, new_h), Image.LANCZOS)

        out = io.BytesIO()
        save_format = "JPEG" if img_format not in ("JPEG", "PNG", "WEBP") else img_format
        params = {}
        if save_format == "JPEG":
            params["quality"] = 85
            params["optimize"] = True
        img_converted.save(out, format=save_format, **params)
        out.seek(0)
        content_type = {
            "JPEG": "image/jpeg",
            "PNG": "image/png",
            "WEBP": "image/webp"
        }.get(save_format, "application/octet-stream")
        return out.read(), content_type


# Method that call the other above methods:
def process_message(msg):
    body = msg["Body"]
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        log.warning("Message body is not JSON; skipping: %s", body)
        return False

    bucket = payload.get("bucket") or BUCKET
    key    = payload.get("key")
    if not key:
        log.warning("Message missing 'key': %s", body)
        return False

    # S3 event keys can be URL-encoded; normalize
    key = unquote_plus(key)

    # Only process uploads prefix (guardrail)
    if UPLOADS_PREFIX and not key.startswith(UPLOADS_PREFIX):
        log.info("Key not in uploads prefix, skipping: %s", key)
        return True  # don't retry

    thumb_key = derive_thumb_key(key)
    if object_exists(bucket, thumb_key):
        log.info("Thumbnail already exists, skipping: s3://%s/%s", bucket, thumb_key)
        return True

    log.info("Downloading s3://%s/%s", bucket, key)
    try:
        obj = s3.get_object(Bucket=bucket, Key=key)
        data = obj["Body"].read()
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code in ("NoSuchKey", "404", "NotFound"):
            log.warning("Original not found, skipping: s3://%s/%s", bucket, key)
            return True  # permanent
        log.exception("S3 get_object failed")
        return False     # transient → retry

    try:
        thumb_bytes, content_type = make_thumbnail(data, THUMB_MAX_WIDTH)
    except Exception:
        log.exception("Thumbnail generation failed")
        return False

    log.info("Uploading thumbnail to s3://%s/%s", bucket, thumb_key)
    try:
        s3.put_object(
            Bucket=bucket,
            Key=thumb_key,
            Body=thumb_bytes,
            ContentType=content_type,
            # Uncomment if your bucket enforces KMS:
            # ServerSideEncryption="aws:kms",
            # SSEKMSKeyId=os.environ.get("S3_KMS_KEY_ID"),
        )
    except ClientError:
        log.exception("S3 put_object failed")
        return False

    if sns and SNS_TOPIC_ARN:
        try:
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=json.dumps({"bucket": bucket, "key": key, "thumbnail": thumb_key}),
                Subject="Image processed",
            )
        except Exception:
            log.exception("SNS publish failed (non-fatal)")

    log.info("Done: %s -> %s", key, thumb_key)
    return True

def main_loop():
    log.info("Worker started. queue=%s bucket=%s region=%s", QUEUE_URL, BUCKET, region)
    while True:
        resp = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=MAX_MESSAGES,
            WaitTimeSeconds=WAIT_TIME_SECONDS,
            VisibilityTimeout=WAIT_TIME_SECONDS + VISIBILITY_BUFFER,  # small buffer
        )
        msgs = resp.get("Messages", [])
        if not msgs:
            continue

        for m in msgs:
            receipt = m["ReceiptHandle"]
            ok = False
            try:
                ok = process_message(m)
            except Exception:
                log.exception("Unhandled error while processing message")

            if ok:
                try:
                    sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=receipt)
                    log.info("Message deleted")
                except Exception:
                    log.exception("Failed to delete message (will retry later)")

if __name__ == "__main__":
    try:
        main_loop()
    except KeyboardInterrupt:
        log.info("Shutting down")
