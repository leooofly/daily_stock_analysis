#!/bin/bash
###############################################################################
# 股票分析系统 - 腾讯云自动部署脚本
# 
# 功能：
# 1. 检查并安装 Docker & Docker Compose
# 2. 配置环境变量
# 3. 启动服务
# 4. 验证部署
#
# 使用方法：
#   bash deploy-config.sh
###############################################################################

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}股票分析系统 - 自动部署脚本${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# 1. 检查是否为 root 用户
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}⚠️  检测到 root 用户，建议使用普通用户 + sudo${NC}"
fi

# 2. 检查操作系统
echo -e "${YELLOW}[1/7] 检查操作系统...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${GREEN}✓ 操作系统: $NAME $VERSION${NC}"
else
    echo -e "${RED}✗ 无法识别操作系统${NC}"
    exit 1
fi

# 3. 检查并安装 Docker
echo -e "${YELLOW}[2/7] 检查 Docker...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker 已安装: $(docker --version)${NC}"
else
    echo -e "${YELLOW}⚙️  正在安装 Docker...${NC}"
    curl -fsSL https://get.docker.com | bash
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓ Docker 安装完成${NC}"
    echo -e "${YELLOW}⚠️  需要重新登录以使 Docker 权限生效${NC}"
fi

# 4. 检查并安装 Docker Compose
echo -e "${YELLOW}[3/7] 检查 Docker Compose...${NC}"
if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose 已安装: $(docker-compose --version)${NC}"
else
    echo -e "${YELLOW}⚙️  正在安装 Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✓ Docker Compose 安装完成${NC}"
fi

# 5. 创建项目目录
echo -e "${YELLOW}[4/7] 创建项目目录...${NC}"
PROJECT_DIR="$HOME/stock-analysis"
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠️  项目目录已存在，是否覆盖? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rm -rf "$PROJECT_DIR"
    else
        echo -e "${RED}✗ 部署取消${NC}"
        exit 1
    fi
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"
echo -e "${GREEN}✓ 项目目录: $PROJECT_DIR${NC}"

# 6. 克隆代码
echo -e "${YELLOW}[5/7] 克隆代码仓库...${NC}"
git clone https://github.com/ZhuLinsen/daily_stock_analysis.git .
echo -e "${GREEN}✓ 代码克隆完成${NC}"

# 7. 配置环境变量
echo -e "${YELLOW}[6/7] 配置环境变量...${NC}"
echo -e "${YELLOW}请输入以下配置信息（按回车使用默认值）:${NC}"
echo ""

# 读取配置
read -p "自选股列表 (如 600519,000001): " STOCK_LIST
STOCK_LIST=${STOCK_LIST:-"600519,000001"}

read -p "Gemini API Key: " GEMINI_API_KEY
if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}✗ Gemini API Key 是必需的！${NC}"
    echo -e "${YELLOW}请访问 https://aistudio.google.com/ 获取${NC}"
    exit 1
fi

read -p "飞书 App ID (可选): " FEISHU_APP_ID
read -p "飞书 App Secret (可选): " FEISHU_APP_SECRET
read -p "飞书 Webhook URL (可选): " FEISHU_WEBHOOK_URL
read -p "Tavily API Key (可选): " TAVILY_API_KEY

# 生成 .env 文件
cat > .env << EOF
# ===================================
# 股票分析系统 - 配置文件
# 自动生成时间: $(date)
# ===================================

# === 必填：自选股列表 ===
STOCK_LIST=$STOCK_LIST

# === 必填：AI 模型 ===
GEMINI_API_KEY=$GEMINI_API_KEY
GEMINI_MODEL=gemini-2.0-flash-exp

# === 飞书机器人（Stream 模式）===
EOF

if [ -n "$FEISHU_APP_ID" ]; then
    cat >> .env << EOF
FEISHU_APP_ID=$FEISHU_APP_ID
FEISHU_APP_SECRET=$FEISHU_APP_SECRET
FEISHU_STREAM_ENABLED=true
EOF
fi

if [ -n "$FEISHU_WEBHOOK_URL" ]; then
    echo "FEISHU_WEBHOOK_URL=$FEISHU_WEBHOOK_URL" >> .env
fi

if [ -n "$TAVILY_API_KEY" ]; then
    echo "TAVILY_API_KEY=$TAVILY_API_KEY" >> .env
fi

cat >> .env << EOF

# === 定时任务 ===
SCHEDULE_ENABLED=true
SCHEDULE_TIME=18:00

# === WebUI ===
WEBUI_ENABLED=true
WEBUI_HOST=0.0.0.0
WEBUI_PORT=8000

# === 报告类型 ===
REPORT_TYPE=full

# === 日志配置 ===
LOG_DIR=./logs
EOF

echo -e "${GREEN}✓ 配置文件已生成: .env${NC}"

# 8. 启动服务
echo -e "${YELLOW}[7/7] 启动服务...${NC}"
docker-compose up -d

# 等待服务启动
echo -e "${YELLOW}⏳ 等待服务启动（30秒）...${NC}"
sleep 30

# 9. 验证部署
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✓ 部署完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# 获取服务器 IP
SERVER_IP=$(curl -s ifconfig.me)

echo -e "${GREEN}📊 服务信息:${NC}"
echo -e "  WebUI 地址: http://$SERVER_IP:8000"
echo -e "  WebUI 本地: http://127.0.0.1:8000"
echo ""

echo -e "${GREEN}🔧 常用命令:${NC}"
echo -e "  查看日志: cd $PROJECT_DIR && docker-compose logs -f"
echo -e "  重启服务: cd $PROJECT_DIR && docker-compose restart"
echo -e "  停止服务: cd $PROJECT_DIR && docker-compose down"
echo -e "  手动分析: cd $PROJECT_DIR && docker-compose exec app python main.py --stocks 600519"
echo ""

echo -e "${GREEN}🤖 飞书机器人:${NC}"
if [ -n "$FEISHU_APP_ID" ]; then
    echo -e "  在飞书中搜索并添加你的机器人应用"
    echo -e "  发送命令: /分析 600519"
else
    echo -e "  ${YELLOW}未配置飞书机器人，如需使用请编辑 .env 文件并重启服务${NC}"
fi
echo ""

echo -e "${YELLOW}⚠️  安全提示:${NC}"
echo -e "  1. 建议配置防火墙，只开放必要端口"
echo -e "  2. 定期备份 .env 配置文件"
echo -e "  3. API Keys 请妥善保管"
echo ""
