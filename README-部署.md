# MoonTV Ubuntu 部署脚本使用说明

## 📁 文件说明

本目录包含了 MoonTV 在 Ubuntu 上部署的所有必要脚本和文档：

### 📄 文档文件

- `Ubuntu发布手顺.md` - 详细的部署文档和说明
- `README.md` - 本使用说明文件

### 🚀 部署脚本

- `deploy-docker.sh` - Docker 方式部署脚本
- `deploy-source.sh` - 源码方式部署脚本
- `deploy-nginx.sh` - Nginx 反向代理配置脚本
- `deploy-monitor.sh` - 监控和维护配置脚本

## 🛠️ 使用方法

### 方案一：Docker 部署（推荐）

```bash
# 1. 下载脚本
wget https://raw.githubusercontent.com/your-repo/MoonTV/main/deploy-docker.sh
chmod +x deploy-docker.sh

# 2. 运行部署脚本
sudo ./deploy-docker.sh

# 3. 配置Nginx（可选）
sudo ./deploy-nginx.sh

# 4. 配置监控（可选）
sudo ./deploy-monitor.sh
```

### 方案二：源码部署

```bash
# 1. 下载脚本
wget https://raw.githubusercontent.com/your-repo/MoonTV/main/deploy-source.sh
chmod +x deploy-source.sh

# 2. 运行部署脚本
sudo ./deploy-source.sh

# 3. 配置Nginx（可选）
sudo ./deploy-nginx.sh

# 4. 配置监控（可选）
sudo ./deploy-monitor.sh
```

### 方案三：分步部署

```bash
# 1. 基础部署（选择其中一种）
sudo ./deploy-docker.sh    # 或
sudo ./deploy-source.sh

# 2. 配置反向代理
sudo ./deploy-nginx.sh

# 3. 配置监控维护
sudo ./deploy-monitor.sh
```

## 📋 部署前准备

### 系统要求

- Ubuntu 18.04+ 或 Debian 10+
- 至少 1GB RAM
- 至少 5GB 磁盘空间
- 稳定的网络连接

### 端口要求

- 3000 端口：MoonTV 服务端口
- 80 端口：HTTP 访问（可选）
- 443 端口：HTTPS 访问（可选）

### 域名要求（可选）

- 如需使用域名访问，请提前将域名解析到服务器 IP

## 🔧 脚本功能说明

### deploy-docker.sh

- 自动安装 Docker 和 Docker Compose
- 创建 docker-compose.yml 配置
- 启动 MoonTV 和 Redis 容器
- 支持环境变量配置

### deploy-source.sh

- 自动安装 Node.js 20 和 pnpm
- 克隆项目源码
- 安装依赖并构建项目
- 创建 systemd 服务
- 支持 Redis 存储

### deploy-nginx.sh

- 自动安装 Nginx
- 配置反向代理
- 支持 SSL 证书自动申请和配置
- 优化安全设置

### deploy-monitor.sh

- 创建健康检查脚本
- 设置定时备份任务
- 配置日志轮转
- 创建监控面板
- 提供快捷管理命令

## 🎯 部署后管理

### 快捷命令

```bash
# 查看服务状态
moontv status

# 重启服务
moontv restart

# 查看日志
moontv logs

# 更新项目
moontv update

# 备份数据
moontv backup
```

### 手动管理

```bash
# Docker方式
cd /opt/moontv
docker-compose ps
docker-compose logs -f moontv-core
docker-compose restart

# 源码方式
sudo systemctl status moontv
sudo journalctl -u moontv -f
sudo systemctl restart moontv
```

## 🔒 安全配置

### 防火墙设置

```bash
# 启用UFW
sudo ufw enable

# 开放必要端口
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS

# 如果直接访问3000端口
sudo ufw allow 3000
```

### SSL 证书

- 脚本支持自动申请 Let's Encrypt 免费 SSL 证书
- 证书自动续期已配置
- 建议使用 HTTPS 访问

### 密码安全

- 部署时必须设置访问密码
- 建议使用强密码
- 定期更换密码

## 📊 监控和维护

### 自动监控

- 服务状态监控（每 5 分钟）
- 端口连通性检查
- 系统资源监控
- 自动重启异常服务

### 数据备份

- 配置文件自动备份
- Redis 数据自动备份
- 备份文件保留 7 天
- 支持手动备份

### 日志管理

- 应用日志自动轮转
- 保留最近 7 天日志
- 支持日志压缩
- 提供日志查看工具

## 🚨 故障排除

### 常见问题

#### 1. 服务无法启动

```bash
# 检查端口占用
sudo netstat -tlnp | grep 3000

# 检查服务状态
sudo systemctl status moontv

# 查看错误日志
sudo journalctl -u moontv -n 50
```

#### 2. 无法访问网站

```bash
# 检查防火墙
sudo ufw status

# 检查Nginx配置
sudo nginx -t

# 重启Nginx
sudo systemctl restart nginx
```

#### 3. Redis 连接失败

```bash
# 检查Redis状态
sudo systemctl status redis

# 测试Redis连接
redis-cli ping
```

#### 4. Docker 容器问题

```bash
# 查看容器状态
docker-compose ps

# 查看容器日志
docker-compose logs moontv-core

# 重启容器
docker-compose restart
```

### 日志位置

- 应用日志：`/var/log/moontv-health.log`
- 系统日志：`sudo journalctl -u moontv`
- Nginx 日志：`/var/log/nginx/`
- 备份目录：`/opt/moontv/backup/`

## 🔄 更新升级

### Docker 方式更新

```bash
cd /opt/moontv
docker-compose pull
docker-compose up -d
```

### 源码方式更新

```bash
# 使用更新脚本
sudo /opt/moontv/update.sh

# 或手动更新
cd /opt/moontv
git pull
sudo pnpm install
sudo pnpm build
sudo systemctl restart moontv
```

## 📞 技术支持

如遇到问题，请：

1. 查看相关日志文件
2. 检查系统资源使用情况
3. 参考故障排除章节
4. 提交 Issue 到项目仓库

## 📝 注意事项

1. **密码安全**：请务必设置强密码并妥善保管
2. **域名解析**：使用域名前请确保 DNS 已正确解析
3. **防火墙**：请正确配置防火墙规则
4. **备份**：建议定期备份重要数据
5. **更新**：及时更新到最新版本以获得安全修复

---

**最后更新**：2025 年 1 月
**版本**：v1.0.0
