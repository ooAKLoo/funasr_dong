#!/usr/bin/env python3
"""
WebSocket FunASR 测试脚本
测试SenseVoice模型的语音识别功能
"""

import asyncio
import websockets
import json
import base64
import wave
import os
from pathlib import Path

# 配置
WEBSOCKET_URL = "ws://localhost:1758"
TEST_AUDIO_PATH = "/Users/yangdongju/Desktop/code_project/pc/Ohoo/python-service/models/models/iic/SenseVoiceSmall/example/zh.mp3"

async def test_websocket_asr():
    """测试WebSocket ASR服务"""
    
    # 检查测试音频文件
    if not os.path.exists(TEST_AUDIO_PATH):
        print(f"❌ 测试音频文件不存在: {TEST_AUDIO_PATH}")
        print("💡 请指定一个有效的音频文件路径")
        return
    
    try:
        print("🔗 连接到WebSocket服务器...")
        async with websockets.connect(WEBSOCKET_URL) as websocket:
            print(f"✅ 已连接到: {WEBSOCKET_URL}")
            
            # 读取音频文件
            print(f"📁 读取音频文件: {TEST_AUDIO_PATH}")
            with open(TEST_AUDIO_PATH, "rb") as f:
                audio_data = f.read()
            
            # 编码音频数据
            audio_base64 = base64.b64encode(audio_data).decode('utf-8')
            
            # 构建消息
            message = {
                "mode": "offline",  # 离线模式
                "wav_name": "test_audio",
                "wav_format": "mp3",
                "is_speaking": True,
                "audio_fs": 16000,
                "svs_lang": "auto",  # SenseVoice语言自动检测
                "svs_itn": True,     # SenseVoice ITN
                "chunk_size": [5, 10, 5],
                "audio": audio_base64
            }
            
            print("📤 发送音频数据...")
            await websocket.send(json.dumps(message))
            
            # 发送结束标志
            end_message = {
                "is_speaking": False
            }
            await websocket.send(json.dumps(end_message))
            
            print("⏳ 等待识别结果...")
            
            # 接收识别结果
            while True:
                try:
                    response = await asyncio.wait_for(websocket.recv(), timeout=30)
                    result = json.loads(response)
                    
                    print("📝 收到响应:")
                    print(f"   消息类型: {result.get('mode', 'unknown')}")
                    
                    if 'text' in result:
                        print(f"   识别结果: {result['text']}")
                    
                    if 'timestamp' in result:
                        print(f"   时间戳: {result['timestamp']}")
                    
                    if result.get('is_final', False):
                        print("✅ 识别完成!")
                        break
                        
                except asyncio.TimeoutError:
                    print("⏰ 等待超时")
                    break
                except websockets.exceptions.ConnectionClosed:
                    print("🔌 连接已关闭")
                    break
    
    except ConnectionRefusedError:
        print("❌ 连接被拒绝")
        print("💡 请确保WebSocket服务器正在运行")
        print("💡 运行命令: ./run_websocket.sh")
    
    except Exception as e:
        print(f"❌ 发生错误: {e}")

def test_simple_client():
    """简单的测试客户端"""
    print("🎤 FunASR WebSocket 测试客户端")
    print("=" * 50)
    
    # 检查服务器是否运行
    print("🔍 检查服务器状态...")
    
    # 运行异步测试
    asyncio.run(test_websocket_asr())

if __name__ == "__main__":
    test_simple_client()