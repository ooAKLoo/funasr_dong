#!/usr/bin/env python3
"""
性能测试脚本：对比云端服务和本地C++服务的处理速度
"""

import requests
import time
import json
import argparse
import statistics
from pathlib import Path
from tabulate import tabulate

class ServiceBenchmark:
    def __init__(self):
        self.cloud_url = "http://115.190.136.178:8001"
        self.local_url = "http://localhost:10095"
        
    def test_cloud_service(self, audio_file):
        """测试云端服务"""
        try:
            with open(audio_file, 'rb') as f:
                audio_data = f.read()
            
            # 准备请求
            files = {'file': (Path(audio_file).name, audio_data, 'audio/wav')}
            data = {
                'language': 'auto',
                'use_itn': 'true'
            }
            
            # 记录开始时间
            start_time = time.time()
            
            # 发送请求
            response = requests.post(
                f"{self.cloud_url}/transcribe/normal",
                files=files,
                data=data,
                timeout=60
            )
            
            # 记录结束时间
            end_time = time.time()
            total_time = (end_time - start_time) * 1000  # 转换为毫秒
            
            if response.status_code == 200:
                result = response.json()
                return {
                    'success': True,
                    'total_time': total_time,
                    'text': result.get('text', ''),
                    'server_time': result.get('processing_time_ms', None)
                }
            else:
                return {
                    'success': False,
                    'error': f"HTTP {response.status_code}: {response.text}",
                    'total_time': total_time
                }
                
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'total_time': None
            }
    
    def test_local_service(self, audio_file):
        """测试本地C++服务"""
        try:
            with open(audio_file, 'rb') as f:
                audio_data = f.read()
            
            # 准备请求
            files = {'file': (Path(audio_file).name, audio_data, 'audio/wav')}
            data = {
                'wav_format': 'wav',
                'itn': 'true',
                'audio_fs': '16000',
                'svs_lang': 'auto',
                'svs_itn': 'true'
            }
            
            # 记录开始时间
            start_time = time.time()
            
            # 发送请求
            response = requests.post(
                f"{self.local_url}/transcribe/normal",
                files=files,
                data=data,
                timeout=60
            )
            
            # 记录结束时间
            end_time = time.time()
            total_time = (end_time - start_time) * 1000  # 转换为毫秒
            
            if response.status_code == 200:
                result = response.json()
                return {
                    'success': True,
                    'total_time': total_time,
                    'text': result.get('text', ''),
                    'server_time': result.get('processing_time_ms', None)
                }
            else:
                return {
                    'success': False,
                    'error': f"HTTP {response.status_code}: {response.text}",
                    'total_time': total_time
                }
                
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'total_time': None
            }
    
    def run_benchmark(self, audio_file, iterations=5):
        """运行基准测试"""
        print(f"\n🎯 性能测试开始")
        print(f"📁 测试音频: {audio_file}")
        print(f"🔄 测试次数: {iterations}")
        print("-" * 60)
        
        # 检查文件是否存在
        if not Path(audio_file).exists():
            print(f"❌ 错误：音频文件不存在: {audio_file}")
            return
        
        # 获取文件信息
        file_size = Path(audio_file).stat().st_size
        print(f"📊 文件大小: {file_size:,} bytes ({file_size/1024:.1f} KB)")
        print("-" * 60)

        # 测试本地服务
        print("\n💻 测试本地C++服务...")
        local_times = []
        local_results = []
        local_success = 0
        
        for i in range(iterations):
            print(f"  第 {i+1}/{iterations} 次测试...", end='', flush=True)
            result = self.test_local_service(audio_file)
            local_results.append(result)
            
            if result['success']:
                local_success += 1
                local_times.append(result['total_time'])
                print(f" ✅ {result['total_time']:.1f}ms")
            else:
                print(f" ❌ {result['error']}")
        
        # 测试云端服务
        print("\n☁️  测试云端服务...")
        cloud_times = []
        cloud_results = []
        cloud_success = 0
        
        for i in range(iterations):
            print(f"  第 {i+1}/{iterations} 次测试...", end='', flush=True)
            result = self.test_cloud_service(audio_file)
            cloud_results.append(result)
            
            if result['success']:
                cloud_success += 1
                cloud_times.append(result['total_time'])
                print(f" ✅ {result['total_time']:.1f}ms")
            else:
                print(f" ❌ {result['error']}")
        
        # 显示结果
        print("\n" + "=" * 60)
        print("📊 测试结果汇总")
        print("=" * 60)
        
        # 准备表格数据
        table_data = []
        
        # 云端服务统计
        if cloud_times:
            cloud_avg = statistics.mean(cloud_times)
            cloud_min = min(cloud_times)
            cloud_max = max(cloud_times)
            cloud_std = statistics.stdev(cloud_times) if len(cloud_times) > 1 else 0
            table_data.append([
                "☁️  云端服务",
                f"{cloud_success}/{iterations}",
                f"{cloud_avg:.1f}",
                f"{cloud_min:.1f}",
                f"{cloud_max:.1f}",
                f"{cloud_std:.1f}"
            ])
        else:
            table_data.append([
                "☁️  云端服务",
                f"{cloud_success}/{iterations}",
                "N/A", "N/A", "N/A", "N/A"
            ])
        
        # 本地服务统计
        if local_times:
            local_avg = statistics.mean(local_times)
            local_min = min(local_times)
            local_max = max(local_times)
            local_std = statistics.stdev(local_times) if len(local_times) > 1 else 0
            table_data.append([
                "💻 本地服务",
                f"{local_success}/{iterations}",
                f"{local_avg:.1f}",
                f"{local_min:.1f}",
                f"{local_max:.1f}",
                f"{local_std:.1f}"
            ])
        else:
            table_data.append([
                "💻 本地服务",
                f"{local_success}/{iterations}",
                "N/A", "N/A", "N/A", "N/A"
            ])
        
        # 打印表格
        headers = ["服务", "成功率", "平均(ms)", "最小(ms)", "最大(ms)", "标准差"]
        print(tabulate(table_data, headers=headers, tablefmt="grid"))
        
        # 性能对比
        if cloud_times and local_times:
            cloud_avg = statistics.mean(cloud_times)
            local_avg = statistics.mean(local_times)
            
            print(f"\n📈 性能对比:")
            if local_avg < cloud_avg:
                speedup = cloud_avg / local_avg
                print(f"   本地服务比云端服务快 {speedup:.2f}x")
                print(f"   节省时间: {cloud_avg - local_avg:.1f}ms ({(cloud_avg - local_avg)/cloud_avg*100:.1f}%)")
            else:
                speedup = local_avg / cloud_avg
                print(f"   云端服务比本地服务快 {speedup:.2f}x")
                print(f"   节省时间: {local_avg - cloud_avg:.1f}ms ({(local_avg - cloud_avg)/local_avg*100:.1f}%)")
        
        # 显示识别结果（只显示第一次成功的结果）
        print(f"\n📝 识别结果对比:")
        cloud_text = next((r['text'] for r in cloud_results if r['success']), "N/A")
        local_text = next((r['text'] for r in local_results if r['success']), "N/A")
        
        print(f"   云端服务: {cloud_text}")
        print(f"   本地服务: {local_text}")
        
        if cloud_text != "N/A" and local_text != "N/A" and cloud_text != local_text:
            print("   ⚠️  注意：两个服务的识别结果不同")

