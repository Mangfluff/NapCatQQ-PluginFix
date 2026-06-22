@echo off
chcp 65001 >nul
title NapCatQQ-PluginFix 改版更新程序

REM ===========================================
REM  NapCatQQ-PluginFix Windows 一键更新脚本
REM  从原版 NapCat 更新到 PluginFix 改版
REM  用法:
REM    1. cd 到原 NapCat 目录运行:
REM       curl -sL https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/update.bat | cmd
REM    2. 或将此脚本放到原 NapCat 目录直接运行
REM ===========================================

setlocal enabledelayedexpansion

set REPO_URL=https://github.com/Mangfluff/NapCatQQ-PluginFix.git
set BUILD_DIR=%TEMP%\NapCatQQ-PluginFix-build
set NODE_MIN_VERSION=18

echo ╔═══════════════════════════════════════════════╗
echo ║   NapCatQQ-PluginFix 改版 Windows 更新程序    ║
echo ╚═══════════════════════════════════════════════╝
echo.
echo  从原版 NapCat 更新到 PluginFix 改版
echo  仓库: %REPO_URL%
echo.

REM ============== 检测安装目录 ==============
echo [检测] 检测 NapCat 安装目录...

if not "%1"=="" (
    set INSTALL_DIR=%1
    if not exist "!INSTALL_DIR!" (
        echo [错误] 指定的目录不存在: !INSTALL_DIR!
        pause
        exit /b 1
    )
    goto :check_deps
)

REM 检测当前目录
set INSTALL_DIR=%CD%
echo [信息] 当前目录: %INSTALL_DIR%

REM 验证当前目录是否包含 NapCat 文件
set FOUND=
if exist "%INSTALL_DIR%\package.json" (
    findstr /i "napcat" "%INSTALL_DIR%\package.json" >nul 2>&1
    if !errorlevel! equ 0 set FOUND=1
)
if exist "%INSTALL_DIR%\napcat.mjs" set FOUND=1
if exist "%INSTALL_DIR%\index.js" (
    findstr /i "napcat" "%INSTALL_DIR%\index.js" >nul 2>&1
    if !errorlevel! equ 0 set FOUND=1
)

if defined FOUND (
    echo [信息] 检测到当前目录包含 NapCat 文件
) else (
    echo [警告] 当前目录未检测到 NapCat 文件
    echo.
    echo  请将此脚本放到原版 NapCat 的安装目录下运行
    echo  或指定安装目录运行: update.bat D:\NapCatQQ
    echo.
    set /p CONTINUE="仍要继续更新到当前目录？(y/N): "
    if /i not "!CONTINUE!"=="y" (
        echo [信息] 已取消
        pause
        exit /b 0
    )
)

:confirm
echo.
echo  即将更新目录: %INSTALL_DIR%
set /p CONFIRM="是否继续？(Y/n): "
if /i "!CONFIRM!"=="n" (
    echo [信息] 已取消
    pause
    exit /b 0
)

:check_deps
echo.
echo [步骤 1/4] 检查依赖环境...

where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Node.js 未安装！请先安装 Node.js v%NODE_MIN_VERSION%+
    echo   下载: https://nodejs.org/
    pause
    exit /b 1
)
for /f "tokens=1 delims=v" %%a in ('node -v') do set NODE_VER=%%a
for /f "tokens=1 delims=." %%a in ("%NODE_VER%") do set NODE_MAJOR=%%a
echo [信息] Node.js v%NODE_VER%
if %NODE_MAJOR% lss %NODE_MIN_VERSION% (
    echo [错误] Node.js 版本过低，需要 v%NODE_MIN_VERSION%+
    pause
    exit /b 1
)

where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] Git 未安装
    pause
    exit /b 1
)
for /f "tokens=*" %%a in ('git --version') do echo [信息] %%a

where pnpm >nul 2>&1
if %errorlevel% neq 0 (
    echo [提示] pnpm 未安装，正在安装...
    call npm install -g pnpm
)
for /f "tokens=*" %%a in ('pnpm -v') do echo [信息] pnpm v%%a

:backup
echo.
echo [步骤 2/4] 备份配置和插件...

set BACKUP_DIR=%INSTALL_DIR%\.backup-%date:~0,4%%date:~5,2%%date:~8,2%%time:~0,2%%time:~3,2%%time:~6,2%
set BACKUP_DIR=!BACKUP_DIR: =0!
mkdir "!BACKUP_DIR!" 2>nul

