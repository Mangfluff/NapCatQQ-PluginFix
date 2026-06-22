#!/bin/bash
# NapCatQQ-PluginFix 一键更新脚本（从原版 NapCat 更新到 PluginFix 改版）
# 用法: bash <(curl -sL https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/update.sh)
#   或: curl -sL https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/update.sh | bash
#   或: bash update.sh [NapCat安装目录]

set -e

# ============== 颜色输出 ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
title() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}\n"; }

# ============== 配置 ==============
REPO_OWNER="Mangfluff"
REPO_NAME="NapCatQQ-PluginFix"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}.git"
BUILD_DIR="/tmp/NapCatQQ-PluginFix-build"
NODE_MIN_VERSION="18"

# ============== 检测 NapCat 安装目录 ==============
detect_install_dir() {
  # 如果传入了参数，直接使用
  if [ -n "$1" ] && [ -d "$1" ]; then
    INSTALL_DIR="$1"
    return 0
  fi

  # 自动检测策略
  CANDIDATES=()

  # 1. 当前目录（最常见）
  if [ -f "package.json" ] && grep -q "napcat" "package.json" 2>/dev/null; then
    CANDIDATES+=("$(pwd)")
  fi

  # 2. 常见安装路径
  for dir in \
    "$HOME/NapCatQQ" \
    "$HOME/NapCat" \
    "$HOME/napcat" \
    "$HOME/napcatqq" \
    "$HOME/NapCatQQ-PluginFix" \
    "/opt/NapCatQQ" \
    "/opt/napcat" \
    "/usr/local/napcat"; do
    if [ -f "$dir/package.json" ] && grep -q "napcat" "$dir/package.json" 2>/dev/null; then
      CANDIDATES+=("$dir")
    fi
  done

  # 去重
  UNIQUE_CANDIDATES=()
  for c in "${CANDIDATES[@]}"; do
    seen=false
    for u in "${UNIQUE_CANDIDATES[@]}"; do
      [ "$u" = "$c" ] && seen=true
    done
    $seen || UNIQUE_CANDIDATES+=("$c")
  done

  if [ ${#UNIQUE_CANDIDATES[@]} -eq 0 ]; then
    return 1
  elif [ ${#UNIQUE_CANDIDATES[@]} -eq 1 ]; then
    INSTALL_DIR="${UNIQUE_CANDIDATES[0]}"
    info "自动检测到 NapCat 安装目录: ${INSTALL_DIR}"
    return 0
  else
    echo "检测到多个可能的 NapCat 安装目录:"
    for i in "${!UNIQUE_CANDIDATES[@]}"; do
      echo "  [$((i+1))] ${UNIQUE_CANDIDATES[$i]}"
    done
    read -p "请选择 (1-${#UNIQUE_CANDIDATES[@]}): " SELECTION
    INSTALL_DIR="${UNIQUE_CANDIDATES[$((SELECTION-1))]}"
    return 0
  fi
}

# ============== 检查依赖 ==============
check_deps() {
  if ! command -v node &>/dev/null; then
    error "Node.js 未安装，请先安装 Node.js v${NODE_MIN_VERSION}+"
    exit 1
  fi
  NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VER" -lt "$NODE_MIN_VERSION" ]; then
    error "Node.js 版本过低 (v$(node -v))，需要 v${NODE_MIN_VERSION}+"
    exit 1
  fi
  info "Node.js $(node -v) ✓"

  if ! command -v git &>/dev/null; then
    error "Git 未安装"
    exit 1
  fi
  info "Git $(git --version | head -1) ✓"

  if ! command -v pnpm &>/dev/null; then
    warn "pnpm 未安装，正在安装..."
    npm install -g pnpm
  fi
  info "pnpm $(pnpm -v) ✓"
}

# ============== 备份配置 ==============
backup_config() {
  local backup_dir="${INSTALL_DIR}/.backup-$(date +%Y%m%d%H%M%S)"
  info "备份配置文件和插件到: ${backup_dir}"

  mkdir -p "$backup_dir"
  [ -d "${INSTALL_DIR}/config" ] && cp -r "${INSTALL_DIR}/config" "$backup_dir/config"
  [ -d "${INSTALL_DIR}/plugins" ] && cp -r "${INSTALL_DIR}/plugins" "$backup_dir/plugins"
  [ -f "${INSTALL_DIR}/.env" ] && cp "${INSTALL_DIR}/.env" "$backup_dir/.env"

  info "备份完成: ${backup_dir}"
  BACKUP_DIR="$backup_dir"
}

# ============== 构建新版 ==============
build_new_version() {
  title "步骤 2/4: 下载并构建 PluginFix 改版"

  # 清理旧的构建目录
  rm -rf "$BUILD_DIR"

  info "克隆仓库 (深度 1)..."
  git clone --depth 1 "$REPO_URL" "$BUILD_DIR"
  cd "$BUILD_DIR"

  info "安装依赖..."
  pnpm install --frozen-lockfile 2>/dev/null || pnpm install

  info "构建项目..."
  pnpm build:plugin-builtin 2>/dev/null || warn "内置插件构建跳过"
  pnpm build:webui 2>/dev/null || warn "WebUI 构建跳过"
  pnpm build:shell 2>/dev/null || warn "Shell 构建跳过"
  pnpm build:framework 2>/dev/null || warn "Framework 构建跳过"

  info "构建完成"
}

# ============== 更新安装 ==============
update_installation() {
  title "步骤 3/4: 更新到 PluginFix 改版"

  # 找到需要替换的文件列表（排除 config、plugins、data 目录）
  info "将新版文件部署到: ${INSTALL_DIR}"

  # 使用 rsync 或 cp 复制文件，排除配置和插件目录
  local exclude_opts=""
  for exclude in config plugins data .backup-* node_modules .git; do
    exclude_opts="$exclude_opts --exclude=$exclude"
  done

  # 复制构建目录的文件到安装目录
  if command -v rsync &>/dev/null; then
    rsync -av $exclude_opts "${BUILD_DIR}/" "${INSTALL_DIR}/" 2>&1 | tail -5
  else
    # 使用 find + cp 方式（兼容性更好）
    find "${BUILD_DIR}" -maxdepth 1 -not -name "config" -not -name "plugins" -not -name "data" \
      -not -name ".backup-*" -not -name "node_modules" -not -name ".git" \
      -not -name "." -not -name ".." \
      -exec cp -r {} "${INSTALL_DIR}/" \; 2>/dev/null
  fi

  # 合并 package.json 中的关键字段
  info "合并配置..."

  # 确保 config/webui.json 包含新字段
  local webui_config="${INSTALL_DIR}/config/webui.json"
  if [ -f "$webui_config" ]; then
    # 添加新字段（如果不存在）
    local has_enableKeyAuth=$(python3 -c "import json; f=open('$webui_config'); d=json.load(f); print('enableKeyAuth' in d)" 2>/dev/null || echo "false")
    if [ "$has_enableKeyAuth" = "False" ] || [ "$has_enableKeyAuth" = "false" ]; then
      info "添加 enableKeyAuth 配置项到 webui.json..."
      python3 -c "
import json
f=open('$webui_config')
d=json.load(f)
d['enableKeyAuth'] = d.get('enableKeyAuth', True)
d['hotReloadInterval'] = d.get('hotReloadInterval', 0)
f=open('$webui_config','w')
json.dump(d,f,indent=4)
" 2>/dev/null || true
    fi
  fi

  info "更新完成"
}

# ============== 恢复配置 ==============
restore_config() {
  title "步骤 4/4: 恢复配置和插件"

  if [ -d "${BACKUP_DIR}/config" ]; then
    # 合并配置（不覆盖已存在的文件）
    for f in "${BACKUP_DIR}/config/"*; do
      [ -f "$f" ] || continue
      local basename=$(basename "$f")
      if [ ! -f "${INSTALL_DIR}/config/$basename" ]; then
        cp "$f" "${INSTALL_DIR}/config/$basename"
        info "恢复配置: config/$basename"
      fi
    done
  fi

  if [ -d "${BACKUP_DIR}/plugins" ]; then
    # 恢复所有插件
    cp -r "${BACKUP_DIR}/plugins/"* "${INSTALL_DIR}/plugins/" 2>/dev/null || true
    info "已恢复插件目录"
  fi

  if [ -f "${BACKUP_DIR}/.env" ]; then
    cp "${BACKUP_DIR}/.env" "${INSTALL_DIR}/.env"
    info "已恢复 .env"
  fi
}

# ============== 显示结果 ==============
show_result() {
  local old_version=$(cat "${INSTALL_DIR}/package.json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','?'))" 2>/dev/null || echo "?")

  echo
  echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║       NapCatQQ-PluginFix 改版 更新完成！        ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
  echo
  info "安装目录: ${INSTALL_DIR}"
  info "配置已备份: ${BACKUP_DIR}"
  echo
  echo -e "${CYAN}现在可以重启 NapCat 使用了！${NC}"
  echo
  echo -e "  ${YELLOW}Shell 模式启动:${NC}"
  echo -e "  cd ${INSTALL_DIR}"
  echo -e "  node index.js"
  echo
  echo -e "  ${YELLOW}WebUI 管理页面:${NC}"
  echo -e "  http://localhost:6099/webui"
  echo
  echo -e "  ${YELLOW}如果遇到问题，恢复备份:${NC}"
  echo -e "  cp -r ${BACKUP_DIR}/config ${INSTALL_DIR}/"
  echo -e "  cp -r ${BACKUP_DIR}/plugins ${INSTALL_DIR}/"
  echo
  echo -e "${BLUE}PluginFix 改版特性:${NC}"
  echo -e "  ✓ 纯第三方插件支持（移除白名单限制）"
  echo -e "  ✓ WebUI 插件上传功能已恢复"
  echo -e "  ✓ 插件定时热重载 (Hot Reload)"
  echo -e "  ✓ WebUI 鉴权可关闭 (enableKeyAuth)"
  echo
}

# ============== 主流程 ==============
main() {
  title "NapCatQQ-PluginFix 改版一键更新脚本"
  echo -e "  从原版 NapCat 更新到 ${CYAN}PluginFix 改版${NC}"
  echo -e "  仓库: ${REPO_URL}"
  echo

  # 检测安装目录
  if ! detect_install_dir "$1"; then
    # 尝试找 .napcat 标识文件
    if [ -d "./node_modules/napcat" ] || [ -f "./napcat.mjs" ] || [ -d "./packages/napcat-onebot" ]; then
      INSTALL_DIR=$(pwd)
      info "检测到当前目录包含 NapCat 文件: ${INSTALL_DIR}"
    else
      error "未检测到 NapCat 安装目录！"
      echo ""
      echo "使用方法:"
      echo "  1. cd 到你安装 NapCat 的目录，然后运行:"
      echo "     bash <(curl -sL https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/update.sh)"
      echo ""
      echo "  2. 或直接指定安装目录:"
      echo "     bash update.sh /path/to/napcat"
      echo ""
      exit 1
    fi
  fi

  read -p "即将更新: ${INSTALL_DIR}，是否继续？(Y/n): " CONFIRM
  if [ "$CONFIRM" = "n" ] || [ "$CONFIRM" = "N" ]; then
    info "已取消"
    exit 0
  fi

  check_deps
  backup_config
  build_new_version
  update_installation
  restore_config
  show_result
}

main "$@"