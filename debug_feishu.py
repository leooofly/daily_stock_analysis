# -*- coding: utf-8 -*-
import os
import sys
import time
import logging
import threading

# 确保能导入 src 模块
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("FeishuDebug")

def mask_secret(secret):
    if not secret:
        return "Not Set"
    if len(secret) < 6:
        return "*" * len(secret)
    return secret[:3] + "*" * (len(secret) - 6) + secret[-3:]

def main():
    print("="*50)
    print("Feishu Bot Diagnostic Tool (Docker compatible)")
    print("="*50)

    try:
        from src.config import get_config, setup_env
        from bot.platforms.feishu_stream import FeishuStreamClient, FEISHU_SDK_AVAILABLE
    except ImportError as e:
        logger.error(f"Import failed: {e}")
        print(f"\n[ERROR] 无法导入模块: {e}")
        print(f"当前路径: {current_dir}")
        print(f"sys.path: {sys.path}")
        return

    if not FEISHU_SDK_AVAILABLE:
        print("\n[ERROR] lark-oapi SDK 未安装。请运行: pip install lark-oapi")
        return

    # 1. 加载配置
    print("\n[1] 加载配置...")
    setup_env()
    config = get_config()

    app_id = config.feishu_app_id
    app_secret = config.feishu_app_secret
    stream_enabled = config.feishu_stream_enabled
    bot_enabled = config.bot_enabled

    print(f"Feishu App ID: {mask_secret(app_id)}")
    print(f"Feishu App Secret: {mask_secret(app_secret)}")
    print(f"Stream Mode Enabled: {stream_enabled} (Config: feishu_stream_enabled)")
    print(f"Bot Enabled: {bot_enabled} (Config: bot_enabled)")

    if not app_id or not app_secret:
        print("\n[ERROR] 缺少 Feishu App ID 或 App Secret。请检查 .env 文件。")
        return

    # 2. 初始化客户端
    print("\n[2] 初始化 FeishuStreamClient...")
    try:
        client = FeishuStreamClient(app_id=app_id, app_secret=app_secret)
        print("客户端初始化成功。")
    except Exception as e:
        print(f"[ERROR] 客户端初始化失败: {e}")
        return

    # 3. 测试连接
    print("\n[3] 测试 WebSocket 连接...")
    print("正在尝试建立连接... (如果配置正确，应该会保持连接)")
    print("按 Ctrl+C 停止测试")
    
    stop_event = threading.Event()
    
    def run_client():
        try:
            client.start()
        except Exception as e:
            logger.error(f"Stream client error: {e}")
            if not stop_event.is_set():
                print(f"\n[ERROR] 连接断开或失败: {e}")
                # os._exit(1) # 不要直接退出，让主线程处理

    t = threading.Thread(target=run_client, daemon=True)
    t.start()
    
    try:
        # 监控连接状态
        for i in range(30):
            if not t.is_alive():
                 print("\n[ERROR] 客户端线程已停止，连接建立失败。")
                 break
            
            # 这里无法直接获取 ws 连接状态，但如果线程还在跑，通常意味着正在连接或已连接
            if i % 5 == 0:
                print(f"连接维持中... {i}s")
            
            time.sleep(1)
        
        if t.is_alive():
            print("\n[SUCCESS] 测试通过！飞书 Stream 客户端连接正常。")
            print("注意：如果这是在本地测试成功，但在服务器失败，请检查服务器网络是否能访问飞书 API (open.feishu.cn)。")
            print("即将退出测试...")
            
    except KeyboardInterrupt:
        print("\n用户手动停止。")
    finally:
        stop_event.set()
        if client:
            client.stop()
        print("测试结束。")

if __name__ == "__main__":
    main()
