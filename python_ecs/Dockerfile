FROM public.ecr.aws/docker/library/python:3.11-slim

# System deps for Pillow (JPEG/PNG/WebP)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libjpeg62-turbo-dev zlib1g-dev libpng-dev libwebp-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Run as non-root (best practice)
RUN useradd -m appuser
USER appuser

# The worker loops forever
CMD ["python", "app.py"]
