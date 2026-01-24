#!/bin/bash

# MoonTV Ubuntu发布脚本
# 适用于Ubuntu系统

set -e

echo "🚀 开始发布MoonTV..."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用sudo运行此脚本${NC}"
    exit 1
fi

# 1. 安装Node.js 20
echo -e "${GREEN}1. 安装Node.js 20...${NC}"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    echo "Node.js已安装: $(node --version)"
fi

# 2. 安装pnpm
echo -e "${GREEN}2. 安装pnpm...${NC}"
if ! command -v pnpm &> /dev/null; then
    npm install -g pnpm
else
    echo "pnpm已安装: $(pnpm --version)"
fi

# 3. 安装依赖
echo -e "${GREEN}3. 安装依赖...${NC}"
pnpm install

# 4. 构建项目
echo -e "${GREEN}4. 构建项目...${NC}"
pnpm build

# 5. 创建环境变量文件
echo -e "${GREEN}5. 创建环境变量文件...${NC}"
cat > .env.production << EOF
NODE_ENV=production
NEXT_PUBLIC_STORAGE_TYPE=localstorage
NEXT_PUBLIC_ENABLE_REGISTER=false
EOF

# 6. 创建systemd服务
echo -e "${GREEN}6. 创建系统服务...${NC}"
cat > /etc/systemd/system/moontv.service << EOF
[Unit]
Description=MoonTV Video Streaming Service
After=network.target

[Service]
Type=simple
User=homeserver
WorkingDirectory=$(pwd)
Environment=NODE_ENV=production
EnvironmentFile=$(pwd)/.env.production
ExecStart=/usr/bin/pnpm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 7. 设置权限
echo -e "${GREEN}7. 设置权限...${NC}"
chown -R homeserver:homeserver $(pwd)

# 8. 启动服务
echo -e "${GREEN}8. 启动服务...${NC}"
systemctl daemon-reload
systemctl start moontv
systemctl enable moontv

# 9. 检查服务状态
echo -e "${GREEN}9. 检查服务状态...${NC}"
sleep 5
systemctl status moontv --no-pager

echo -e "${GREEN}🎉 发布完成!${NC}"
echo -e "${YELLOW}访问地址:${NC}"
echo "http://localhost:3000"
echo -e "${YELLOW}管理命令:${NC}"
echo "查看状态: sudo systemctl status moontv"
echo "查看日志: sudo journalctl -u moontv -f"
echo "重启服务: sudo systemctl restart moontv"
