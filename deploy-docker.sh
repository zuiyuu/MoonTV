#!/bin/bash

# MoonTV Docker部署脚本
# 适用于Ubuntu系统

set -e

echo "🚀 开始部署MoonTV..."

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

# 设置默认值
SITE_NAME=${SITE_NAME:-"MyMoonTV"}

echo -e "${YELLOW}配置信息:${NC}"
echo "密码: $PASSWORD"
echo "站点名称: $SITE_NAME"
echo "域名: $DOMAIN_NAME"

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

# 2. 安装Docker
echo -e "${GREEN}2. 安装Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl start docker
    systemctl enable docker
else
    echo "Docker已安装"
fi

# 3. 安装Docker Compose
echo -e "${GREEN}3. 安装Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    apt install docker-compose -y
else
    echo "Docker Compose已安装"
fi

# 4. 创建项目目录
echo -e "${GREEN}4. 创建项目目录...${NC}"
mkdir -p /opt/moontv
cd /opt/moontv

# 5. 创建docker-compose.yml
echo -e "${GREEN}5. 创建Docker Compose配置...${NC}"
cat > docker-compose.yml << EOF
version: '3.8'

services:
  moontv-core:
    image: ghcr.io/lunatechlab/moontv:latest
    container_name: moontv-core
    restart: unless-stopped
    ports:
      - '3000:3000'
    environment:
      - PASSWORD=$PASSWORD
      - NEXT_PUBLIC_SITE_NAME=$SITE_NAME
      - NEXT_PUBLIC_STORAGE_TYPE=redis
      - REDIS_URL=redis://moontv-redis:6379
      - NEXT_PUBLIC_ENABLE_REGISTER=false
    networks:
      - moontv-network
    depends_on:
      - moontv-redis

  moontv-redis:
    image: redis:alpine
    container_name: moontv-redis
    restart: unless-stopped
    networks:
      - moontv-network
    volumes:
      - redis_data:/data

networks:
  moontv-network:
    driver: bridge

volumes:
  redis_data:
EOF

# 6. 启动服务
echo -e "${GREEN}6. 启动服务...${NC}"
docker-compose up -d

# 7. 等待服务启动
echo -e "${GREEN}7. 等待服务启动...${NC}"
sleep 10

# 8. 检查服务状态
echo -e "${GREEN}8. 检查服务状态...${NC}"
docker-compose ps

# 9. 显示访问信息
echo -e "${GREEN}🎉 部署完成!${NC}"
echo -e "${YELLOW}访问地址:${NC}"
echo "本地访问: http://localhost:3000"
echo "外网访问: http://$(curl -s ifconfig.me):3000"

if [ ! -z "$DOMAIN_NAME" ]; then
    echo -e "${YELLOW}域名配置:${NC}"
    echo "请将域名 $DOMAIN_NAME 解析到服务器IP: $(curl -s ifconfig.me)"
    echo "然后配置Nginx反向代理"
fi

echo -e "${YELLOW}管理命令:${NC}"
echo "查看状态: cd /opt/moontv && docker-compose ps"
echo "查看日志: cd /opt/moontv && docker-compose logs -f moontv-core"
echo "重启服务: cd /opt/moontv && docker-compose restart"
echo "停止服务: cd /opt/moontv && docker-compose down"

echo -e "${YELLOW}安全提醒:${NC}"
echo "1. 请确保防火墙已正确配置"
echo "2. 建议配置SSL证书"
echo "3. 定期备份数据"