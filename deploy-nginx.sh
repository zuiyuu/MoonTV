#!/bin/bash

# MoonTV Nginx反向代理配置脚本
# 适用于Ubuntu系统

set -e

echo "🌐 配置Nginx反向代理..."

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
read -p "请输入域名: " DOMAIN_NAME
read -p "是否配置SSL证书? (y/n): " INSTALL_SSL

if [ -z "$DOMAIN_NAME" ]; then
    echo -e "${RED}域名不能为空${NC}"
    exit 1
fi

echo -e "${YELLOW}配置信息:${NC}"
echo "域名: $DOMAIN_NAME"
echo "配置SSL: $INSTALL_SSL"

# 确认配置
read -p "确认配置? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "配置已取消"
    exit 1
fi

# 1. 安装Nginx
echo -e "${GREEN}1. 安装Nginx...${NC}"
if ! command -v nginx &> /dev/null; then
    apt install nginx -y
    systemctl start nginx
    systemctl enable nginx
else
    echo "Nginx已安装"
fi

# 2. 创建Nginx配置
echo -e "${GREEN}2. 创建Nginx配置...${NC}"

if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
    # SSL配置
    cat > /etc/nginx/sites-available/moontv << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
else
    # HTTP配置
    cat > /etc/nginx/sites-available/moontv << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
fi

# 3. 启用站点
echo -e "${GREEN}3. 启用站点...${NC}"
ln -sf /etc/nginx/sites-available/moontv /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 4. 测试配置
echo -e "${GREEN}4. 测试Nginx配置...${NC}"
nginx -t

# 5. 重启Nginx
echo -e "${GREEN}5. 重启Nginx...${NC}"
systemctl reload nginx

# 6. 配置SSL证书（如果需要）
if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}6. 配置SSL证书...${NC}"
    
    # 安装Certbot
    apt install certbot python3-certbot-nginx -y
    
    # 获取SSL证书
    echo -e "${YELLOW}正在获取SSL证书...${NC}"
    certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME
    
    # 设置自动续期
    echo -e "${GREEN}7. 设置SSL证书自动续期...${NC}"
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
fi

# 7. 配置防火墙
echo -e "${GREEN}8. 配置防火墙...${NC}"
if command -v ufw &> /dev/null; then
    ufw allow 'Nginx Full'
    ufw --force enable
fi

# 8. 显示配置信息
echo -e "${GREEN}🎉 Nginx配置完成!${NC}"
echo -e "${YELLOW}访问地址:${NC}"

if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
    echo "HTTPS: https://$DOMAIN_NAME"
    echo "HTTP将自动重定向到HTTPS"
else
    echo "HTTP: http://$DOMAIN_NAME"
fi

echo -e "${YELLOW}管理命令:${NC}"
echo "测试配置: sudo nginx -t"
echo "重载配置: sudo systemctl reload nginx"
echo "重启Nginx: sudo systemctl restart nginx"
echo "查看状态: sudo systemctl status nginx"
echo "查看日志: sudo tail -f /var/log/nginx/access.log"

if [[ $INSTALL_SSL =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}SSL管理:${NC}"
    echo "手动续期: sudo certbot renew"
    echo "测试续期: sudo certbot renew --dry-run"
fi

echo -e "${YELLOW}安全提醒:${NC}"
echo "1. 确保域名已正确解析到服务器"
echo "2. 检查防火墙配置"
echo "3. 定期检查SSL证书状态"