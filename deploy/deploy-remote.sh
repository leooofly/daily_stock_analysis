#!/bin/bash
###############################################################################
# 股票分析系统 - 本地远程部署脚本
# 
# 功能：从本地 Windows 电脑通过 SSH 部署到腾讯云服务器
#
# 使用方法：
#   bash deploy-remote.sh <服务器IP> <SSH用户名> [SSH端口]
#
# 示例：
#   bash deploy-remote.sh 1.2.3.4 ubuntu
#   bash deploy-remote.sh 1.2.3.4 root 22
###############################################################################

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查参数
if [ $# -lt 2 ]; then
    echo -e "${RED}用法: $0 <服务器IP> <SSH用户名> [SSH端口]${NC}"
    echo -e "${YELLOW}示例: $0 1.2.3.4 ubuntu 22${NC}"
    exit 1
fi

SERVER_IP=$1
SSH_USER=$2
SSH_PORT=${3:-22}

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}股票分析系统 - 远程部署${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "目标服务器: ${YELLOW}$SSH_USER@$SERVER_IP:$SSH_PORT${NC}"
echo ""

# 测试 SSH 连接
echo -e "${YELLOW}[1/5] 测试 SSH 连接...${NC}"
if ssh -o ConnectTimeout=5 -p $SSH_PORT $SSH_USER@$SERVER_IP "echo '连接成功'" &> /dev/null; then
    echo -e "${GREEN}✓ SSH 连接正常${NC}"
else
    echo -e "${RED}✗ SSH 连接失败，请检查:${NC}"
    echo -e "  1. 服务器 IP 是否正确"
    echo -e "  2. SSH 端口是否正确"
    echo -e "  3. 用户名/密码是否正确"
    echo -e "  4. 服务器防火墙是否开放 SSH 端口"
    exit 1
fi

# 上传部署脚本
echo -e "${YELLOW}[2/5] 上传部署脚本...${NC}"
scp -P $SSH_PORT deploy-config.sh $SSH_USER@$SERVER_IP:/tmp/
echo -e "${GREEN}✓ 脚本上传完成${NC}"

# 执行远程部署
echo -e "${YELLOW}[3/5] 开始远程部署...${NC}"
ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "bash /tmp/deploy-config.sh"

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✓ 远程部署完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

echo -e "${GREEN}📊 访问地址:${NC}"
echo -e "  WebUI: http://$SERVER_IP:8000"
echo ""

echo -e "${GREEN}🔧 远程管理:${NC}"
echo -e "  SSH 登录: ssh -p $SSH_PORT $SSH_USER@$SERVER_IP"
echo -e "  查看日志: ssh $SSH_USER@$SERVER_IP 'cd ~/stock-analysis && docker-compose logs -f'"
echo ""
