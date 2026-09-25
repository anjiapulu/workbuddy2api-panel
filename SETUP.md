# workbuddy2api-panel 部署说明（Windows）

`v1.11.6` · 网关 `http://127.0.0.1:7863`

本文件记录在 **Windows 上不使用 Docker / Go** 的部署方式，以及配套的免管理员
无窗口启动脚本。作者原 README 见 [README.md](./README.md)。

> ⚠️ 两个脚本里写死了部署目录，换机器要改：
> - `startup-shim.vbs` 顶部的 `PANEL_DIR`
> - 改完后重新执行 `wb2api.cmd` 的菜单 `4` 重新安装启动项

---

## 怎么用

**只需要双击一个文件：`wb2api.cmd`**

```
   workbuddy2api-panel     http://127.0.0.1:7863/panel/
   -------------------------------------------------------

    1  Start  (no window)
    2  Stop
    3  Status

    4  Enable autostart at logon   (no admin needed)
    5  Disable autostart

    6  Allow LAN access            (needs admin)
    0  Exit

   Log: data\wb2api.log
```

日常就三步：

1. **`1`** 启动（无窗口）
2. **`4`** 装开机自启 —— 装完以后每次登录 Windows 自动起来，不用再管
3. 之后要用面板才去开 `http://127.0.0.1:7863/panel/`

**`6` 只在需要手机/其他电脑访问时才点**（要右键以管理员身份运行）。

---

## 客户端接入

| 配置项 | 值 |
|---|---|
| Base URL | `http://127.0.0.1:7863/v1`（局域网换成 `http://<本机局域网IP>:7863/v1`） |
| API Key | `config.json` 里的 `api_key`，或按 `3` 直接看 |
| 模型 | `deepseek-v4.1-flash`（或其他可用模型） |

---

## 文件说明

**你需要的（1 个）**

| 文件 | 作用 |
|---|---|
| `wb2api.cmd` | 全部操作的入口 |

**内部用的（2 个，别手动双击）**

| 文件 | 作用 |
|---|---|
| `startup-shim.vbs` | 无窗口拉起网关；同时被复制到「启动」文件夹做登录自启 |
| `run-wb2api.cmd` | 真正启动 exe 的那一层（切目录 + 日志重定向） |

**数据 / 配置**

| 路径 | 说明 |
|---|---|
| `config.json` | 配置，含 `api_key`。首次启动自动生成 |
| `auths/` | 账号凭证（明文含 token，**勿外传**） |
| `data/` | 账号池状态 + 日志 `wb2api.log` |

`auths/`、`data/`、`config.json` 都已在 `.gitignore` 里。

---

## 为什么是这个版本

上一个方案 `codebuddy2api`（Python）被 WorkBuddy 桌面端 **2026-09-25 的自动更新**打挂了：
桌面端把 auth 文件里的 `accessToken`/`refreshToken` 改成了加密信封
（`{"$wbEncrypted":1,"envelope":"..."}`），而那个转换器只按明文读，
发给上游的变成 `Authorization: Bearer {dict}` → 全程 401。

本项目**不读桌面端 auth 文件**，走官方 OAuth 自取 token 存在自己的 `auths/`，
桌面端怎么改格式都不影响。

迁移对照：

| | codebuddy2api（旧） | workbuddy2api-panel（新） |
|---|---|---|
| 凭据来源 | 读桌面端 auth 文件 | OAuth 自取，独立存 |
| 抗桌面端更新 | ❌ 已被打挂 | ✅ 不受影响 |
| 端口 | 8787 | **7863** |
| 多账号 | 单账号 | 账号池 + 轮转 + 熔断 |
| 管理界面 | 无 | Web 面板 |
| 自动化 | 无 | 自动签到 / 旅行 / 活跃 / 保活 |
| 依赖 | Python venv + 3 包 | 无（单个 exe） |

旧目录 `D:\CodeData\codebuddy2api` 已不再需要，可以删。

---

## 配置要点

默认值够用，想调就改 `config.json` 或面板「配置」页（大部分热生效）。

| 字段 | 当前 | 说明 |
|---|---|---|
| `listen` | `:7863` | 绑所有网卡。**不是仅本机**，靠 `api_key` 兜底 |
| `api_key` | 随机 | 非空即强制鉴权，**别清空** |
| `prompt.mode` | `passthrough` | 透传客户端 system。遇到内容策略误拦（400 + `blocked by security policy`）就改成 `custom` |
| `schedule.*` | 全开 | 签到 9/21、旅行 9/21、活跃 10、保活 22、夜猫子 23 |

---

## 排查

| 现象 | 处理 |
|---|---|
| 面板打不开 | 按 `3` 看状态；没跑就按 `1` |
| 客户端 401 | API Key 不对，按 `3` 查；或账号池空了去面板加账号 |
| 局域网连不上 | 按 `6` 放行防火墙（要管理员） |
| 想加账号 / 换账号 | 面板 → 右上角「添加账号」→ OAuth 登录，热加载免重启 |
| 想看详细日志 | `data\wb2api.log` |

---

## 实现上的坑（记录备查）

1. **`schtasks /SC ONLOGON` 需要管理员**，非管理员报 `Access is denied`。
   所以自动启动走「启动文件夹」路线（菜单 `4`），不需要任何提权。
2. **不能注册成 Windows 服务**：源码没引 service 库，不实现服务控制协议，
   `sc create` 会报**错误 1053**。
3. **`wscript` 隐式启动的子进程会死**（日志里有 `listening` 但进程随后消失，
   事件日志无崩溃记录 = 被终止而非崩溃）。所以常驻场景都改由系统拉起
   （登录流程 / 任务计划），`startup-shim.vbs` 只负责「把 exe 以无窗口方式交给系统」。
4. **VBS 里读 netstat 千万别用重定向 + 临时文件**，那串嵌套引号写不对就恒返回假值，
   会误报「not listening」。统一用 `sh.Exec(...).StdOut.ReadAll()`。
5. **停止网关绝不用 `taskkill /IM wb2api.exe /F`** —— 现场可能有多个实例，
   `/IM` 会全杀。改成从 `netstat` 取端口持有者 PID 再 `/PID` 精确杀。
   （我曾用 `/IM` 误杀过正在服务的实例，教训。）
6. 计划任务 `/TR` 的值里**不能出现 `wscript.exe` 字样**，会被当 LOLBin 拦下。
