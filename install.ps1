# NapCatQQ-PluginFix Windows PowerShell 安装脚本
# 使用方式: powershell -c "irm https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/install.ps1 | iex"

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$REPO_OWNER = "Mangfluff"
$REPO_NAME = "NapCatQQ-PluginFix"
$REPO_URL = "https://github.com/$REPO_OWNER/$REPO_NAME.git"
$INSTALL_DIR = [IO.Path]::Combine($env:USERPROFILE, $REPO_NAME)
$NODE_MIN_VERSION = 18

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  NapCatQQ-PluginFix Windows 安装程序" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""
Write-Host "  仓库: $REPO_URL" -ForegroundColor Gray
Write-Host "  安装到: $INSTALL_DIR" -ForegroundColor Gray
Write-Host ""

# ============== 检查 Node.js ==============
Write-Host "[检查] 检测 Node.js..." -ForegroundColor Yellow
try {
    $nodeVersion = node -v
    $nodeMajor = [int]($nodeVersion -replace 'v', '' -replace '\..*', '')
    Write-Host "[信息] Node.js 已安装: $nodeVersion" -ForegroundColor Green
    if ($nodeMajor -lt $NODE_MIN_VERSION) {
        Write-Host "[错误] Node.js 版本过低，需要 v$NODE_MIN_VERSION+，当前 $nodeVersion" -ForegroundColor Red
        pause
        exit 1
    }
} catch {
    Write-Host "[错误] Node.js 未安装！请先安装 Node.js v$NODE_MIN_VERSION+" -ForegroundColor Red
    Write-Host "  下载地址: https://nodejs.org/" -ForegroundColor Cyan
    pause
    exit 1
}

# ============== 检查 pnpm ==============
Write-Host "[检查] 检测 pnpm..." -ForegroundColor Yellow
try {
    $pnpmVersion = pnpm -v
    Write-Host "[信息] pnpm 已安装: v$pnpmVersion" -ForegroundColor Green
} catch {
    Write-Host "[提示] pnpm 未安装，正在安装..." -ForegroundColor Yellow
    npm install -g pnpm
    Write-Host "[信息] pnpm 安装完成" -ForegroundColor Green
}

# ============== 检查 Git ==============
Write-Host "[检查] 检测 Git..." -ForegroundColor Yellow
try {
    $gitVersion = git --version
    Write-Host "[信息] $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "[错误] Git 未安装！请先安装 Git" -ForegroundColor Red
    Write-Host "  下载地址: https://git-scm.com/" -ForegroundColor Cyan
    pause
    exit 1
}

# ============== 克隆仓库 ==============
Write-Host ""
Write-Host "[信息] 克隆仓库..." -ForegroundColor Yellow

if (Test-Path $INSTALL_DIR) {
    Write-Host "[提示] 目标目录已存在: $INSTALL_DIR" -ForegroundColor Yellow
    $overwrite = Read-Host "是否覆盖？(y/N)"
    if ($overwrite -eq "y" -or $overwrite -eq "Y") {
        Remove-Item -Recurse -Force $INSTALL_DIR
    } else {
        Write-Host "[信息] 更新已有目录..." -ForegroundColor Green
        Set-Location $INSTALL_DIR
        git pull
        goto install_deps
    }
}

git clone --depth 1 $REPO_URL $INSTALL_DIR
if ($LASTEXITCODE -ne 0) {
    Write-Host "[错误] 克隆仓库失败" -ForegroundColor Red
    pause
    exit 1
}
Write-Host "[信息] 克隆完成" -ForegroundColor Green

# ============== 安装依赖 ==============
Set-Location $INSTALL_DIR
Write-Host ""
Write-Host "[信息] 安装依赖..." -ForegroundColor Yellow

try {
    pnpm install --frozen-lockfile
} catch {
    Write-Host "[警告] pnpm install 失败，尝试无 frozen-lockfile..." -ForegroundColor Yellow
    pnpm install --no-frozen-lockfile
}
Write-Host "[信息] 依赖安装完成" -ForegroundColor Green

# ============== 构建项目 ==============
Write-Host ""
Write-Host "[信息] 构建项目中..." -ForegroundColor Yellow

$buildTasks = @(
    @{Name="内置插件"; Command="pnpm build:plugin-builtin"},
    @{Name="WebUI"; Command="pnpm build:webui"},
    @{Name="Shell 模式"; Command="pnpm build:shell"},
    @{Name="Framework 模式"; Command="pnpm build:framework"}
)

foreach ($task in $buildTasks) {
    Write-Host "  构建 $($task.Name)..." -ForegroundColor Gray
    try {
        Invoke-Expression $task.Command
    } catch {
        Write-Host "  [警告] $($task.Name) 构建失败（可跳过）" -ForegroundColor Yellow
    }
}

# ============== 配置 ==============
Write-Host ""
Write-Host "[信息] 创建默认配置..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "config" | Out-Null
New-Item -ItemType Directory -Force -Path "plugins" | Out-Null

if (-not (Test-Path "config/napcat.json")) {
    "{}" | Set-Content "config/napcat.json" -Encoding utf8
}

if (-not (Test-Path "config/webui.json")) {
    @"
{
    "host": "::",
    "port": 6099,
    "token": "",
    "loginRate": 10,
    "enableKeyAuth": true,
    "hotReloadInterval": 0
}
"@ | Set-Content "config/webui.json" -Encoding utf8
}

# ============== 完成 ==============
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  NapCatQQ-PluginFix 安装完成！" -ForegroundColor Green
Write-Host "  安装目录: $INSTALL_DIR" -ForegroundColor White
Write-Host ""
Write-Host "  启动方式:" -ForegroundColor White
Write-Host "  cd /d `"$INSTALL_DIR`"" -ForegroundColor Cyan
Write-Host "  node index.js" -ForegroundColor Cyan
Write-Host ""
Write-Host "  WebUI 管理页面:" -ForegroundColor White
Write-Host "  http://localhost:6099/webui" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

pause