if exist "%INSTALL_DIR%\config" (
    xcopy /E /I /Y "%INSTALL_DIR%\config" "!BACKUP_DIR!\config" >nul
    echo [信息] 已备份 config/
)
if exist "%INSTALL_DIR%\plugins" (
    xcopy /E /I /Y "%INSTALL_DIR%\plugins" "!BACKUP_DIR!\plugins" >nul
    echo [信息] 已备份 plugins/
)
if exist "%INSTALL_DIR%\.env" (
    copy "%INSTALL_DIR%\.env" "!BACKUP_DIR!\.env" >nul
    echo [信息] 已备份 .env
)
echo [信息] 备份目录: !BACKUP_DIR!

:build
echo.
echo [步骤 3/4] 下载并构建 PluginFix 改版...

if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
echo [信息] 克隆仓库...
git clone --depth 1 "%REPO_URL%" "%BUILD_DIR%"
if %errorlevel% neq 0 (
    echo [错误] 克隆仓库失败
    pause
    exit /b 1
)

cd /d "%BUILD_DIR%"
echo [信息] 安装依赖...
call pnpm install --frozen-lockfile
if %errorlevel% neq 0 (
    call pnpm install --no-frozen-lockfile
)

echo [信息] 构建项目...
call pnpm build:plugin-builtin 2>nul
call pnpm build:webui 2>nul
call pnpm build:shell 2>nul
echo [信息] 构建完成

:update
echo.
echo [步骤 4/4] 更新到 PluginFix 改版...
echo [信息] 更新文件到: %INSTALL_DIR%

cd /d "%BUILD_DIR%"

REM 复制所有文件（排除 config、plugins、.git）
for /d %%i in (*) do (
    if not "%%i"=="config" if not "%%i"=="plugins" if not "%%i"==".git" if not "%%i"=="node_modules" (
        if exist "%INSTALL_DIR%\%%i" (
            if exist "%%i\.git" (echo skip) else (
                echo [信息] 更新目录: %%i
                xcopy /E /I /Y "%%i" "%INSTALL_DIR%\%%i" >nul
            )
        ) else (
            echo [信息] 新建目录: %%i
            xcopy /E /I /Y "%%i" "%INSTALL_DIR%\%%i" >nul
        )
    )
)
for %%f in (*) do (
    if not "%%f"=="update.bat" if not "%%f"=="update.ps1" if not "%%f"=="install.bat" if not "%%f"=="install.ps1" (
        if exist "%INSTALL_DIR%\%%f" (
            echo [信息] 更新文件: %%f
        ) else (
            echo [信息] 新建文件: %%f
        )
        copy /Y "%%f" "%INSTALL_DIR%\%%f" >nul
    )
)

REM 合并 webui.json 新配置字段
if exist "%INSTALL_DIR%\config\webui.json" (
    echo [信息] 合并 webui.json 配置...
    powershell -Command ^
        "$p='%INSTALL_DIR%\config\webui.json';" ^
        "$d=Get-Content $p -Raw | ConvertFrom-Json;" ^
        "$changed=$false;" ^
        "if (-not ($d.PSObject.Properties.Name -contains 'enableKeyAuth')) { $d ^| Add-Member -NotePropertyName 'enableKeyAuth' -NotePropertyValue $true; $changed=$true };" ^
        "if (-not ($d.PSObject.Properties.Name -contains 'hotReloadInterval')) { $d ^| Add-Member -NotePropertyName 'hotReloadInterval' -NotePropertyValue 0; $changed=$true };" ^
        "if ($changed) { $d ^| ConvertTo-Json -Depth 10 ^| Set-Content $p -Encoding utf8; Write-Host '[信息] 已添加新配置字段' } else { Write-Host '[信息] 配置已包含所有字段' }"
)

echo.
echo ╔═══════════════════════════════════════════════╗
echo ║    NapCatQQ-PluginFix 改版 更新完成！         ║
echo ╚═══════════════════════════════════════════════╝
echo.
echo  安装目录: %INSTALL_DIR%
echo  备份目录: !BACKUP_DIR!
echo.
echo  现在可以重启 NapCat 使用了！
echo.
echo  Shell 模式启动:
echo    cd /d "%INSTALL_DIR%"
echo    node index.js
echo.
echo  WebUI 管理页面:
echo    http://localhost:6099/webui
echo.
echo  PluginFix 改版特性:
echo    ✓ 纯第三方插件支持（移除白名单）
echo    ✓ WebUI 插件上传功能
echo    ✓ 插件定时热重载 (Hot Reload)
echo    ✓ WebUI 鉴权可关闭
echo.

pause