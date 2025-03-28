FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    git-lfs \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Install PyTorch CPU version
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Copy application code
COPY . .

# Set environment variables
ENV MODEL_DIR=/app/pretrained_models
ENV ENV_NAME=sparktts

# Default command
CMD ["python", "web_server.py"]