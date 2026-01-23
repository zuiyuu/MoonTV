#!/bin/bash

# MoonTV 自动重启设置脚本 (Mac)
# 使用 PM2 设置生产服务自动后台重启

echo "🚀 设置 MoonTV 自动重启..."

# 检查是否安装了 Node.js 和 pnpm
if ! command -v node &> /dev/null || ! command -v pnpm &> /dev/null; then
    echo "错误: 需要先安装 Node.js 和 pnpm"
    echo "请运行 setup-and-start.sh 脚本"
    exit 1
fi

# 安装 PM2（如果未安装）
if ! command -v pm2 &> /dev/null; then
    echo "安装 PM2..."
    npm install -g pm2
fi

# 确保项目依赖已安装
echo "检查项目依赖..."
pnpm install

# 构建项目
echo "构建项目..."
pnpm build

# 检查构建是否成功
if [ $? -ne 0 ]; then
    echo "构建失败，请检查错误信息"
    exit 1
fi

# 停止现有 PM2 进程（如果存在）
pm2 delete moontv 2>/dev/null || true

# 启动应用
echo "使用 PM2 启动应用..."
pm2 start "pnpm start" --name moontv

# 保存进程列表
echo "保存进程列表..."
pm2 save

# 生成系统启动脚本
echo "生成系统启动脚本..."
pm2 startup launchd

echo "✅ 设置完成！"
echo "查看状态: pm2 status"
echo "查看日志: pm2 logs moontv"
echo "重启应用: pm2 restart moontv"