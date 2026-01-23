#!/bin/bash

# MoonTV 项目开发启动脚本 (Mac)
# 用于启动开发服务器

echo "🚀 启动 MoonTV 开发服务器..."

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

# 启动开发服务器
echo "启动开发服务器..."
pnpm dev