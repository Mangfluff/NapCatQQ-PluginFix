# NapCatQQ-PluginFix Windows PowerShell 更新脚本
# 从原版 NapCat 更新到 PluginFix 改版
#
# 用法:
#   cd 到原版 NapCat 安装目录，然后执行:
#   powershell -c "irm https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/update.ps1 | iex"
#
#   或指定目录:
#   .\update.ps1 -InstallDir "D:\NapCat"
#
# 参数:
#   -InstallDir    <string>   NapCat 安装目录（可选，默认自动检测）
#   -SkipBackup    <switch>   跳过备份
#   -SkipConfirm   <switch>   跳过确认提示

param(
    [string]$InstallDir = "",
    [switch]$SkipBackup = $false,
    [switch]$SkipConfirm = $false
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$REPO_OWNER = "Mangfluff"
$REPO_NAME = "NapCatQQ-PluginFix"
$REPO_URL = "https://github.com/$REPO_OWNER/$REPO_NAME.git"
$BUILD_DIR = [IO.Path]::Combine($env:TEMP, "NapCatQQ-PluginFix-build")
$NODE_MIN_VERSION = 18

Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║   NapCatQQ-PluginFix 改版 PowerShell 更新程序 ║" -ForegroundColor Blue
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""
Write-Host "  从原版 NapCat 更新到 PluginFix 改版" -ForegroundColor Cyan
Write-Host "  仓库: $REPO_URL" -ForegroundColor Gray
Write-Host ""

# ============== 检测安装目录 ==============
function Find-NapCatInstall {
    $candidates = @()

    # 当前目录
    if (Test-Path "package.json") {
        $content = Get-Content "package.json" -Raw -ErrorAction SilentlyContinue
        if ($content -match "napcat") { $candidates += (Get-Location).Path }
    }

    # 常见路径
    $commonPaths = @(
        "$env:USERPROFILE\NapCatQQ",
        "$env:USERPROFILE\NapCat",
        "$env:USERPROFILE\napcat",
        "$env:USERPROFILE\napcatqq",
        "$env:USERPROFILE\NapCatQQ-PluginFix",
        "$env:LOCALAPPDATA\NapCat"
    )
    foreach ($p in $commonPaths) {
        if (Test-Path "$p\package.json") {
            $content = Get-Content "$p\package.json" -Raw -ErrorAction SilentlyContinue
            if ($content -match "napcat") { $candidates += $p }
        }
    }

    # 去重
    $candidates = $candidates | Select-Object -Unique

    if ($candidates.Count -eq 0) { return $null }
    if ($candidates.Count -eq 1) { return $candidates[0] }

    Write-Host "检测到多个 NapCat 安装目录:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        Write-Host "  [$($i+1)] $($candidates[$i])"
    }
    $selection = Read-Host "请选择 (1-$($candidates.Count))"
    return $candidates[[int]$selection - 1]
}

if (-not $InstallDir) {
    Write-Host "[检测] 检测 NapCat 安装目录..." -ForegroundColor Yellow
    $detected = Find-NapCatInstall
    if ($detected) {
        $InstallDir = $detected
        Write-Host "[信息] 检测到: $InstallDir" -ForegroundColor Green
    } else {
        $InstallDir = (Get-Location).Path
        Write-Host "[警告] 未检测到 NapCat 安装目录，将更新到当前目录: $InstallDir" -ForegroundColor Yellow
    }
}

if (-not (Test-Path $InstallDir)) {
    Write-Host "[错误] 目录不存在: $InstallDir" -ForegroundColor Red
    pause
    exit 1
}

# ============== 确认 ==============
if (-not $SkipConfirm) {
    Write-Host ""
    Write-Host "即将更新目录: $InstallDir" -ForegroundColor White
    $confirm = Read-Host "是否继续？(Y/n)"
    if ($confirm -eq "n" -or $confirm -eq "N") {
        Write-Host "[信息] 已取消" -ForegroundColor Yellow
        exit 0
    }
}