def main():
    parser = argparse.ArgumentParser(description="对比云端和本地语音识别服务性能")
    parser.add_argument("--file", "-f", required=True, help="测试音频文件路径")
    parser.add_argument("--iterations", "-n", type=int, default=5, 
                       help="每个服务测试次数 (默认: 5)")
    parser.add_argument("--cloud-url", help="云端服务URL (默认: http://115.190.136.178:8001)")
    parser.add_argument("--local-url", help="本地服务URL (默认: http://localhost:10095)")
    
    args = parser.parse_args()
    
    # 创建测试实例
    benchmark = ServiceBenchmark()
    
    # 自定义URL
    if args.cloud_url:
        benchmark.cloud_url = args.cloud_url
    if args.local_url:
        benchmark.local_url = args.local_url
    
    # 运行测试
    benchmark.run_benchmark(args.file, args.iterations)

if __name__ == "__main__":
    # 如果没有命令行参数，使用默认测试
    import sys
    if len(sys.argv) == 1:
        print("📊 语音识别服务性能对比测试")
        print("=" * 60)
        print("\n使用方法:")
        print("  python benchmark_services.py --file <音频文件>")
        print("\n示例:")
        print("  python benchmark_services.py --file test.wav")
        print("  python benchmark_services.py --file test.wav --iterations 10")
        print("\n可选参数:")
        print("  --iterations, -n  : 测试次数 (默认: 5)")
        print("  --cloud-url      : 自定义云端服务URL")
        print("  --local-url      : 自定义本地服务URL")
        print("\n默认测试:")
        
        # 使用默认音频文件进行测试
        default_audio = "/Users/yangdongju/Desktop/apps/ohoo/testdata/录音记录_20250928_0006.wav"
        if Path(default_audio).exists():
            print(f"  使用默认音频: {default_audio}")
            benchmark = ServiceBenchmark()
            benchmark.run_benchmark(default_audio, iterations=3)
        else:
            print("  ❌ 默认测试音频不存在，请使用 --file 参数指定音频文件")
    else:
        main()