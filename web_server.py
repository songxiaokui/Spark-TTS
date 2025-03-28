import sys
import os

# Add project root to system path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from flask import Flask, request, send_file, Response
import torch
import soundfile as sf
from datetime import datetime
import platform
from cli.SparkTTS import SparkTTS

app = Flask(__name__)


# 初始化TTS模型
def init_model(model_dir):
    if platform.system() == "Darwin" and torch.backends.mps.is_available():
        device = torch.device("mps:0")
    elif torch.cuda.is_available():
        device = torch.device("cuda:0")
    else:
        device = torch.device("cpu")

    return SparkTTS(model_dir, device)


# 全局变量存储模型实例
model_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pretrained_models/Spark-TTS-0.5B")
if not os.path.exists(model_dir):
    raise ValueError(f"预训练模型目录不存在: {model_dir}")
model = init_model(model_dir)


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

        # 设置默认的prompt音频路径
        prompt_speech_path = os.path.join(os.getcwd(), 'src', 'demos', 'zhongli', 'zhongli_en.wav')

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


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8887)
