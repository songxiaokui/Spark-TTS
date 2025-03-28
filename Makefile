ENV_NAME ?= my_sparktts
MODEL_DIR ?= pretrained_models

.PHONY: env
env:  ## 初始化环境
	@conda env list | grep -q "$(ENV_NAME)" || ( \
        echo "Creating conda environment: $(ENV_NAME)" && \
        conda create -n $(ENV_NAME) -y python=3.12 && \
        echo "Installing requirements" && \
        . $$(conda info --base)/etc/profile.d/conda.sh && \
        conda activate $(ENV_NAME) && \
        pip install -r requirements.txt \
    )
	@echo "Environment $(ENV_NAME) is ready"
	@echo "Checking gradio version..."
	@( \
        . $$(conda info --base)/etc/profile.d/conda.sh && \
        conda activate $(ENV_NAME) && \
        if ! pip show gradio | grep -q "Version: 3.41.2"; then \
            echo "Gradio version is not 3.41.2, downgrading..." && \
            pip uninstall gradio gradio-client -y && \
            pip install gradio==3.41.2; \
        else \
            echo "Gradio is already at version 3.41.2"; \
        fi \
    )
	@echo "Checking git-lfs installation..."
	@command -v git-lfs >/dev/null 2>&1 || ( \
        echo "git-lfs not found, installing via Homebrew..." && \
        brew install git-lfs \
    )
	@echo "Checking ffmpeg installation..."
	@command -v ffmpeg >/dev/null 2>&1 || ( \
        echo "ffmpeg not found, installing via Homebrew..." && \
        brew install ffmpeg \
    )
	@echo "Checking architecture for PyTorch installation..."
	@( \
        . $$(conda info --base)/etc/profile.d/conda.sh && \
        conda activate $(ENV_NAME) && \
        if uname -m | grep -q "arm\|aarch64|arm64"; then \
            echo "ARM architecture detected, installing PyTorch for CPU..." && \
            pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu; \
        else \
            echo "Non-ARM architecture detected, skipping custom PyTorch installation"; \
        fi \
    )
	@echo "Environment setup complete"

.PHONY: download_model
download_model:  ## 下载大模型
	@echo "check model..."
	@if [ ! -d "$(CURDIR)/$(MODEL_DIR)" ]; then \
  		echo "model is not exist, downloading..."; \
  		git lfs install; \
		git clone https://huggingface.co/SparkAudio/Spark-TTS-0.5B $(MODEL_DIR)/Spark-TTS-0.5B; \
  	 fi
	@echo "check model finished"

.PHONY: test
test:  ## 测试运行
	@echo "运行测试案例"
	@( \
        . $$(conda info --base)/etc/profile.d/conda.sh && \
        conda activate $(ENV_NAME) && \
        cd $(CURDIR)/example  && \
        chmod +x infer.sh  && \
        ./infer.sh \
    )

.PHONY: gui
gui:  ## 运行web页面
	@( \
        . $$(conda info --base)/etc/profile.d/conda.sh && \
        conda activate $(ENV_NAME) && \
        echo "servers running: http://127.0.0.1:8999" && \
        python webui.py --device 0 --server_name 0.0.0.0 --server_port 8999 \
    )
	@echo "web页面运行结束"

help:
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m \033[31m%s\033[0m\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.DEFAULT_GOAL=help
.PHONY=help
