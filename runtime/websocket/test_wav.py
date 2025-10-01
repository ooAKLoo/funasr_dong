#!/usr/bin/env python3
import asyncio
import websockets
import json
import ssl
from pydub import AudioSegment

WEBSOCKET_URL = "wss://localhost:1758"
TEST_AUDIO_PATH = "/Users/yangdongju/Downloads/录音记录_20250928_0006.wav"

async def test_wav_file():
    print("🎤 测试FunASR WebSocket - 正确协议版本")
    
    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE
    
    try:
        async with websockets.connect(WEBSOCKET_URL, ssl=ssl_context) as websocket:
            print("✅ 连接成功")
            
            # 1. 用pydub加载WAV并转换为标准PCM
            print("🔄 加载WAV并标准化...")
            audio = AudioSegment.from_wav(TEST_AUDIO_PATH)
            audio = audio.set_frame_rate(16000).set_channels(1)
            pcm_data = audio.raw_data
            
            print(f"📊 PCM: {len(pcm_data)} bytes, {len(pcm_data)/32000:.1f}s")
            
            # 2. 发送元数据（不含音频数据）
            metadata = {
                "wav_name": "test",
                "wav_format": "pcm",
                "audio_fs": 16000,
                "is_speaking": True,
                "itn": True,
                "hotwords": "{}"
            }
            print("📤 发送元数据...")
            await websocket.send(json.dumps(metadata))
            
            # 3. 发送二进制PCM数据
            print("📤 发送二进制PCM数据...")
            await websocket.send(pcm_data)
            
            # 4. 发送结束标志
            print("📤 发送结束标志...")
            await websocket.send(json.dumps({"is_speaking": False}))
            
            print("⏳ 等待结果...")
            
            async for response in websocket:
                result = json.loads(response)
                
                if 'text' in result and result['text']:
                    print(f"✅ 识别: {result['text']}")
                
                if result.get('is_final') or result.get('mode') == 'offline':
                    print("✅ 完成")
                    break
    
    except Exception as e:
        print(f"❌ 错误: {e}")

if __name__ == "__main__":
    asyncio.run(test_wav_file())