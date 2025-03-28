import sys
import os

# Add project root to system path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import soundfile as sf
import torch
import platform
from flask import Flask, request, send_file, Response
from datetime import datetime
from cli.SparkTTS import SparkTTS

app = Flask(__name__)


# 自定义 CORS 中间件
@app.after_request
def add_cors_headers(response):
    # 允许所有来源访问
    response.headers['Access-Control-Allow-Origin'] = '*'
    # 允许的请求方法
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    # 允许的请求头
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    return response


# 初始化TTS模型
def init_model(model_dir):
    if platform.system() == "Darwin" and torch.backends.mps.is_available():
        device = torch.device("mps:0")
    elif torch.cuda.is_available():
        device = torch.device("cuda:0")
    else:
        device = torch.device("cpu")

    return SparkTTS(model_dir, device)


# 获取可用的模型列表
def get_available_models():
    demos_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src/demos")
    models = []
    for item in os.listdir(demos_dir):
        if os.path.isdir(os.path.join(demos_dir, item)):
            models.append(item)
    return models


# 全局变量存储模型实例和模型列表
model_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pretrained_models/Spark-TTS-0.5B")
if not os.path.exists(model_dir):
    raise ValueError(f"预训练模型目录不存在: {model_dir}")
model = init_model(model_dir)
AVAILABLE_MODELS = get_available_models()


@app.route('/api/v1/generate', methods=['POST'])
def generate():
    try:
        data = request.get_json()
        if not data or 'content' not in data:
            return {'error': 'Missing content parameter'}, 400

        text = data['content']
        model_type = data.get('model_type', 'default')

        # 确保保存目录存在
        save_dir = os.path.join(os.getcwd(), 'example', 'results')
        os.makedirs(save_dir, exist_ok=True)

        # 生成唯一的文件名
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        save_path = os.path.join(save_dir, f"{timestamp}.wav")

        # 根据model_type选择对应的prompt音频
        if model_type not in AVAILABLE_MODELS:
            return {'error': f'Invalid model_type. Available models: {AVAILABLE_MODELS}'}, 400

        # 获取对应模型的音频文件
        model_dir = os.path.join(os.getcwd(), 'src', 'demos', model_type)
        audio_files = [f for f in os.listdir(model_dir) if f.endswith('.wav')]
        if not audio_files:
            return {'error': f'No audio file found for model: {model_type}'}, 500
        prompt_speech_path = os.path.join(model_dir, audio_files[0])

        # 执行语音生成
        with torch.no_grad():
            wav = model.inference(
                text,
                prompt_speech_path=prompt_speech_path,
                prompt_text=None
            )
            sf.write(save_path, wav, samplerate=16000)

        # 以流式方式返回生成的音频文件
        def generate_file():
            with open(save_path, 'rb') as f:
                while True:
                    chunk = f.read(8192)
                    if not chunk:
                        break
                    yield chunk
            # 清理临时文件
            os.remove(save_path)

        return Response(
            generate_file(),
            mimetype='audio/wav',
            headers={
                'Content-Disposition': f'attachment; filename={timestamp}.wav'
            }
        )

    except Exception as e:
        return {'error': str(e)}, 500


@app.route('/api/v1/models', methods=['GET'])
def get_models():
    try:
        return {'models': AVAILABLE_MODELS}
    except Exception as e:
        return {'error': str(e)}, 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8887)
