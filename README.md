<div align="center">

# NapCatQQ-PluginFix

**基于 NTQQ 的 Bot 协议端 — 改版增强版**

> 在原有 NapCat 基础上修复纯第三方插件支持，添加热重载等实用功能

[![GitHub release](https://img.shields.io/github/v/release/Mangfluff/NapCatQQ-PluginFix)](https://github.com/Mangfluff/NapCatQQ-PluginFix/releases)
[![GitHub stars](https://img.shields.io/github/stars/Mangfluff/NapCatQQ-PluginFix)](https://github.com/Mangfluff/NapCatQQ-PluginFix/stargazers)
[![License](https://img.shields.io/github/license/Mangfluff/NapCatQQ-PluginFix)](./LICENSE)

</div>

---

## ⚠️ 本仓库说明

本仓库是基于 NapCat 的 **改版 (PluginFix)**，主要修复了原版新版本中移除纯第三方插件支持、禁用 WebUI 插件上传的问题，并额外添加了实用功能增强。

**改版与原版的差异：**

| 特性 | 原版新版本 | PluginFix 改版 |
|------|-----------|---------------|
| 第三方纯插件加载 | ❌ 仅限官方白名单 | ✅ 完全支持 |
| WebUI 插件上传 | ❌ 被禁用 | ✅ 已恢复 |
| 插件热重载 | ❌ 不支持 | ✅ 定时热重载（可配置） |
| WebUI 鉴权开关 | ❌ 一直需要 Token | ✅ 可关闭（局域网友好） |
| 更新源 | 官方仓库 | 本仓库 |

---

## ✨ 改版特性详解

### 🧩 纯插件支持（核心修复）

移除官方的 **OFFICIAL_PLUGIN_IDS 白名单限制**，所有通过安全检测的第三方纯插件均可正常加载，恢复旧版 NapCat 的插件生态。

### 📤 WebUI 插件上传

恢复 WebUI 中插件导入上传功能，支持通过管理界面上传 `.zip` 格式的插件包，自动解压安装并加载。

### 🔄 插件定时热重载

新增插件定时热重载功能，可在 WebUI 配置（或直接修改 `config/webui.json`）中设置自动重载间隔，开发插件时无需手动重启。

```
config/webui.json 配置:
"hotReloadInterval": 60   // 每 60 秒自动重载一次，0 为禁用
```

### 🔓 WebUI 鉴权可关闭

新增 `enableKeyAuth` 配置项，设为 `false` 后可免 Token 登录 WebUI，适合局域网内部使用。

```
config/webui.json 配置:
"enableKeyAuth": false    // true=需要Token登录，false=免登录
```

---

## 🚀 快速安装

### Linux / macOS

```bash
# 一键安装
bash <(curl -sL https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/install.sh)

# 或指定安装目录
INSTALL_DIR=/opt/napcat bash <(curl -sL https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/install.sh)
```

### Windows

```powershell
# PowerShell 安装
powershell -c "irm https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/install.ps1 | iex"
```

或直接下载 `install.bat` 双击运行。

---

## 🔄 从原版 NapCat 更新

无需重新安装！直接在原有 NapCat 目录运行更新脚本，会自动备份配置并替换文件。

### Linux / macOS

```bash
# 方法1：在 NapCat 目录直接执行
cd /path/to/your/napcat
bash <(curl -sL https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/update.sh)

# 方法2：指定 NapCat 安装目录
bash <(curl -sL https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/update.sh) /path/to/napcat
```

### Windows

```powershell
# 方法1：打开 PowerShell，cd 到 NapCat 目录后执行
cd D:\NapCatQQ
powershell -c "irm https://github.com/Mangfluff/NapCatQQ-PluginFix/raw/main/update.ps1 | iex"

# 方法2：下载 update.bat 放到 NapCat 目录双击运行
```

### 更新脚本会做什么？

1. **检测** — 自动识别原版 NapCat 安装目录
2. **备份** — 自动备份 `config/`、`plugins/`、`.env` 到 `.backup-时间戳/`
3. **下载** — 克隆 PluginFix 改版仓库
4. **构建** — 自动安装依赖并构建
5. **更新** — 替换文件，保留配置和插件
6. **完成** — 重启即可使用

> 所有配置和插件数据都会被保留，如需回退只需还原备份目录即可。

---

## 📋 系统要求

| 依赖 | 最低版本 |
|------|---------|
| Node.js | v18+ |
| pnpm | 最新（自动安装） |
| Git | 任意版本 |

---

## 🔧 手动构建

```bash
git clone https://github.com/Mangfluff/NapCatQQ-PluginFix.git
cd NapCatQQ-PluginFix
pnpm install
pnpm build:shell     # 构建 Shell 模式
pnpm build:webui     # 构建 WebUI 前端
pnpm build:plugin-builtin  # 构建内置插件
```

---

## 📖 使用方法

### Shell 模式启动

```bash
cd NapCatQQ-PluginFix
node index.js
```

### WebUI 管理

启动后浏览器打开：`http://localhost:6099/webui`

首次启动会自动生成随机 Token，可在 `config/webui.json` 中查看或修改。

### 配置说明

配置文件位于 `config/webui.json`：

```json
{
    "host": "::",
    "port": 6099,
    "token": "your_token",
    "loginRate": 10,
    "enable2FA": false,
    "enableKeyAuth": true,
    "hotReloadInterval": 0
}
```

---

## 🤝 致谢

- [Lagrange](https://github.com/LagrangeDev/Lagrange.Core) — 参考部分代码，已获授权
- [AstrBot](https://github.com/AstrBotDevs/AstrBot) — 完美适配的 LLM Bot 框架
- [MaiBot](https://github.com/MaiM-with-u/MaiBot) — 麦麦 Bot 框架
- 原始 NapCat 项目团队 — 优秀的 Bot 协议端实现

---

## 📄 许可证

本项目采用混合协议开源。第三方库代码或修改部分遵循其原始开源许可。项目其余逻辑代码采用本仓库开源许可。

**本仓库仅用于提高易用性，实现消息推送类功能。使用请遵守当地法律法规，由此造成的问题由使用者负责。**