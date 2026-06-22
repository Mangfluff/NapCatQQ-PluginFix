@echo off
chcp 65001 >nul
title NapCatQQ-PluginFix Windows 安装程序

REM ============== 配置 ==============
set REPO_URL=https://github.com/Mangfluff/NapCatQQ-PluginFix.git
set INSTALL_DIR=%USERPROFILE%\NapCatQQ-PluginFix
set NODE_MIN_VERSION=18

echo ========================================
echo   NapCatQQ-PluginFix Windows 安装程序
echo ========================================
echo.
echo  仓库: %REPO_URL%
echo  安装到: %INSTALL_DIR%
echo.

REM ============== 检查 Node.js ==============
echo [检查] 检测 Node.js...
where node >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [错误] Node.js 未安装！请先安装 Node.js v%NODE_MIN_VERSION%+
    echo   下载地址: https://nodejs.org/
    pause
    exit /b 1
)

for /f "tokens=1 delims=v" %%a in ('node -v') do set NODE_VER=%%a
for /f "tokens=1 delims=." %%a in ("%NODE_VER%") do set NODE_MAJOR=%%a
echo [信息] Node.js 已安装: v%NODE_VER%

if %NODE_MAJOR% LSS %NODE_MIN_VERSION% (
    echo [错误] Node.js 版本过低，需要 v%NODE_MIN_VERSION%+，当前 v%NODE_VER%
    pause
    exit /b 1
)

REM ============== 检查 pnpm ==============
echo [检查] 检测 pnpm...
where pnpm >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [提示] pnpm 未安装，正在安装...
    call npm install -g pnpm
    if %ERRORLEVEL% neq 0 (
        echo [错误] pnpm 安装失败
        pause
        exit /b 1
    )
    echo [信息] pnpm 安装完成
)

for /f "tokens=*" %%a in ('pnpm -v') do echo [信息] pnpm 已安装: v%%a

REM ============== 检查 Git ==============
echo [检查] 检测 Git...
where git >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [错误] Git 未安装！请先安装 Git
    echo   下载地址: https://git-scm.com/
    pause
    exit /b 1
)
for /f "tokens=*" %%a in ('git --version') do echo [信息] %%a

REM ============== 克隆仓库 ==============
echo.
echo [信息] 克隆仓库...

if exist "%INSTALL_DIR%" (
    echo [提示] 目标目录已存在: %INSTALL_DIR%
    set /p OVERWRITE="是否覆盖？(y/N): "
    if /i "!OVERWRITE!"=="y" (
        rmdir /s /q "%INSTALL_DIR%"
    ) else (
        echo [信息] 更新已有目录...
        cd /d "%INSTALL_DIR%"
        git pull
        goto :install_deps
    )
)

git clone --depth 1 "%REPO_URL%" "%INSTALL_DIR%"
if %ERRORLEVEL% neq 0 (
    echo [错误] 克隆仓库失败
    pause
    exit /b 1
)
echo [信息] 克隆完成

:install_deps
cd /d "%INSTALL_DIR%"

REM ============== 安装依赖 ==============
echo.
echo [信息] 安装依赖...
call pnpm install
if %ERRORLEVEL% neq 0 (
    echo [警告] pnpm install 失败，尝试无 frozen-lockfile...
    call pnpm install --no-frozen-lockfile
)
echo [信息] 依赖安装完成

REM ============== 构建项目 ==============
echo.
echo [信息] 构建内置插件...
call pnpm build:plugin-builtin 2>nul
if %ERRORLEVEL% neq 0 echo [警告] 内置插件构建失败（可跳过）

echo [信息] 构建 WebUI...
call pnpm build:webui 2>nul
if %ERRORLEVEL% neq 0 echo [警告] WebUI 构建失败（可跳过）

echo [信息] 构建 Shell 模式...
call pnpm build:shell 2>nul
if %ERRORLEVEL% neq 0 echo [警告] Shell 构建失败

echo [信息] 构建 Framework 模式...
call pnpm build:framework 2>nul
if %ERRORLEVEL% neq 0 echo [警告] Framework 构建失败

REM ============== 配置 ==============
echo.
echo [信息] 创建默认配置...
if not exist config mkdir config
if not exist config\napcat.json echo {} > config\napcat.json
if not exist config\webui.json (
    echo {> config\webui.json
    echo     "host": "::",>> config\webui.json
    echo     "port": 6099,>> config\webui.json
    echo     "token": "",>> config\webui.json
    echo     "loginRate": 10,>> config\webui.json
    echo     "enableKeyAuth": true,>> config\webui.json
    echo     "hotReloadInterval": 0>> config\webui.json
    echo }>> config\webui.json
)

if not exist plugins mkdir plugins

REM ============== 完成 ==============
echo.
echo ========================================
echo   NapCatQQ-PluginFix 安装完成！
echo   安装目录: %INSTALL_DIR%
echo.
echo   启动方式:
echo   cd /d "%INSTALL_DIR%"
echo   node index.js
echo.
echo   WebUI 管理页面:
echo   http://localhost:6099/webui
echo ========================================
echo.

pause