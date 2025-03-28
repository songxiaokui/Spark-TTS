ARG TARGET_STAGE=cpu
# ----- base -----
FROM python:3.12-slim as base

WORKDIR /app

RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# ----- CPU stage -----
FROM base as cpu
RUN pip install -r requirements.txt && \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# ----- GPU stage -----
FROM nvidia/cuda:12.3.1-runtime-ubuntu22.04 as gpu

RUN apt-get update && apt-get install -y \
    python3.12 \
    python3-pip \
    ffmpeg \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt && \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# ----- Final stage -----
FROM ${TARGET_STAGE} as final

WORKDIR /app
COPY . .

ENV MODEL_DIR=/app/pretrained_models
ENV ENV_NAME=sparktts

CMD ["python", "web_server.py"]