# ============== 检查依赖 ==============
Write-Host ""
Write-Host "[步骤 1/4] 检查依赖环境..." -ForegroundColor Yellow

try {
    $nodeVer = node -v
    $nodeMajor = [int]($nodeVer -replace 'v', '' -replace '\..*', '')
    Write-Host "[信息] Node.js $nodeVer ✓" -ForegroundColor Green
    if ($nodeMajor -lt $NODE_MIN_VERSION) {
        Write-Host "[错误] Node.js 版本过低，需要 v$NODE_MIN_VERSION+" -ForegroundColor Red
        pause; exit 1
    }
} catch {
    Write-Host "[错误] Node.js 未安装！" -ForegroundColor Red
    pause; exit 1
}

try {
    $gitVer = git --version
    Write-Host "[信息] Git $gitVer ✓" -ForegroundColor Green
} catch {
    Write-Host "[错误] Git 未安装！" -ForegroundColor Red
    pause; exit 1
}

try {
    $pnpmVer = pnpm -v
    Write-Host "[信息] pnpm v$pnpmVer ✓" -ForegroundColor Green
} catch {
    Write-Host "[提示] pnpm 未安装，正在安装..." -ForegroundColor Yellow
    npm install -g pnpm
}

# ============== 备份 ==============
if (-not $SkipBackup) {
    Write-Host ""
    Write-Host "[步骤 2/4] 备份配置和插件..." -ForegroundColor Yellow

    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $backupDir = Join-Path $InstallDir ".backup-$timestamp"
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

    $configDir = Join-Path $InstallDir "config"
    $pluginsDir = Join-Path $InstallDir "plugins"
    $envFile = Join-Path $InstallDir ".env"

    if (Test-Path $configDir) {
        Copy-Item -Recurse -Path $configDir -Destination (Join-Path $backupDir "config")
        Write-Host "[信息] 已备份 config/" -ForegroundColor Green
    }
    if (Test-Path $pluginsDir) {
        Copy-Item -Recurse -Path $pluginsDir -Destination (Join-Path $backupDir "plugins")
        Write-Host "[信息] 已备份 plugins/" -ForegroundColor Green
    }
    if (Test-Path $envFile) {
        Copy-Item -Path $envFile -Destination (Join-Path $backupDir ".env")
        Write-Host "[信息] 已备份 .env" -ForegroundColor Green
    }
    Write-Host "[信息] 备份目录: $backupDir" -ForegroundColor Gray
}

# ============== 构建 ==============
Write-Host ""
Write-Host "[步骤 3/4] 下载并构建 PluginFix 改版..." -ForegroundColor Yellow

if (Test-Path $BUILD_DIR) { Remove-Item -Recurse -Force $BUILD_DIR }

Write-Host "[信息] 克隆仓库..." -ForegroundColor Gray
git clone --depth 1 $REPO_URL $BUILD_DIR
if ($LASTEXITCODE -ne 0) {
    Write-Host "[错误] 克隆仓库失败" -ForegroundColor Red
    pause; exit 1
}

Set-Location $BUILD_DIR
Write-Host "[信息] 安装依赖..." -ForegroundColor Gray
try { pnpm install --frozen-lockfile } catch { pnpm install --no-frozen-lockfile }

Write-Host "[信息] 构建项目..." -ForegroundColor Gray
try { pnpm build:plugin-builtin } catch {}
try { pnpm build:webui } catch {}
try { pnpm build:shell } catch {}
Write-Host "[信息] 构建完成" -ForegroundColor Green

# ============== 更新 ==============
Write-Host ""
Write-Host "[步骤 4/4] 更新到 PluginFix 改版..." -ForegroundColor Yellow
Write-Host "[信息] 更新文件到: $InstallDir" -ForegroundColor Gray

