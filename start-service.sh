#!/bin/bash

# MoonTV 服务生产启动脚本 (Mac)
# 用于构建和启动生产服务

echo "🚀 构建并启动 MoonTV 生产服务..."

# 检查是否安装了 pnpm
if ! command -v pnpm &> /dev/null; then
    echo "错误: 未找到 pnpm，请先安装 pnpm"
    exit 1
fi

# 安装依赖
echo "正在安装依赖..."
pnpm install

# 检查安装是否成功
if [ $? -ne 0 ]; then
    echo "依赖安装失败，请检查错误信息"
    exit 1
fi

# 构建项目
echo "正在构建项目..."
pnpm build

# 检查构建是否成功
if [ $? -ne 0 ]; then
    echo "构建失败，请检查错误信息"
    exit 1
fi

# 创建环境变量文件（如果不存在）
if [ ! -f .env.production ]; then
    echo "创建生产环境变量文件..."
    cat > .env.production << EOF
NODE_ENV=production
NEXT_PUBLIC_STORAGE_TYPE=localstorage
NEXT_PUBLIC_ENABLE_REGISTER=false
EOF
fi

# 启动生产服务
echo "启动生产服务..."
pnpm start