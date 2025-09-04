# Terraform Part:
Inside the `Terraform folder`, you can run the AWS Infrastructure using:
```
terraform init
terraform plan
terraform apply
```

And to destroy:
```
terraform destroy
```


# Architecture
Initially was planned to use ALB load balancer, but now will be omited/commented due to:
**This worker doesn’t accept inbound HTTP**: for a queue-driven worker (poll SQS → read/write S3), an ALB isn’t needed because nothing on the internet (or your VPC) needs to call into the task. The task only makes outbound calls (to SQS/S3). So we can drop the ALB wiring and simplify.


# Docker image for ECS
First go to the `cd python_ecs` folder and then we build a multi arch image using the following commands and push it to DockerHub:

```
docker buildx create --name multi --use
docker buildx inspect --bootstrap
```

```
export DOCKERHUB_USER="<our_dockerhub_username>"
export IMAGE="image-processor"
export TAG="1.0.0"

docker buildx build \
  --platform linux/amd64,linux/arm64/v8 \
  -t ${DOCKERHUB_USER}/${IMAGE}:${TAG} \
  -t ${DOCKERHUB_USER}/${IMAGE}:latest \
  --push .
```


Testing using temporal SKIP of Eventbridge issue:
Please use:
```
aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{"bucket":"<YOUR-BUCKET-NAME>","key":"uploads/brand1.jpg"}'
```