$excludeDirs = @("config", "plugins", ".git", "node_modules", ".backup-*")
$excludeFiles = @("update.bat", "update.ps1", "install.bat", "install.ps1")

# 复制文件
Get-ChildItem -Path $BUILD_DIR -Exclude $excludeDirs | ForEach-Object {
    $target = Join-Path $InstallDir $_.Name
    if ($_.PSIsContainer) {
        Copy-Item -Recurse -Force -Path $_.FullName -Destination $target -ErrorAction SilentlyContinue
        Write-Host "  [更新] 目录: $($_.Name)" -ForegroundColor Gray
    } else {
        if ($_.Name -notin $excludeFiles) {
            Copy-Item -Force -Path $_.FullName -Destination $target -ErrorAction SilentlyContinue
        }
    }
}

# 复制子目录（排除列表）
$excludeDirNames = @("config", "plugins", ".git", "node_modules")
$excludeDirPatterns = @(".backup-*")
Get-ChildItem -Path $BUILD_DIR -Directory | Where-Object {
    $_.Name -notin $excludeDirNames -and (
        -not ($excludeDirPatterns | Where-Object { $_.Name -like $_ })
    )
} | ForEach-Object {
    $target = Join-Path $InstallDir $_.Name
    Copy-Item -Recurse -Force -Path $_.FullName -Destination $target -ErrorAction SilentlyContinue
}

# 合并 webui.json
$webuiConfigPath = Join-Path $InstallDir "config" "webui.json"
if (Test-Path $webuiConfigPath) {
    Write-Host "[信息] 合并 webui.json 配置..." -ForegroundColor Gray
    try {
        $config = Get-Content $webuiConfigPath -Raw | ConvertFrom-Json
        $changed = $false

        if (-not ($config.PSObject.Properties.Name -contains "enableKeyAuth")) {
            $config | Add-Member -NotePropertyName "enableKeyAuth" -NotePropertyValue $true
            $changed = $true
        }
        if (-not ($config.PSObject.Properties.Name -contains "hotReloadInterval")) {
            $config | Add-Member -NotePropertyName "hotReloadInterval" -NotePropertyValue 0
            $changed = $true
        }
        if ($changed) {
            $config | ConvertTo-Json -Depth 10 | Set-Content $webuiConfigPath -Encoding utf8
            Write-Host "[信息] 已添加新配置字段" -ForegroundColor Green
        } else {
            Write-Host "[信息] 配置已包含所有字段" -ForegroundColor Green
        }
    } catch {
        Write-Host "[警告] webui.json 合并失败: $_" -ForegroundColor Yellow
    }
}

# ============== 完成 ==============
Write-Host ""
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║    NapCatQQ-PluginFix 改版 更新完成！          ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "安装目录: $InstallDir" -ForegroundColor White

if (-not $SkipBackup) {
    Write-Host "配置已备份到: $backupDir" -ForegroundColor Gray
}

Write-Host ""
Write-Host "现在可以重启 NapCat 使用了！" -ForegroundColor Cyan
Write-Host ""
Write-Host "Shell 模式启动:" -ForegroundColor Yellow
Write-Host "  cd /d `"$InstallDir`"" -ForegroundColor Gray
Write-Host "  node index.js" -ForegroundColor Gray
Write-Host ""
Write-Host "WebUI 管理页面:" -ForegroundColor Yellow
Write-Host "  http://localhost:6099/webui" -ForegroundColor Gray
Write-Host ""
Write-Host "PluginFix 改版特性:" -ForegroundColor Cyan
Write-Host "  ✓ 纯第三方插件支持（移除白名单）" -ForegroundColor Gray
Write-Host "  ✓ WebUI 插件上传功能" -ForegroundColor Gray
Write-Host "  ✓ 插件定时热重载 (Hot Reload)" -ForegroundColor Gray
Write-Host "  ✓ WebUI 鉴权可关闭" -ForegroundColor Gray
Write-Host ""

pause