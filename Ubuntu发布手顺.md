# MoonTV Ubuntu 发布手顺

## 📋 项目启动分析

### 项目基本信息

- **项目类型**: Next.js 14 + TypeScript + Tailwind CSS
- **包管理器**: pnpm 10.14.0
- **Node.js 版本**: v20.10.0+
- **主要功能**: 影视聚合播放器，支持多源搜索、在线播放、收藏同步

### 启动方式

#### 1. 开发环境启动

```bash
# 安装依赖
pnpm install

# 生成运行时配置和PWA清单
pnpm gen:runtime && pnpm gen:manifest

# 启动开发服务器（监听所有IP）
pnpm dev
```

#### 2. 生产环境启动

```bash
# 构建项目
pnpm build

# 启动生产服务器
pnpm start
```

#### 3. Docker 启动

```bash
# 拉取预构建镜像
docker pull ghcr.io/lunatechlab/moontv:latest

# 运行容器
docker run -d --name moontv -p 3000:3000 --env PASSWORD=your_password ghcr.io/lunatechlab/moontv:latest
```

## 🐧 Ubuntu 发布手顺

### 方案一：Docker 部署（推荐）

#### 1. 系统准备

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装Docker Compose
sudo apt install docker-compose -y

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker
```

#### 2. 创建 Docker Compose 配置

```bash
# 创建项目目录
mkdir -p /opt/moontv
cd /opt/moontv

# 创建docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  moontv-core:
    image: ghcr.io/lunatechlab/moontv:latest
    container_name: moontv-core
    restart: unless-stopped
    ports:
      - '3000:3000'
    environment:
      - PASSWORD=your_secure_password
      - NEXT_PUBLIC_SITE_NAME=MyMoonTV
      - NEXT_PUBLIC_STORAGE_TYPE=redis
      - REDIS_URL=redis://moontv-redis:6379
      - NEXT_PUBLIC_ENABLE_REGISTER=false
    networks:
      - moontv-network
    depends_on:
      - moontv-redis
    volumes:
      - ./config.json:/app/config.json:ro

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
```

#### 3. 启动服务

```bash
# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f moontv-core
```

### 方案二：源码部署

#### 1. 环境准备

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 安装pnpm
npm install -g pnpm

# 安装Redis（可选，用于持久化存储）
sudo apt install redis-server -y
sudo systemctl start redis
sudo systemctl enable redis
```

#### 2. 部署应用

```bash
# 创建项目目录
sudo mkdir -p /opt/moontv
sudo chown $USER:$USER /opt/moontv
cd /opt/moontv

# 克隆项目
git clone https://github.com/LunaTechLab/MoonTV.git .

# 安装依赖
pnpm install

# 构建项目
pnpm build

# 创建环境变量文件
sudo cat > .env.production << 'EOF'
NODE_ENV=production
PASSWORD=1122
NEXT_PUBLIC_SITE_NAME=HomeMoonTV
NEXT_PUBLIC_STORAGE_TYPE=redis
REDIS_URL=redis://localhost:6379
NEXT_PUBLIC_ENABLE_REGISTER=false
EOF
```

#### 3. 创建系统服务

```bash
# 创建systemd服务文件
sudo cat > /etc/systemd/system/moontv.service << 'EOF'
[Unit]
Description=MoonTV Video Streaming Service
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/root/MoonTV
Environment=NODE_ENV=production
EnvironmentFile=/root/MoonTV/.env.production
ExecStart=/usr/bin/pnpm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 设置权限
sudo chown -R www-data:www-data /root/MoonTV

# 启动服务
sudo systemctl daemon-reload
sudo systemctl start moontv
sudo systemctl enable moontv
```

### 方案三：Nginx 反向代理配置

#### 1. 安装 Nginx

```bash
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
```

#### 2. 配置反向代理

```bash
# 创建Nginx配置
sudo cat > /etc/nginx/sites-available/moontv << 'EOF'
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# 启用站点
sudo ln -s /etc/nginx/sites-available/moontv /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 方案四：SSL 证书配置（可选）

#### 1. 安装 Certbot

```bash
sudo apt install certbot python3-certbot-nginx -y
```

#### 2. 获取 SSL 证书

```bash
sudo certbot --nginx -d your-domain.com
```

### 监控和维护

#### 1. 创建监控脚本

```bash
# 创建健康检查脚本
cat > /opt/moontv/health-check.sh << 'EOF'
#!/bin/bash
if ! curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "MoonTV is down, restarting..."
    sudo systemctl restart moontv
fi
EOF

chmod +x /opt/moontv/health-check.sh

# 添加到crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/moontv/health-check.sh") | crontab -
```

#### 2. 日志管理

```bash
# 配置日志轮转
sudo cat > /etc/logrotate.d/moontv << 'EOF'
/opt/moontv/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
}
EOF
```

## 🔧 重要配置说明

### 环境变量配置

- `PASSWORD`: 必须设置，用于访问控制
- `NEXT_PUBLIC_STORAGE_TYPE`: 存储类型（localstorage/redis/upstash）
- `NEXT_PUBLIC_SITE_NAME`: 站点名称
- `NEXT_PUBLIC_ENABLE_REGISTER`: 是否允许注册

### 安全建议

1. 设置强密码
2. 关闭公网注册
3. 使用 HTTPS
4. 定期更新镜像
5. 配置防火墙

### 访问地址

- HTTP: `http://your-server-ip:3000`
- HTTPS: `https://your-domain.com`
- 管理页面: `https://your-domain.com/admin`

## 📝 部署检查清单

### 部署前检查

- [ ] Ubuntu 系统已更新
- [ ] 防火墙已配置（开放 3000 端口）
- [ ] 域名已解析到服务器 IP（如使用域名）
- [ ] SSL 证书已申请（如需要 HTTPS）

### 部署后检查

- [ ] 服务正常启动
- [ ] 网站可正常访问
- [ ] 密码保护已生效
- [ ] 数据库连接正常
- [ ] 日志记录正常

### 故障排除

1. **服务无法启动**: 检查端口占用和权限设置
2. **无法访问**: 检查防火墙和 Nginx 配置
3. **数据库连接失败**: 检查 Redis 服务状态
4. **页面显示异常**: 检查环境变量配置

## 🔄 更新和维护

### 更新 Docker 版本

```bash
cd /opt/moontv
docker-compose pull
docker-compose up -d
```

### 更新源码版本

```bash
cd /opt/moontv
git pull
pnpm install
pnpm build
sudo systemctl restart moontv
```

### 备份数据

```bash
# Redis数据备份
redis-cli BGSAVE
cp /var/lib/redis/dump.rdb /opt/moontv/backup/

# 配置文件备份
cp /opt/moontv/config.json /opt/moontv/backup/
```

---

**注意**: 请根据实际需求修改配置文件中的密码、域名等敏感信息。
