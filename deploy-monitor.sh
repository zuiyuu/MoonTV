#!/bin/bash

# MoonTV 监控和维护脚本

set -e

echo "🔧 配置MoonTV监控和维护..."

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

# 1. 创建健康检查脚本
echo -e "${GREEN}1. 创建健康检查脚本...${NC}"
cat > /opt/moontv/health-check.sh << 'EOF'
#!/bin/bash

# MoonTV健康检查脚本
LOG_FILE="/var/log/moontv-health.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# 检查服务状态
check_service() {
    if systemctl is-active --quiet moontv; then
        echo "[$DATE] MoonTV服务运行正常" >> $LOG_FILE
        return 0
    else
        echo "[$DATE] MoonTV服务异常，尝试重启" >> $LOG_FILE
        systemctl restart moontv
        sleep 5
        
        if systemctl is-active --quiet moontv; then
            echo "[$DATE] MoonTV服务重启成功" >> $LOG_FILE
        else
            echo "[$DATE] MoonTV服务重启失败" >> $LOG_FILE
            # 可以在这里添加告警通知
        fi
        return 1
    fi
}

# 检查端口连通性
check_port() {
    if curl -f http://localhost:3000 > /dev/null 2>&1; then
        echo "[$DATE] 端口3000连通正常" >> $LOG_FILE
        return 0
    else
        echo "[$DATE] 端口3000连通异常" >> $LOG_FILE
        return 1
    fi
}

# 检查磁盘空间
check_disk() {
    DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ $DISK_USAGE -gt 80 ]; then
        echo "[$DATE] 磁盘使用率过高: ${DISK_USAGE}%" >> $LOG_FILE
    fi
}

# 检查内存使用
check_memory() {
    MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ $MEMORY_USAGE -gt 80 ]; then
        echo "[$DATE] 内存使用率过高: ${MEMORY_USAGE}%" >> $LOG_FILE
    fi
}

# 执行检查
check_service
check_port
check_disk
check_memory

# 清理日志文件（保留最近7天）
find /var/log -name "moontv-*.log" -mtime +7 -delete 2>/dev/null || true
EOF

chmod +x /opt/moontv/health-check.sh

# 2. 创建备份脚本
echo -e "${GREEN}2. 创建备份脚本...${NC}"
cat > /opt/moontv/backup.sh << 'EOF'
#!/bin/bash

# MoonTV备份脚本
BACKUP_DIR="/opt/moontv/backup"
DATE=$(date '+%Y%m%d_%H%M%S')

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份配置文件
echo "备份配置文件..."
cp /opt/moontv/config.json $BACKUP_DIR/config_$DATE.json 2>/dev/null || true
cp /opt/moontv/.env.production $BACKUP_DIR/env_$DATE.production 2>/dev/null || true

# 备份Redis数据（如果使用Redis）
if systemctl is-active --quiet redis; then
    echo "备份Redis数据..."
    redis-cli BGSAVE
    sleep 2
    cp /var/lib/redis/dump.rdb $BACKUP_DIR/redis_$DATE.rdb 2>/dev/null || true
fi

# 备份Docker数据（如果使用Docker）
if command -v docker-compose &> /dev/null && [ -f "/opt/moontv/docker-compose.yml" ]; then
    echo "备份Docker数据..."
    docker run --rm -v moontv_redis_data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/redis_docker_$DATE.tar.gz -C /data .
fi

# 清理旧备份（保留最近7天）
find $BACKUP_DIR -name "*.json" -mtime +7 -delete 2>/dev/null || true
find $BACKUP_DIR -name "*.rdb" -mtime +7 -delete 2>/dev/null || true
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete 2>/dev/null || true

echo "备份完成: $BACKUP_DIR"
EOF

chmod +x /opt/moontv/backup.sh

# 3. 创建更新脚本
echo -e "${GREEN}3. 创建更新脚本...${NC}"
cat > /opt/moontv/update.sh << 'EOF'
#!/bin/bash

# MoonTV更新脚本
LOG_FILE="/var/log/moontv-update.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] 开始更新MoonTV..." >> $LOG_FILE

# 停止服务
echo "停止服务..."
systemctl stop moontv

# 备份当前版本
echo "备份当前版本..."
/opt/moontv/backup.sh

# 拉取最新代码
echo "拉取最新代码..."
cd /opt/moontv
git pull >> $LOG_FILE 2>&1

# 安装依赖
echo "安装依赖..."
sudo -u www-data pnpm install >> $LOG_FILE 2>&1

# 构建项目
echo "构建项目..."
sudo -u www-data pnpm build >> $LOG_FILE 2>&1

# 启动服务
echo "启动服务..."
systemctl start moontv

# 检查服务状态
sleep 5
if systemctl is-active --quiet moontv; then
    echo "[$DATE] MoonTV更新成功" >> $LOG_FILE
else
    echo "[$DATE] MoonTV更新失败" >> $LOG_FILE
    exit 1
fi

echo "更新完成"
EOF

chmod +x /opt/moontv/update.sh

# 4. 设置定时任务
echo -e "${GREEN}4. 设置定时任务...${NC}"

# 健康检查（每5分钟）
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/moontv/health-check.sh") | crontab -

