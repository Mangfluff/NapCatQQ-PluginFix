#!/bin/bash
# NapCatQQ-PluginFix Linux 一键安装脚本
# 使用方式: bash <(curl -sL https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/install.sh)
# 或者: curl -sL https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/install.sh | bash

set -e

# ============== 颜色输出 ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
title() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}========================================${NC}\n"; }

# ============== 配置 ==============
REPO_OWNER="Mangfluff"
REPO_NAME="NapCatQQ-PluginFix"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
INSTALL_DIR="${INSTALL_DIR:-$HOME/${REPO_NAME}}"
NODE_MIN_VERSION="18"

# ============== 检测系统 ==============
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
  elif command -v sw_vers &>/dev/null; then
    OS="macos"
  else
    OS="unknown"
  fi
  echo "检测到系统: $OS $OS_VERSION"
}

# ============== 检测依赖 ==============
check_dependencies() {
  title "检查依赖环境"

  # 检查 Node.js
  if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v | sed 's/v//')
    info "Node.js 已安装: v${NODE_VERSION}"
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$NODE_MAJOR" -lt "$NODE_MIN_VERSION" ]; then
      error "Node.js 版本过低，需要 v${NODE_MIN_VERSION}+，当前 v${NODE_VERSION}"
      exit 1
    fi
  else
    error "Node.js 未安装，请先安装 Node.js v${NODE_MIN_VERSION}+"
    echo "  推荐使用 nvm 安装:"
    echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
    echo "  nvm install 20"
    exit 1
  fi

  # 检查 pnpm
  if command -v pnpm &>/dev/null; then
    PNPM_VERSION=$(pnpm -v)
    info "pnpm 已安装: v${PNPM_VERSION}"
  else
    warn "pnpm 未安装，正在安装..."
    npm install -g pnpm
    info "pnpm 安装完成"
  fi

  # 检查 git
  if command -v git &>/dev/null; then
    GIT_VERSION=$(git --version)
    info "Git 已安装: ${GIT_VERSION}"
  else
    error "Git 未安装，请先安装 Git"
    exit 1
  fi
}

# ============== 克隆仓库 ==============
clone_repo() {
  title "克隆仓库"

  if [ -d "$INSTALL_DIR" ]; then
    warn "目标目录已存在: $INSTALL_DIR"
    read -p "是否覆盖？(y/N): " OVERWRITE
    if [ "$OVERWRITE" = "y" ] || [ "$OVERWRITE" = "Y" ]; then
      rm -rf "$INSTALL_DIR"
    else
      info "使用已有目录"
      cd "$INSTALL_DIR"
      git pull
      return
    fi
  fi

  info "克隆 ${REPO_URL} 到 ${INSTALL_DIR}..."
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
  info "克隆完成"
}

# ============== 安装依赖 ==============
install_deps() {
  title "安装依赖"

  cd "$INSTALL_DIR"

  info "安装项目依赖..."
  pnpm install --frozen-lockfile 2>/dev/null || pnpm install

  info "依赖安装完成"
}

# ============== 构建项目 ==============
build_project() {
  title "构建项目"

  cd "$INSTALL_DIR"

  info "构建内置插件..."
  pnpm build:plugin-builtin 2>/dev/null || echo "  [WARN] 内置插件构建失败（可跳过）"

  info "构建 WebUI..."
  pnpm build:webui 2>/dev/null || echo "  [WARN] WebUI 构建失败（可跳过）"

  info "构建 Shell 模式..."
  pnpm build:shell 2>/dev/null || warn "Shell 构建失败"

  info "构建 Framework 模式..."
  pnpm build:framework 2>/dev/null || warn "Framework 构建失败"

  info "构建完成"
}

# ============== 配置环境 ==============
setup_env() {
  title "配置环境"

  cd "$INSTALL_DIR"

  # 创建工作目录
  mkdir -p config plugins

  # 生成默认配置文件
  if [ ! -f config/napcat.json ]; then
    echo '{}' > config/napcat.json
    info "已创建默认 napcat.json 配置"
  fi

  if [ ! -f config/webui.json ]; then
    cat > config/webui.json << 'WEBUI_EOF'
{
    "host": "::",
    "port": 6099,
    "token": "",
    "loginRate": 10,
    "enable2FA": false,
    "enableKeyAuth": true,
    "hotReloadInterval": 0
}
WEBUI_EOF
    info "已创建默认 webui.json 配置"
  fi

  echo
  info "=========================================="
  info "  NapCatQQ-PluginFix 安装完成！"
  info "  安装目录: ${INSTALL_DIR}"
  info ""
  info "  启动方式:"
  info "  Shell 模式: cd ${INSTALL_DIR} && node index.js"
  info "  更多信息请查看 README.md"
  info "=========================================="
  echo
}

# ============== 显示使用说明 ==============
show_usage() {
  echo
  info "安装完成后使用方式:"
  echo ""
  echo "  cd ${INSTALL_DIR}"
  echo "  # Shell 模式启动"
  echo "  node index.js"
  echo ""
  echo "  # 或使用 WebUI 管理界面 (浏览器打开)"
  echo "  # http://localhost:6099/webui"
  echo ""
}

# ============== 主流程 ==============
main() {
  title "NapCatQQ-PluginFix 一键安装脚本"
  echo "  仓库: ${REPO_URL}"
  echo "  安装到: ${INSTALL_DIR}"
  echo

  detect_os
  check_dependencies
  clone_repo
  install_deps
  build_project
  setup_env
  show_usage
}

main "$@"