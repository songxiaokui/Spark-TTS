ENV_NAME ?= my_sparktts
MODEL_DIR ?= pretrained_models
Model ?= cpu
ARCH ?= linux/amd64

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

.PHONY: cli
cli:  ## 命令行调用
	@( \
        . $$(conda info --base)/etc/profile.d/conda.sh && \
        conda activate $(ENV_NAME) && \
        python -m cli.inference --text "文王序《易》，以乾坤为首。孔子系之曰：“天尊地卑，乾坤定矣，卑高以陈，贵贱位矣。”言君臣之位，犹天地之不可易也。《春秋》抑诸侯，尊周室，王人虽微，序于诸侯之上，以是见圣人于君臣之际，未尝不惓惓也。非有桀、纣之暴，汤、武之仁，人归之，天命之，君臣之分，当守节伏死而已矣。是故以微子而代纣，则成汤配天矣；以季札而君吴，则太伯血食矣。然二子宁亡国而不为者，诚以礼之大节不可乱也。故曰：礼莫大于分也" --device 0 --save_dir ./example/results --model_dir pretrained_models/Spark-TTS-0.5B --prompt_text "朕，登基了17年了，朕，负过的人不少，负朕的人更多。朕非亡国之君，为何世事皆为亡国之相，斩杀袁崇焕的时候朕只有18岁，自毁长城也好，刚愎自用也罢，朕要做中兴之主，不料成为亡国之君，你要朕认什么错。崇祯愧对列祖列宗！"  --prompt_speech_path "src/demos/Erebus/chongzheng_zh.wav" \
    )

.PHONY: build
build:  ## 构建服务
	@echo "build web server..."
	@echo "build with $(Model) support..."
	@docker build -t sparktts:v0.1.0-$(Model) --platform $(ARCH) --build-arg TARGET_STAGE=$(Model) -f Dockerfile .

.PHONY: run
run:  ## 运行服务
	@echo "running server..."
	@cd $(CURDIR) && docker-compose up -d

help:
	@awk -F ':|##' '/^[^\t].+?:.*?##/ {\
		printf "\033[36m%-30s\033[0m \033[31m%s\033[0m\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)
.DEFAULT_GOAL=help
.PHONY=help
