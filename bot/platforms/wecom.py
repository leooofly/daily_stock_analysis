# -*- coding: utf-8 -*-
"""
===================================
企业微信适配器
===================================

使用企业微信自建应用接入机器人，支持：
- URL验证（企业微信后台验证回调地址）
- 消息接收与解密
- 主动发送消息

依赖：
pip install wechatpy

企业微信API文档：
https://developer.work.weixin.qq.com/document/path/90556
"""

import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

# 尝试导入企业微信SDK
try:
    from wechatpy.enterprise import WeChatClient
    from wechatpy.enterprise.crypto import WeChatCrypto
    from wechatpy.enterprise.exceptions import InvalidSignatureException, InvalidCorpIdException
    from wechatpy.exceptions import WeChatException
    
    WECOM_SDK_AVAILABLE = True
except ImportError:
    WECOM_SDK_AVAILABLE = False
    logger.warning("[WeCom] wechatpy SDK 未安装，企业微信功能不可用")
    logger.warning("[WeCom] 请运行: pip install wechatpy")

from bot.models import BotMessage, BotResponse, ChatType, WebhookResponse
from bot.platforms.base import BotPlatform


class WeComPlatform(BotPlatform):
    """
    企业微信平台适配器
    
    配置要求（.env）：
        WECOM_CORP_ID=ww1234567890abcdef
        WECOM_AGENT_ID=1000002
        WECOM_SECRET=your_secret
        WECOM_TOKEN=WeCom2026Token
        WECOM_ENCODING_AES_KEY=your_aes_key
    """
    
    def __init__(
        self,
        corp_id: str,
        agent_id: str,
        secret: str,
        token: str,
        encoding_aes_key: str
    ):
        """
        初始化企业微信适配器
        
        Args:
            corp_id: 企业ID
            agent_id: 应用AgentID
            secret: 应用Secret
            token: 消息验证Token
            encoding_aes_key: 消息加密密钥
        """
        if not WECOM_SDK_AVAILABLE:
            raise ImportError("wechatpy SDK 未安装，请运行: pip install wechatpy")
        
        self.corp_id = corp_id
        self.agent_id = int(agent_id)
        self.secret = secret
        self.token = token
        self.encoding_aes_key = encoding_aes_key
        
        # 初始化客户端和加密工具
        self.client = WeChatClient(corp_id, secret)
        self.crypto = WeChatCrypto(token, encoding_aes_key, corp_id)
        
        logger.info(f"[WeCom] 企业微信适配器初始化成功 (AgentID={agent_id})")
    
    @property
    def platform_name(self) -> str:
        return "wecom"
    
    def verify_url(
        self,
        msg_signature: str,
        timestamp: str,
        nonce: str,
        echostr: str
    ) -> Optional[str]:
        """
        验证URL（企业微信后台验证回调地址）
        
        Args:
            msg_signature: 签名
            timestamp: 时间戳
            nonce: 随机数
            echostr: 加密的随机字符串
            
        Returns:
            解密后的echostr，验证失败返回None
        """
        try:
            echo_str = self.crypto.check_signature(
                msg_signature,
                timestamp,
                nonce,
                echostr
            )
            logger.info("[WeCom] URL验证成功")
            return echo_str.decode('utf-8')
        except (InvalidSignatureException, InvalidCorpIdException) as e:
            logger.error(f"[WeCom] URL验证失败: {e}")
            return None
    
    def verify_request(self, headers: Dict[str, str], body: bytes) -> bool:
        """
        验证消息请求签名
        
        企业微信的消息验证在解密时进行，这里始终返回True
        实际验证在decrypt_message中完成
        """
        return True
    
    def decrypt_message(
        self,
        msg_signature: str,
        timestamp: str,
        nonce: str,
        encrypted_msg: str
    ) -> Optional[str]:
        """
        解密企业微信消息
        
        Args:
            msg_signature: 签名
            timestamp: 时间戳
            nonce: 随机数
            encrypted_msg: 加密消息
            
        Returns:
            解密后的XML消息，失败返回None
        """
        try:
            decrypted_xml = self.crypto.decrypt_message(
                encrypted_msg,
                msg_signature,
                timestamp,
                nonce
            )
            return decrypted_xml
        except (InvalidSignatureException, InvalidCorpIdException) as e:
            logger.error(f"[WeCom] 消息解密失败: {e}")
            return None
    
    def parse_message(self, data: Dict[str, Any]) -> Optional[BotMessage]:
        """
        解析企业微信消息为统一格式
        
        企业微信消息格式（XML已转为dict）：
        {
            'ToUserName': 'ww1234567890abcdef',
            'FromUserName': 'UserID',
            'CreateTime': '1234567890',
            'MsgType': 'text',
            'Content': '600519',
            'MsgId': '123456789',
            'AgentID': '1000002'
        }
        """
        try:
            msg_type = data.get('MsgType', '')
            
            # 只处理文本消息
            if msg_type != 'text':
                logger.debug(f"[WeCom] 跳过非文本消息: {msg_type}")
                return None
            
            # 提取消息内容
            content = data.get('Content', '').strip()
            if not content:
                return None
            
            # 构造统一消息格式
            bot_message = BotMessage(
                platform="wecom",
                chat_type=ChatType.PRIVATE,  # 企业微信应用消息默认为私聊
                user_id=data.get('FromUserName', ''),
                user_name=data.get('FromUserName', ''),  # 企业微信不返回用户名，使用UserID
                text=content,
                message_id=data.get('MsgId', ''),
                raw_data=data
            )
            
            logger.info(f"[WeCom] 解析消息成功: user={bot_message.user_id}, text={content}")
            return bot_message
            
        except Exception as e:
            logger.exception(f"[WeCom] 解析消息失败: {e}")
            return None
    
    def format_response(
        self,
        response: BotResponse,
        message: BotMessage
    ) -> WebhookResponse:
        """
        将统一响应转换为企业微信格式
        
        企业微信采用被动回复或主动发送两种方式：
        1. 被动回复：在5秒内直接返回XML响应
        2. 主动发送：调用API发送消息
        
        这里我们使用主动发送，因为分析可能超过5秒
        """
        try:
            # 使用企业微信API主动发送消息
            user_id = message.user_id
            
            # 转换响应类型
            if response.type == "text":
                msg_content = response.text
            elif response.type == "markdown":
                # 企业微信支持markdown，但需要特定格式
                msg_content = response.markdown
            else:
                msg_content = response.text or str(response.data)
            
            # 发送消息
            result = self.client.message.send_text(
                agent_id=self.agent_id,
                user_ids=user_id,
                content=msg_content
            )
            
            logger.info(f"[WeCom] 消息发送成功: user={user_id}")
            
            # 返回空响应（因为我们主动发送了消息）
            return WebhookResponse.success("success")
            
        except WeChatException as e:
            logger.error(f"[WeCom] 发送消息失败: {e}")
            return WebhookResponse.error(f"发送失败: {e}", 500)
    
    def send_message(self, user_id: str, content: str) -> bool:
        """
        主动发送消息给用户
        
        Args:
            user_id: 企业微信用户ID
            content: 消息内容
            
        Returns:
            是否发送成功
        """
        try:
            self.client.message.send_text(
                agent_id=self.agent_id,
                user_ids=user_id,
                content=content
            )
            return True
        except WeChatException as e:
            logger.error(f"[WeCom] 发送消息失败: {e}")
            return False


# ============================================================
# 全局实例管理
# ============================================================

_wecom_instance: Optional[WeComPlatform] = None


def get_wecom_platform(
    corp_id: str,
    agent_id: str,
    secret: str,
    token: str,
    encoding_aes_key: str
) -> Optional[WeComPlatform]:
    """
    获取企业微信平台实例（单例）
    
    Args:
        corp_id: 企业ID
        agent_id: 应用AgentID
        secret: 应用Secret
        token: 消息验证Token
        encoding_aes_key: 消息加密密钥
        
    Returns:
        WeComPlatform实例，未安装SDK返回None
    """
    global _wecom_instance
    
    if not WECOM_SDK_AVAILABLE:
        return None
    
    if _wecom_instance is None:
        _wecom_instance = WeComPlatform(
            corp_id=corp_id,
            agent_id=agent_id,
            secret=secret,
            token=token,
            encoding_aes_key=encoding_aes_key
        )
    
    return _wecom_instance


def is_wecom_available() -> bool:
    """检查企业微信SDK是否可用"""
    return WECOM_SDK_AVAILABLE
