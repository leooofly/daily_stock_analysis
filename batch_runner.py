# -*- coding: utf-8 -*-
"""
===================================
多用户批处理运行器 (Batch Runner)
===================================

职责：
1. 从环境变量 MULTI_USER_CONFIG 读取多用户配置 (JSON格式)
2. 循环为每个用户执行独立的分析任务
3. 动态通过环境变量隔离每个用户的配置（邮箱、自选股）

使用场景：
GitHub Actions 中配置一个 Secret 即可管理多个用户的推送
"""
import json
import os
import sys
import logging
import argparse
from typing import List, Dict

# 添加当前目录 to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from src.config import Config, get_config
from main import run_full_analysis, parse_arguments

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)-8s | %(name)-20s | %(message)s'
)
logger = logging.getLogger("BatchRunner")

def load_user_config() -> List[Dict]:
    """读取并解析多用户配置"""
    config_json = os.getenv("MULTI_USER_CONFIG")
    if not config_json:
        logger.warning("未找到 MULTI_USER_CONFIG 环境变量，将回退到默认单用户模式")
        return []
    
    try:
        users = json.loads(config_json)
        if not isinstance(users, list):
            raise ValueError("配置必须是 JSON 列表格式")
        logger.info(f"成功加载多用户配置，共 {len(users)} 个用户")
        return users
    except json.JSONDecodeError:
        logger.error("MULTI_USER_CONFIG JSON 解析失败，请检查格式")
        return []
    except Exception as e:
        logger.error(f"加载配置失败: {e}")
        return []

def run_batch_job():
    """执行批处理任务"""
    # 1. 解析基础参数 (复用 main.py 的参数逻辑)
    args = parse_arguments()
    
    # 2. 加载多用户配置
    users = load_user_config()
    
    # 如果没有多用户配置，通过返回 False 让外部知道应该回退到普通模式
    # 但为了简单，如果列表为空，我们可以直接调用一次 main.py 的逻辑
    # 或者在这里直接运行一次默认配置
    if not users:
        logger.info(">>> 进入单用户兼容模式 (使用默认环境变量配置)")
        # 重置配置确保干净
        Config.reset_instance()
        config = get_config()
        run_full_analysis(config, args)
        return

    # 3. 遍历用户执行
    logger.info(">>> 开始执行多用户批处理任务")
    
    for idx, user in enumerate(users, 1):
        email = user.get("email")
        stocks = user.get("stocks", [])
        
        if not email or not stocks:
            logger.warning(f"用户配置无效 (索引 {idx-1})，跳过: {user}")
            continue
            
        stock_str = ",".join(stocks)
        logger.info(f"\n[{idx}/{len(users)}] 正在处理用户: {email}")
        logger.info(f"    自选股: {stock_str}")
        
        try:
            # === 核心黑科技：通过环境变量动态注入配置 ===
            # Config._load_from_env 会优先读取环境变量
            os.environ["EMAIL_RECEIVERS"] = email
            os.environ["STOCK_LIST"] = stock_str
            
            # 强制重置 Config 单例，触发重新加载环境变量
            Config.reset_instance()
            config = get_config()
            
            # 二次确认配置生效
            if config.email_receivers != [email]:
                logger.error(f"配置注入失败！预期邮箱: {email}, 实际: {config.email_receivers}")
                continue
                
            # 执行分析 (传入 None 让它使用 config 中的 stock_list)
            run_full_analysis(config, args, stock_codes=None)
            
            logger.info(f"用户 {email} 处理完成 ✅")
            
        except Exception as e:
            logger.error(f"用户 {email} 处理失败 ❌: {e}")
            # 继续处理下一个用户，不要中断整个批次
            continue

    logger.info("\n=== 所有用户任务执行完毕 ===")

if __name__ == "__main__":
    run_batch_job()
