#!/bin/bash
###############################################################################
# 股票分析系统 - 一键部署脚本（超简化版）
# 
# 使用方法：复制下面的命令，粘贴到服务器终端执行即可
# 
# curl -fsSL https://raw.githubusercontent.com/你的仓库/main/deploy/one-click-install.sh | bash
# 
# 或者直接执行：
# bash <(curl -fsSL 上面的网址)
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 清屏
clear

# 欢迎界面
cat << "EOF"
╔════════════════════════════════════════╗
║                                        ║
║     📈 股票智能分析系统                 ║
║        一键部署脚本 v1.0                ║
║                                        ║
║     让部署像喝水一样简单 💧              ║
║                                        ║
╚════════════════════════════════════════╝

EOF

echo -e "${BLUE}正在准备部署环境，请稍候...${NC}"
sleep 2

# ========================================
# 步骤 1: 环境检查
# ========================================
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📋 步骤 1/6: 环境检查${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}⚠️  当前非 root 用户，部分操作可能需要输入密码${NC}"
    SUDO="sudo"
else
    echo -e "${GREEN}✓ 当前为 root 用户${NC}"
    SUDO=""
fi

# 检测操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${GREEN}✓ 操作系统: $PRETTY_NAME${NC}"
else
    echo -e "${RED}✗ 无法识别操作系统，建议使用 Ubuntu 20.04+${NC}"
    exit 1
fi

# 检查磁盘空间（至少需要 2GB）
AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
if [ "$AVAILABLE_SPACE" -lt 2097152 ]; then
    echo -e "${RED}✗ 磁盘空间不足，至少需要 2GB${NC}"
    exit 1
else
    echo -e "${GREEN}✓ 磁盘空间充足${NC}"
fi

# ========================================
# 步骤 2: 安装 Docker
# ========================================
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🐳 步骤 2/6: 安装 Docker${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker 已安装: $(docker --version)${NC}"
else
    echo -e "${BLUE}正在安装 Docker（预计 2-3 分钟）...${NC}"
    curl -fsSL https://get.docker.com | bash
    $SUDO systemctl start docker
    $SUDO systemctl enable docker
    
    # 添加当前用户到 docker 组（避免每次都要 sudo）
    if [ "$EUID" -ne 0 ]; then
        $SUDO usermod -aG docker $USER
        echo -e "${YELLOW}⚠️  Docker 安装完成，建议重新登录使权限生效${NC}"
        echo -e "${YELLOW}   或执行: newgrp docker${NC}"
    fi
    
    echo -e "${GREEN}✓ Docker 安装完成${NC}"
fi

# 安装 Docker Compose
if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose 已安装${NC}"
else
    echo -e "${BLUE}正在安装 Docker Compose...${NC}"
    $SUDO curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    $SUDO chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✓ Docker Compose 安装完成${NC}"
fi

# ========================================
# 步骤 3: 下载项目代码
# ========================================
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📦 步骤 3/6: 下载项目代码${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

PROJECT_DIR="$HOME/stock-analysis"

# 检查目录是否存在
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠️  项目目录已存在${NC}"
    echo -e "${YELLOW}   是否删除并重新下载? (y/N): ${NC}"
    read -t 10 -r REPLY || REPLY="N"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$PROJECT_DIR"
        echo -e "${GREEN}✓ 已删除旧目录${NC}"
    else
        echo -e "${BLUE}使用现有目录${NC}"
    fi
fi

# 克隆代码（如果不存在）
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${BLUE}正在克隆代码仓库（预计 1-2 分钟）...${NC}"
    git clone https://github.com/ZhuLinsen/daily_stock_analysis.git "$PROJECT_DIR"
    echo -e "${GREEN}✓ 代码下载完成${NC}"
fi

cd "$PROJECT_DIR"
echo -e "${GREEN}✓ 工作目录: $PROJECT_DIR${NC}"

# ========================================
# 步骤 4: 配置系统（最重要！）
# ========================================
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}⚙️  步骤 4/6: 配置系统${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}现在需要配置一些必要信息，请准备好以下内容：${NC}"
echo -e "  1. ${GREEN}Gemini API Key${NC} (必需) - 免费获取: https://aistudio.google.com/"
echo -e "  2. ${GREEN}自选股列表${NC} (必需) - 如: 600519,000001"
echo -e "  3. 飞书机器人配置 (可选)"
echo ""
echo -e "${YELLOW}按回车键继续...${NC}"
read -r

# 配置文件路径
ENV_FILE=".env"

# 如果已存在配置，询问是否保留
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}⚠️  发现现有配置文件${NC}"
    echo -e "${YELLOW}   是否保留现有配置? (Y/n): ${NC}"
    read -r KEEP_CONFIG
    if [[ ! $KEEP_CONFIG =~ ^[Nn]$ ]]; then
        echo -e "${GREEN}✓ 保留现有配置${NC}"
        SKIP_CONFIG=true
    else
        SKIP_CONFIG=false
    fi
