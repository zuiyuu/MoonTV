#!/bin/bash

# MoonTV网络快速修复脚本
# 解决localhost可访问但固定IP无法访问的问题

set -e

echo "🔧 MoonTV网络快速修复"
echo "========================================"

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

echo -e "${YELLOW}开始修复网络配置...${NC}"

# 1. 检查部署类型
echo -e "${GREEN}1. 检测部署类型${NC}"

if command -v docker-compose &> /dev/null && [ -f "/opt/moontv/docker-compose.yml" ]; then
    DEPLOY_TYPE="docker"
    echo "   检测到: Docker部署"
elif [ -f "/etc/systemd/system/moontv.service" ]; then
    DEPLOY_TYPE="source"
    echo "   检测到: 源码部署"
else
    echo -e "${RED}   未检测到MoonTV部署${NC}"
    exit 1
fi

# 2. 修复Docker部署
if [ "$DEPLOY_TYPE" = "docker" ]; then
    echo -e "${GREEN}2. 修复Docker配置${NC}"
    
    cd /opt/moontv
    
    # 备份原配置
    cp docker-compose.yml docker-compose.yml.backup
    
    # 修复端口映射，确保监听所有IP
    sed -i "s/ports:/ports:\n      - '0.0.0.0:3000:3000'/g" docker-compose.yml
    sed -i "/- '3000:3000'/d" docker-compose.yml
    
    # 添加环境变量确保Next.js监听所有IP
    if ! grep -q "HOSTNAME=0.0.0.0" docker-compose.yml; then
        sed -i "/environment:/a\      - HOSTNAME=0.0.0.0" docker-compose.yml
    fi
    
    echo "   重启Docker容器..."
    docker-compose down
    docker-compose up -d
    
    # 等待容器启动
    sleep 10
    
    # 检查容器状态
    if docker-compose ps | grep -q "Up"; then
        echo -e "   ${GREEN}Docker容器启动成功${NC}"
    else
        echo -e "   ${RED}Docker容器启动失败${NC}"
        docker-compose logs
    fi
fi

# 3. 修复源码部署
if [ "$DEPLOY_TYPE" = "source" ]; then
    echo -e "${GREEN}2. 修复源码配置${NC}"
    
    # 修复环境变量文件
    ENV_FILE="/opt/moontv/.env.production"
    
    if [ -f "$ENV_FILE" ]; then
        # 备份原配置
        cp "$ENV_FILE" "$ENV_FILE.backup"
        
        # 添加或修改HOSTNAME
        if grep -q "HOSTNAME=" "$ENV_FILE"; then
            sed -i "s/HOSTNAME=.*/HOSTNAME=0.0.0.0/" "$ENV_FILE"
        else
            echo "HOSTNAME=0.0.0.0" >> "$ENV_FILE"
        fi
        
        # 添加或修改PORT
        if grep -q "PORT=" "$ENV_FILE"; then
            sed -i "s/PORT=.*/PORT=3000/" "$ENV_FILE"
        else
            echo "PORT=3000" >> "$ENV_FILE"
        fi
        
        echo "   环境变量已更新"
    else
        # 创建环境变量文件
        cat > "$ENV_FILE" << EOF
NODE_ENV=production
HOSTNAME=0.0.0.0
PORT=3000
EOF
        echo "   环境变量文件已创建"
    fi
    
    # 修复systemd服务文件
    SERVICE_FILE="/etc/systemd/system/moontv.service"
    
    if [ -f "$SERVICE_FILE" ]; then
        # 备份原配置
        cp "$SERVICE_FILE" "$SERVICE_FILE.backup"
        
        # 添加环境变量到服务文件
        if ! grep -q "Environment=HOSTNAME=0.0.0.0" "$SERVICE_FILE"; then
            sed -i "/EnvironmentFile=/a\Environment=HOSTNAME=0.0.0.0" "$SERVICE_FILE"
        fi
        
        if ! grep -q "Environment=PORT=3000" "$SERVICE_FILE"; then
            sed -i "/Environment=HOSTNAME=0.0.0.0/a\Environment=PORT=3000" "$SERVICE_FILE"
        fi
        
        # 重新加载systemd
        systemctl daemon-reload
        
        echo "   Systemd服务配置已更新"
    fi
    
    # 重启服务
    echo "   重启MoonTV服务..."
    systemctl restart moontv
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if systemctl is-active --quiet moontv; then
        echo -e "   ${GREEN}MoonTV服务启动成功${NC}"
    else
        echo -e "   ${RED}MoonTV服务启动失败${NC}"
        systemctl status moontv --no-pager
    fi
fi

# 4. 配置防火墙
echo -e "${GREEN}3. 配置防火墙${NC}"

# 配置UFW
if command -v ufw &> /dev/null; then
    if ! ufw status | grep -q "3000"; then
        echo "   开放UFW端口3000..."
        ufw allow 3000
        echo -e "   ${GREEN}UFW端口3000已开放${NC}"
    else
        echo "   UFW端口3000已开放"
    fi
fi

# 配置iptables
if command -v iptables &> /dev/null; then
    if ! iptables -L INPUT | grep -q "tcp dpt:3000"; then
        echo "   开放iptables端口3000..."
        iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
        echo -e "   ${GREEN}iptables端口3000已开放${NC}"
    else
        echo "   iptables端口3000已开放"
    fi
fi

# 5. 验证修复
echo -e "${GREEN}4. 验证修复结果${NC}"

# 检查端口监听
echo "   检查端口监听..."
if netstat -tlnp | grep -q "0.0.0.0:3000"; then
    echo -e "   ${GREEN}端口3000已监听所有IP地址${NC}"
elif netstat -tlnp | grep -q ":3000"; then
    echo -e "   ${YELLOW}端口3000已监听，但可能不是所有IP${NC}"
    netstat -tlnp | grep ":3000"
else
    echo -e "   ${RED}端口3000未监听${NC}"
fi

# 测试连接
echo "   测试连接..."
if curl -s --connect-timeout 3 http://localhost:3000 > /dev/null; then
    echo -e "   localhost: ${GREEN}连接成功${NC}"
else
    echo -e "   localhost: ${RED}连接失败${NC}"
fi

# 获取服务器IP并测试
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ ! -z "$SERVER_IP" ]; then
    echo "   测试外部IP ($SERVER_IP)..."
    if curl -s --connect-timeout 3 http://$SERVER_IP:3000 > /dev/null; then
        echo -e "   $SERVER_IP:3000: ${GREEN}连接成功${NC}"
    else
        echo -e "   $SERVER_IP:3000: ${RED}连接失败${NC}"
    fi
fi

# 6. 显示访问信息
echo -e "${GREEN}5. 访问信息${NC}"
echo
echo -e "${YELLOW}现在您可以通过以下方式访问:${NC}"
echo "   本地访问: http://localhost:3000"
echo "   局域网访问: http://$SERVER_IP:3000"

# 检查是否有公网IP
PUBLIC_IP=$(curl -s --connect-timeout 3 ifconfig.me 2>/dev/null)
if [ ! -z "$PUBLIC_IP" ]; then
    echo "   公网访问: http://$PUBLIC_IP:3000"
    echo
    echo -e "${YELLOW}注意事项:${NC}"
    echo "   1. 如果公网仍无法访问，请检查云服务商的安全组设置"
    echo "   2. 确保安全组已开放3000端口的入站规则"
    echo "   3. 检查是否有其他网络设备阻止访问"
fi

echo
echo -e "${GREEN}修复完成!${NC}"
echo -e "${YELLOW}如果问题仍然存在，请运行诊断脚本:${NC}"
echo "   sudo ./network-diagnose.sh"