#!/bin/bash

# MoonTV 源码部署脚本
# 适用于Ubuntu系统

set -e

echo "🚀 开始源码部署MoonTV..."

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用sudo运行此脚本${NC}"
    exit 1
fi

# 获取用户输入
read -p "请输入访问密码: " PASSWORD
read -p "请输入站点名称 (默认: MyMoonTV): " SITE_NAME
read -p "请输入域名 (可选): " DOMAIN_NAME
read -p "是否安装Redis用于持久化存储? (y/n): " INSTALL_REDIS

# 设置默认值
SITE_NAME=${SITE_NAME:-"MyMoonTV"}

echo -e "${YELLOW}配置信息:${NC}"
echo "密码: $PASSWORD"
echo "站点名称: $SITE_NAME"
echo "域名: $DOMAIN_NAME"
echo "安装Redis: $INSTALL_REDIS"

# 确认部署
read -p "确认部署? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "部署已取消"
    exit 1
fi

# 1. 系统更新
echo -e "${GREEN}1. 更新系统...${NC}"
apt update && apt upgrade -y

# 2. 安装Node.js 20
echo -e "${GREEN}2. 安装Node.js 20...${NC}"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    echo "Node.js已安装: $(node --version)"
fi

# 3. 安装pnpm
echo -e "${GREEN}3. 安装pnpm...${NC}"
if ! command -v pnpm &> /dev/null; then
    npm install -g pnpm
else
    echo "pnpm已安装: $(pnpm --version)"
fi

# 4. 安装Redis（可选）
if [[ $INSTALL_REDIS =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}4. 安装Redis...${NC}"
    apt install redis-server -y
    systemctl start redis
    systemctl enable redis
    STORAGE_TYPE="redis"
    REDIS_URL="redis://localhost:6379"
else
    echo -e "${YELLOW}4. 跳过Redis安装，使用localStorage存储${NC}"
    STORAGE_TYPE="localstorage"
    REDIS_URL=""
fi

# 5. 创建项目目录
echo -e "${GREEN}5. 创建项目目录...${NC}"
mkdir -p /opt/moontv
chown $USER:$USER /opt/moontv

# 6. 克隆项目
echo -e "${GREEN}6. 克隆项目...${NC}"
cd /opt/moontv
if [ -d ".git" ]; then
    echo "项目已存在，拉取最新代码..."
    git pull
else
    git clone https://github.com/zuiyuu/MoonTV.git .
fi

# 7. 安装依赖
echo -e "${GREEN}7. 安装依赖...${NC}"
sudo -u $USER pnpm install

# 8. 构建项目
echo -e "${GREEN}8. 构建项目...${NC}"
sudo -u $USER pnpm build

# 9. 创建环境变量文件
echo -e "${GREEN}9. 创建环境变量文件...${NC}"
cat > .env.production << EOF
NODE_ENV=production
PASSWORD=$PASSWORD
NEXT_PUBLIC_SITE_NAME=$SITE_NAME
NEXT_PUBLIC_STORAGE_TYPE=$STORAGE_TYPE
REDIS_URL=$REDIS_URL
NEXT_PUBLIC_ENABLE_REGISTER=false
EOF

# 10. 创建systemd服务
echo -e "${GREEN}10. 创建系统服务...${NC}"
cat > /etc/systemd/system/moontv.service << EOF
[Unit]
Description=MoonTV Video Streaming Service
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/moontv
Environment=NODE_ENV=production
EnvironmentFile=/opt/moontv/.env.production
ExecStart=/usr/bin/pnpm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 11. 设置权限
echo -e "${GREEN}11. 设置权限...${NC}"
chown -R www-data:www-data /opt/moontv

# 12. 启动服务
echo -e "${GREEN}12. 启动服务...${NC}"
systemctl daemon-reload
systemctl start moontv
systemctl enable moontv

# 13. 检查服务状态
echo -e "${GREEN}13. 检查服务状态...${NC}"
sleep 5
systemctl status moontv --no-pager

# 14. 显示访问信息
echo -e "${GREEN}🎉 部署完成!${NC}"
echo -e "${YELLOW}访问地址:${NC}"
echo "本地访问: http://localhost:3000"
echo "外网访问: http://$(curl -s ifconfig.me):3000"

if [ ! -z "$DOMAIN_NAME" ]; then
    echo -e "${YELLOW}域名配置:${NC}"
    echo "请将域名 $DOMAIN_NAME 解析到服务器IP: $(curl -s ifconfig.me)"
    echo "然后运行Nginx配置脚本"
fi

echo -e "${YELLOW}管理命令:${NC}"
echo "查看状态: sudo systemctl status moontv"
echo "查看日志: sudo journalctl -u moontv -f"
echo "重启服务: sudo systemctl restart moontv"
echo "停止服务: sudo systemctl stop moontv"

echo -e "${YELLOW}更新命令:${NC}"
echo "更新代码: cd /opt/moontv && git pull && sudo pnpm install && sudo pnpm build && sudo systemctl restart moontv"

echo -e "${YELLOW}安全提醒:${NC}"
echo "1. 请确保防火墙已正确配置"
echo "2. 建议配置SSL证书"
echo "3. 定期备份数据"