else
    SKIP_CONFIG=false
fi

if [ "$SKIP_CONFIG" = false ]; then
    # 创建配置文件
    cat > "$ENV_FILE" << 'EOFENV'
# ===================================
# 股票分析系统 - 配置文件
# ===================================

# === 必填配置 ===
STOCK_LIST=
GEMINI_API_KEY=

# === 可选配置 ===
# 飞书机器人（Stream 模式，无需公网 IP）
FEISHU_APP_ID=
FEISHU_APP_SECRET=
FEISHU_STREAM_ENABLED=false

# 搜索引擎（增强新闻分析）
TAVILY_API_KEY=

# 定时任务
SCHEDULE_ENABLED=true
SCHEDULE_TIME=18:00

# WebUI
WEBUI_ENABLED=true
WEBUI_HOST=0.0.0.0
WEBUI_PORT=8000

# 报告类型
REPORT_TYPE=full
EOFENV

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}请输入配置信息（按回车使用默认值）${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 1. 自选股列表
    echo ""
    echo -e "${BLUE}1️⃣  自选股列表${NC}"
    echo -e "   ${YELLOW}格式: A股6位数字 / 港股HK开头 / 美股字母${NC}"
    echo -e "   ${YELLOW}示例: 600519,000001,hk00700,AAPL${NC}"
    read -p "   请输入: " STOCK_LIST
    while [ -z "$STOCK_LIST" ]; do
        echo -e "   ${RED}自选股列表不能为空！${NC}"
        read -p "   请输入: " STOCK_LIST
    done
    sed -i "s|^STOCK_LIST=.*|STOCK_LIST=$STOCK_LIST|" "$ENV_FILE"
    echo -e "   ${GREEN}✓ 已设置${NC}"
    
    # 2. Gemini API Key
    echo ""
    echo -e "${BLUE}2️⃣  Gemini API Key (AI 分析引擎)${NC}"
    echo -e "   ${YELLOW}获取地址: https://aistudio.google.com/${NC}"
    echo -e "   ${YELLOW}完全免费，个人使用额度充足${NC}"
    read -p "   请输入: " GEMINI_KEY
    while [ -z "$GEMINI_KEY" ]; do
        echo -e "   ${RED}Gemini API Key 不能为空！${NC}"
        read -p "   请输入: " GEMINI_KEY
    done
    sed -i "s|^GEMINI_API_KEY=.*|GEMINI_API_KEY=$GEMINI_KEY|" "$ENV_FILE"
    echo -e "   ${GREEN}✓ 已设置${NC}"
    
    # 3. 飞书机器人（可选）
    echo ""
    echo -e "${BLUE}3️⃣  飞书机器人 (可选，按回车跳过)${NC}"
    echo -e "   ${YELLOW}用于在飞书中发送命令实时查询股票${NC}"
    read -p "   飞书 App ID: " FEISHU_ID
    if [ -n "$FEISHU_ID" ]; then
        read -p "   飞书 App Secret: " FEISHU_SECRET
        sed -i "s|^FEISHU_APP_ID=.*|FEISHU_APP_ID=$FEISHU_ID|" "$ENV_FILE"
        sed -i "s|^FEISHU_APP_SECRET=.*|FEISHU_APP_SECRET=$FEISHU_SECRET|" "$ENV_FILE"
        sed -i "s|^FEISHU_STREAM_ENABLED=.*|FEISHU_STREAM_ENABLED=true|" "$ENV_FILE"
        echo -e "   ${GREEN}✓ 已设置飞书机器人${NC}"
    else
        echo -e "   ${YELLOW}⊘ 跳过飞书配置${NC}"
    fi
    
    # 4. 搜索 API（可选）
    echo ""
    echo -e "${BLUE}4️⃣  Tavily 搜索 API (可选，按回车跳过)${NC}"
    echo -e "   ${YELLOW}用于获取股票新闻，免费 1000次/月${NC}"
    echo -e "   ${YELLOW}获取地址: https://tavily.com/${NC}"
    read -p "   Tavily API Key: " TAVILY_KEY
    if [ -n "$TAVILY_KEY" ]; then
        sed -i "s|^TAVILY_API_KEY=.*|TAVILY_API_KEY=$TAVILY_KEY|" "$ENV_FILE"
        echo -e "   ${GREEN}✓ 已设置 Tavily${NC}"
    else
        echo -e "   ${YELLOW}⊘ 跳过搜索配置（仍可正常使用）${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✓ 配置完成！${NC}"
fi

# ========================================
# 步骤 5: 启动服务
# ========================================
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🚀 步骤 5/6: 启动服务${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${BLUE}正在构建 Docker 镜像（首次运行约需 3-5 分钟）...${NC}"

# 使用 docker-compose 启动
$SUDO docker-compose up -d --build

# 等待服务启动
echo -e "${BLUE}等待服务启动（30秒）...${NC}"
sleep 30

# ========================================
# 步骤 6: 验证部署
# ========================================
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}✅ 步骤 6/6: 验证部署${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 检查容器状态
if $SUDO docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✓ 服务运行正常${NC}"
else
    echo -e "${RED}✗ 服务启动失败，请查看日志${NC}"
    $SUDO docker-compose logs --tail 50
    exit 1
fi

# 获取服务器 IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "无法获取")

# ========================================
# 部署完成
# ========================================
clear
cat << "EOF"

╔════════════════════════════════════════╗
║                                        ║
║          🎉 部署成功！                  ║
║                                        ║
╚════════════════════════════════════════╝

EOF

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📊 访问信息${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BLUE}WebUI 地址:${NC}"
echo -e "    • 外网: http://$SERVER_IP:8000"
echo -e "    • 内网: http://127.0.0.1:8000"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🔧 常用命令${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BLUE}进入项目目录:${NC}"
echo -e "    cd $PROJECT_DIR"
echo ""
echo -e "  ${BLUE}查看运行日志:${NC}"
echo -e "    docker-compose logs -f"
echo ""
echo -e "  ${BLUE}手动分析股票:${NC}"
echo -e "    docker-compose exec app python main.py --stocks 600519"
echo ""
echo -e "  ${BLUE}重启服务:${NC}"
echo -e "    docker-compose restart"
echo ""
echo -e "  ${BLUE}停止服务:${NC}"
echo -e "    docker-compose down"
echo ""

# 如果配置了飞书
if grep -q "FEISHU_STREAM_ENABLED=true" "$ENV_FILE"; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🤖 飞书机器人${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}1. 在飞书中搜索你的应用${NC}"
    echo -e "  ${BLUE}2. 添加到聊天${NC}"
    echo -e "  ${BLUE}3. 发送命令:${NC} /分析 600519"
    echo ""
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📅 自动任务${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BLUE}系统将在每天 18:00 自动分析自选股并推送${NC}"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}💡 提示${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  • 如需修改配置，编辑 $PROJECT_DIR/.env"
echo -e "  • 修改后执行: cd $PROJECT_DIR && docker-compose restart"
echo -e "  • 文档地址: https://github.com/ZhuLinsen/daily_stock_analysis"
echo ""
echo -e "${GREEN}部署完成，祝投资顺利！📈${NC}"
echo ""