# 备份任务（每天凌晨2点）
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/moontv/backup.sh") | crontab -

# 日志轮转配置
echo -e "${GREEN}5. 配置日志轮转...${NC}"
cat > /etc/logrotate.d/moontv << 'EOF'
/var/log/moontv*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        systemctl reload moontv || true
    endscript
}
EOF

# 6. 创建监控面板脚本
echo -e "${GREEN}6. 创建监控面板脚本...${NC}"
cat > /opt/moontv/status.sh << 'EOF'
#!/bin/bash

# MoonTV状态监控面板
clear

echo "=========================================="
echo "           MoonTV 状态监控面板            "
echo "=========================================="
echo

# 服务状态
echo -e "📊 服务状态:"
if systemctl is-active --quiet moontv; then
    echo -e "   MoonTV: \033[0;32m运行中\033[0m"
else
    echo -e "   MoonTV: \033[0;31m已停止\033[0m"
fi

if systemctl is-active --quiet redis; then
    echo -e "   Redis: \033[0;32m运行中\033[0m"
else
    echo -e "   Redis: \033[0;31m已停止\033[0m"
fi

if systemctl is-active --quiet nginx; then
    echo -e "   Nginx: \033[0;32m运行中\033[0m"
else
    echo -e "   Nginx: \033[0;31m已停止\033[0m"
fi

echo

# 系统资源
echo -e "💻 系统资源:"
echo "   CPU使用率: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')"
echo "   内存使用率: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
echo "   磁盘使用率: $(df / | awk 'NR==2 {print $5}')"

echo

# 端口状态
echo -e "🌐 端口状态:"
if netstat -tuln | grep -q ":3000 "; then
    echo -e "   3000端口: \033[0;32m监听中\033[0m"
else
    echo -e "   3000端口: \033[0;31m未监听\033[0m"
fi

if netstat -tuln | grep -q ":80 "; then
    echo -e "   80端口: \033[0;32m监听中\033[0m"
else
    echo -e "   80端口: \033[0;31m未监听\033[0m"
fi

if netstat -tuln | grep -q ":443 "; then
    echo -e "   443端口: \033[0;32m监听中\033[0m"
else
    echo -e "   443端口: \033[0;31m未监听\033[0m"
fi

echo

# 最近日志
echo -e "📝 最近日志 (最后5行):"
echo "----------------------------------------"
tail -5 /var/log/moontv-health.log 2>/dev/null || echo "暂无日志记录"

echo
echo "=========================================="
echo "管理命令:"
echo "  查看详细日志: sudo journalctl -u moontv -f"
echo "  重启服务: sudo systemctl restart moontv"
echo "  更新项目: sudo /opt/moontv/update.sh"
echo "  手动备份: sudo /opt/moontv/backup.sh"
echo "=========================================="
EOF

chmod +x /opt/moontv/status.sh

# 7. 创建快捷命令
echo -e "${GREEN}7. 创建快捷命令...${NC}"
cat > /usr/local/bin/moontv << 'EOF'
#!/bin/bash

case "$1" in
    start)
        sudo systemctl start moontv
        echo "MoonTV已启动"
        ;;
    stop)
        sudo systemctl stop moontv
        echo "MoonTV已停止"
        ;;
    restart)
        sudo systemctl restart moontv
        echo "MoonTV已重启"
        ;;
    status)
        sudo /opt/moontv/status.sh
        ;;
    logs)
        sudo journalctl -u moontv -f
        ;;
    update)
        sudo /opt/moontv/update.sh
        ;;
    backup)
        sudo /opt/moontv/backup.sh
        ;;
    *)
        echo "用法: moontv {start|stop|restart|status|logs|update|backup}"
        echo
        echo "命令说明:"
        echo "  start   - 启动MoonTV服务"
        echo "  stop    - 停止MoonTV服务"
        echo "  restart - 重启MoonTV服务"
        echo "  status  - 查看服务状态"
        echo "  logs    - 查看服务日志"
        echo "  update  - 更新项目"
        echo "  backup  - 备份数据"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/moontv

# 8. 设置权限
echo -e "${GREEN}8. 设置权限...${NC}"
chown -R www-data:www-data /opt/moontv

# 9. 显示配置信息
echo -e "${GREEN}🎉 监控和维护配置完成!${NC}"
echo
echo -e "${YELLOW}快捷命令:${NC}"
echo "  moontv status    - 查看服务状态"
echo "  moontv logs      - 查看服务日志"
echo "  moontv update    - 更新项目"
echo "  moontv backup    - 备份数据"
echo "  moontv restart   - 重启服务"
echo
echo -e "${YELLOW}定时任务:${NC}"
echo "  健康检查: 每5分钟执行一次"
echo "  数据备份: 每天凌晨2点执行一次"
echo "  日志轮转: 每天执行一次，保留7天"
echo
echo -e "${YELLOW}文件位置:${NC}"
echo "  健康检查: /opt/moontv/health-check.sh"
echo "  备份脚本: /opt/moontv/backup.sh"
echo "  更新脚本: /opt/moontv/update.sh"
echo "  状态面板: /opt/moontv/status.sh"
echo "  备份目录: /opt/moontv/backup/"
echo "  日志文件: /var/log/moontv-health.log"