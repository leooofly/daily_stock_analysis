# 腾讯云自动部署指南

## 📦 部署包说明

本目录包含两种部署方式的脚本：

### 方式 A：本地远程部署（推荐）

**特点**：从本地 Windows 电脑通过 SSH 一键部署到腾讯云

**前提条件**：
- ✅ 本地已安装 Git Bash 或 WSL
- ✅ 能通过 SSH 连接到服务器
- ✅ 服务器已配置 SSH 密钥或知道密码

**使用步骤**：

```bash
# 1. 打开 Git Bash（Windows）或终端（Linux/Mac）
cd deploy/

# 2. 执行远程部署脚本
bash deploy-remote.sh <服务器IP> <用户名> [SSH端口]

# 示例：
bash deploy-remote.sh 43.xxx.xxx.xxx ubuntu 22
```

脚本会自动完成：
1. ✅ 测试 SSH 连接
2. ✅ 上传部署脚本到服务器
3. ✅ 远程执行安装（Docker、代码、配置）
4. ✅ 启动服务
5. ✅ 输出访问地址

---

### 方式 B：服务器本地部署

**特点**：先登录服务器，再执行部署脚本

**使用步骤**：

```bash
# 1. SSH 登录到服务器
ssh ubuntu@43.xxx.xxx.xxx

# 2. 下载部署脚本
wget https://raw.githubusercontent.com/ZhuLinsen/daily_stock_analysis/main/deploy/deploy-config.sh

# 3. 执行部署
bash deploy-config.sh
```

---

## 🔑 需要准备的信息

### 必需：
1. **Gemini API Key**
   - 访问：https://aistudio.google.com/
   - 免费获取（每月有额度）

2. **自选股列表**
   - 格式：`600519,000001,hk00700,AAPL`
   - A股6位数字，港股HK开头，美股字母

### 可选（增强功能）：
3. **飞书机器人**
   - App ID & App Secret
   - 访问：https://open.feishu.cn/

4. **搜索 API**
   - Tavily API Key（免费 1000次/月）
   - 访问：https://tavily.com/

---

## 📊 部署后验证

### 1. 检查服务状态

```bash
# 查看容器运行状态
docker-compose ps

# 预期输出：
# NAME                         STATUS
# stock-analysis-app-1         Up 2 minutes
```

### 2. 查看日志

```bash
cd ~/stock-analysis
docker-compose logs -f
```

### 3. 访问 WebUI

打开浏览器访问：
```
http://<服务器IP>:8000
```

### 4. 测试分析功能

```bash
# 命令行测试
docker-compose exec app python main.py --stocks 600519 --no-notify

# 或通过 WebUI 界面输入股票代码
```

---

## 🤖 配置飞书机器人

### 1. 创建飞书应用

访问：https://open.feishu.cn/app

1. 点击"创建企业自建应用"
2. 应用名称：`股票分析助手`
3. 获取 App ID 和 App Secret

### 2. 配置权限

在"权限管理"添加：
- `im:message` - 接收消息
- `im:message:send_as_bot` - 发送消息

### 3. 启用机器人

在"应用功能" → "机器人" → 开启

### 4. 发布应用

"版本管理与发布" → "创建版本" → "申请发布"

### 5. 更新配置

```bash
# 编辑配置文件
nano ~/stock-analysis/.env

# 添加或修改以下配置：
FEISHU_APP_ID=cli_xxxx
FEISHU_APP_SECRET=xxxx
FEISHU_STREAM_ENABLED=true

# 重启服务
docker-compose restart
```

### 6. 测试机器人

在飞书中：
1. 搜索你的应用名称
2. 添加到聊天
3. 发送命令：`/分析 600519`

---

## 🔧 常用运维命令

### 服务管理

```bash
cd ~/stock-analysis

# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 查看日志
docker-compose logs -f

# 查看最新 100 行日志
docker-compose logs --tail 100

# 更新代码
git pull
docker-compose up -d --build
```

### 手动执行分析

```bash
# 分析单只股票
docker-compose exec app python main.py --stocks 600519

# 分析多只股票
docker-compose exec app python main.py --stocks 600519,000001,hk00700

# 大盘复盘
docker-compose exec app python main.py --market-review

# 立即推送
docker-compose exec app python main.py --stocks 600519 --single-notify
```

### 查看系统状态

```bash
# 磁盘使用
df -h

# 内存使用
free -h

# Docker 镜像
docker images

# Docker 容器
docker ps -a

# 查看端口占用
netstat -tulpn | grep 8000
```

---

## 🛡️ 安全建议

### 1. 配置防火墙

```bash
# 只开放必要端口
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 8000/tcp  # WebUI（可选，建议仅内网访问）
sudo ufw enable
```

### 2. 使用 Nginx 反向代理 + HTTPS

```bash
# 安装 Nginx
sudo apt install nginx certbot python3-certbot-nginx

# 配置反向代理
sudo nano /etc/nginx/sites-available/stock-analysis

# 内容：
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# 启用配置
sudo ln -s /etc/nginx/sites-available/stock-analysis /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 申请 SSL 证书
sudo certbot --nginx -d your-domain.com
```

### 3. 定期备份

```bash
# 备份配置和数据
tar -czf stock-analysis-backup-$(date +%Y%m%d).tar.gz ~/stock-analysis

# 下载到本地
scp ubuntu@server:/path/to/backup.tar.gz ./
```

---

## ❓ 常见问题

### Q1: Docker 权限错误

```bash
# 将当前用户添加到 docker 组
sudo usermod -aG docker $USER

# 重新登录或执行
newgrp docker
```

### Q2: 端口被占用

```bash
# 查看占用端口的进程
sudo lsof -i :8000

# 修改端口（编辑 .env）
WEBUI_PORT=8001
```

### Q3: 服务启动失败

```bash
# 查看详细错误
docker-compose logs

# 检查配置文件
cat .env

# 重新构建
docker-compose down
docker-compose up -d --build
```

### Q4: Gemini API 超时

```bash
# 检查网络
curl -I https://generativelanguage.googleapis.com

# 如需代理，编辑 .env：
USE_PROXY=true
PROXY_HOST=127.0.0.1
PROXY_PORT=10809
```

---

## 📞 获取帮助

- GitHub Issues: https://github.com/ZhuLinsen/daily_stock_analysis/issues
- 项目文档: https://github.com/ZhuLinsen/daily_stock_analysis/tree/main/docs

---

**部署愉快！📈**
