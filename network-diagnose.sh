#!/bin/bash

# MoonTV网络诊断脚本
# 用于解决localhost可访问但固定IP无法访问的问题

set -e

echo "🔍 MoonTV网络诊断工具"
echo "========================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 检查服务状态
echo -e "${GREEN}1. 检查MoonTV服务状态${NC}"
if systemctl is-active --quiet moontv; then
    echo -e "   MoonTV服务: ${GREEN}运行中${NC}"
else
    echo -e "   MoonTV服务: ${RED}已停止${NC}"
    echo "   请先启动服务: sudo systemctl start moontv"
    exit 1
fi

# 2. 检查端口监听
echo -e "${GREEN}2. 检查端口监听状态${NC}"
if netstat -tlnp | grep -q ":3000 "; then
    echo -e "   3000端口: ${GREEN}监听中${NC}"
    netstat -tlnp | grep ":3000 " | while read line; do
        echo "   $line"
    done
else
    echo -e "   3000端口: ${RED}未监听${NC}"
    exit 1
fi

# 3. 检查监听地址
echo -e "${GREEN}3. 检查监听地址配置${NC}"
LISTEN_IP=$(netstat -tlnp | grep ":3000 " | awk '{print $4}' | cut -d: -f1)
echo "   当前监听IP: $LISTEN_IP"

if [ "$LISTEN_IP" = "127.0.0.1" ] || [ "$LISTEN_IP" = "::1" ]; then
    echo -e "   ${RED}问题发现: 服务只监听localhost，无法通过外部IP访问${NC}"
    echo -e "   ${YELLOW}解决方案: 需要修改配置监听所有IP地址 (0.0.0.0)${NC}"
    
    # 4. 修复监听配置
    echo -e "${GREEN}4. 修复监听配置${NC}"
    
    # 检查是否为Docker部署
    if command -v docker-compose &> /dev/null && [ -f "/opt/moontv/docker-compose.yml" ]; then
        echo "   检测到Docker部署，修复Docker配置..."
        
        # 备份原配置
        cp /opt/moontv/docker-compose.yml /opt/moontv/docker-compose.yml.backup
        
        # 修复端口映射
        sed -i "s/- '3000:3000'/- '0.0.0.0:3000:3000'/g" /opt/moontv/docker-compose.yml
        
        echo "   重启Docker容器..."
        cd /opt/moontv
        docker-compose restart
        
    elif [ -f "/etc/systemd/system/moontv.service" ]; then
        echo "   检测到源码部署，修复systemd配置..."
        
        # 检查环境变量
        if ! grep -q "HOSTNAME=0.0.0.0" /opt/moontv/.env.production; then
            echo "HOSTNAME=0.0.0.0" >> /opt/moontv/.env.production
        fi
        
        echo "   重启MoonTV服务..."
        systemctl restart moontv
    fi
    
    # 等待服务重启
    sleep 5
    
    # 重新检查
    if netstat -tlnp | grep -q "0.0.0.0:3000 "; then
        echo -e "   ${GREEN}修复成功: 现在监听所有IP地址${NC}"
    else
        echo -e "   ${RED}修复失败: 请手动检查配置${NC}"
    fi
else
    echo -e "   ${GREEN}监听配置正常${NC}"
fi

# 5. 检查防火墙
echo -e "${GREEN}5. 检查防火墙配置${NC}"
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status | head -1)
    echo "   UFW状态: $UFW_STATUS"
    
    if ufw status | grep -q "3000"; then
        echo -e "   3000端口: ${GREEN}已开放${NC}"
    else
        echo -e "   3000端口: ${YELLOW}未开放${NC}"
        echo "   建议开放端口: sudo ufw allow 3000"
    fi
else
    echo "   UFW未安装"
fi

# 检查iptables
if command -v iptables &> /dev/null; then
    if iptables -L INPUT | grep -q "3000"; then
        echo -e "   iptables 3000端口: ${GREEN}已开放${NC}"
    else
        echo -e "   iptables 3000端口: ${YELLOW}未开放${NC}"
    fi
fi

# 6. 获取网络信息
echo -e "${GREEN}6. 网络信息${NC}"
echo "   服务器IP地址:"
hostname -I | while read ip; do
    echo "     - $ip:3000"
done

# 7. 测试连接
echo -e "${GREEN}7. 连接测试${NC}"
echo "   测试localhost连接..."
if curl -s --connect-timeout 3 http://localhost:3000 > /dev/null; then
    echo -e "   localhost: ${GREEN}连接成功${NC}"
else
    echo -e "   localhost: ${RED}连接失败${NC}"
fi

# 测试外部IP
EXTERNAL_IP=$(hostname -I | awk '{print $1}')
if [ ! -z "$EXTERNAL_IP" ]; then
    echo "   测试外部IP连接 ($EXTERNAL_IP)..."
    if curl -s --connect-timeout 3 http://$EXTERNAL_IP:3000 > /dev/null; then
        echo -e "   $EXTERNAL_IP:3000: ${GREEN}连接成功${NC}"
    else
        echo -e "   $EXTERNAL_IP:3000: ${RED}连接失败${NC}"
    fi
fi

# 8. 提供解决方案
echo -e "${GREEN}8. 解决方案${NC}"
echo "   如果外部IP仍无法访问，请尝试以下步骤:"
echo
echo "   a) 检查云服务器安全组:"
echo "      - 登录云服务商控制台"
echo "      - 找到实例的安全组设置"
echo "      - 添加入站规则: 端口3000, 协议TCP, 来源0.0.0.0/0"
echo
echo "   b) 检查防火墙设置:"
echo "      sudo ufw allow 3000"
echo "      # 或"
echo "      sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT"
echo
echo "   c) 检查服务配置:"
echo "      # 确保Next.js监听所有IP"
echo "      export HOSTNAME=0.0.0.0"
echo "      export PORT=3000"
echo
echo "   d) 重启服务:"
echo "      sudo systemctl restart moontv"
echo "      # 或"
echo "      cd /opt/moontv && docker-compose restart"

echo
echo -e "${GREEN}诊断完成!${NC}"
echo -e "${YELLOW}请根据上述信息检查和修复配置${NC}"