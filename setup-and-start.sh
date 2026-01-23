#!/bin/bash

# MoonTV 一键启动脚本 (Mac)
# 检查并安装所需环境，然后启动开发服务器

echo "🚀 MoonTV 一键启动脚本..."

# 检查并安装 Node.js
echo "检查 Node.js..."
if ! command -v node &> /dev/null; then
    echo "Node.js 未安装，正在安装..."
    # 使用 nvm 安装 Node.js 20
    if ! command -v nvm &> /dev/null; then
        echo "安装 nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    fi
    nvm install 20
    nvm use 20
    echo "Node.js 安装完成: $(node --version)"
else
    echo "Node.js 已安装: $(node --version)"
fi

# 检查并安装 pnpm
echo "检查 pnpm..."
if ! command -v pnpm &> /dev/null; then
    echo "pnpm 未安装，正在安装..."
    npm install -g pnpm
    echo "pnpm 安装完成: $(pnpm --version)"
else
    echo "pnpm 已安装: $(pnpm --version)"
fi

# 安装项目依赖
echo "安装项目依赖..."
pnpm install

# 检查安装是否成功
if [ $? -ne 0 ]; then
    echo "依赖安装失败，请检查错误信息"
    exit 1
fi

# 启动开发服务器
echo "启动 MoonTV 开发服务器..."
pnpm dev