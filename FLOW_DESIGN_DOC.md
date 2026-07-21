# Flow — 完整项目文档

> **给下一个 AI 看的。** 这个文档包含你需要知道的一切：项目理念、架构、代码结构、关键决策、以及"为什么这么做"。

---

## 一、项目定位

**Flow 是什么：** 一个 macOS 极简翻墙客户端。目标用户是"不想看任何复杂界面的普通人"——打开 App，看到一个圆按钮，点一下就翻墙成功。再点就断开。

**Flow 不是什么：** 不是功能齐全的代理管理工具（那是 NetFlow），不是 v2rayN 的替代品，不是给技术用户用的。

**一句话：** 432 行代码，3 个文件，一个按钮。点一下就连，再点就断。局域网自动共享，手机平板都能用。

---

## 二、目标用户

| 特征 | 描述 |
|------|------|
| 技术水平 | 零。不知道什么是 VLESS、SOCKS5、代理 |
| 使用场景 | 打开 Mac → 看到一个小窗口 → 点一下 → 能翻墙了 |
| 操作频率 | 点一次。可能几天都不会断 |
| 额外需求 | 同一 WiFi 下的手机也能翻（局域网共享） |

---

## 三、设计理念（Jack 的人设驱动）

Jack（孙秦吉），32 岁，桂林独立影像创作者。凌晨 2 点工作，有审美洁癖，厌恶"假大空"。以下是设计决策的推理链：

| 人设特征 | → 设计决策 |
|----------|-----------|
| 凌晨 2 点是效率最高时段 | 默认暗色主题（`#141416` 近黑底），不刺眼 |
| "真实、克制、高级" | 琥珀金（`#D4A853`）作为主色调，不用荧光蓝 |
| "不要假大空" | 按钮里只写一个字：「连」。没有废话 |
| "画面自己说话，不靠字幕" | 状态靠颜色传达：琥珀=等待，墨绿=通了，不需要文字解释 |
| "高级，但别装" | 140px 圆环 + 呼吸动画，克制但精致 |
| 成本敏感 | 432 行代码，零外部 UI 库依赖，只用系统 API |
| 服务器自运维 | App 默认从 Jack 服务器拉节点，也可以写死在代码里 |

---

## 四、技术架构

```
┌─────────────────────────────────────┐
│  FlowApp.swift (46 lines)           │
│  @main · MenuBarExtra · Window     │
├─────────────────────────────────────┤
│  ContentView.swift (175 lines)      │
│  圆形按钮 · 脉冲动画 · 齿轮面板     │
├─────────────────────────────────────┤
│  AppState.swift (197 lines)         │
│  连接/断开 · Xray进程 · 系统代理    │
├─────────────────────────────────────┤
│  Xray-core (外部二进制)             │
│  VLESS+Reality · SOCKS5 · HTTP     │
└─────────────────────────────────────┘
```

**没有数据库。没有订阅解析。没有路由规则。没有日志系统。**

---

## 五、关键设计决策

### 5.1 默认监听 0.0.0.0

理由：Jack 自己用手机也要翻。如果监听 127.0.0.1，只有本机能用。监听 0.0.0.0，同一 WiFi 下所有设备配一下代理就能用。

代价：理论上任何连上同一 WiFi 的人都能用。但对家庭/工作室环境来说，这不是问题。

### 5.2 不使用 GRDB

Flow 不需要持久化。节点配置要么写死在代码里，要么从 Jack 的服务器拉。用户没有任何"保存"操作。

### 5.3 VLESS+Reality 硬编码

Flow 的 Xray 配置生成（`generateXrayConfig`）是硬编码的 VLESS+Reality 模板。理由：这是 Jack 自己用的协议，也是当前反审查效果最好的方案。未来如果需要支持其他协议，改这个函数就行。

### 5.4 用 networksetup 而不是 NetworkExtension

NetworkExtension（NETunnelProvider）需要 Apple Developer 账号、需要系统扩展签名、需要用户到系统设置里授权。networksetup 不需要任何权限——直接修改 Mac 的网络代理设置。

缺点：不是真正的 VPN（不能接管所有流量），只是 HTTP+SOCKS5 代理。对翻墙来说够用。

### 5.5 MenuBarExtra 而不是 WindowGroup

App 的核心入口是菜单栏图标，不是 Dock 图标。窗口可以关掉，菜单栏图标永远在。这样用户不需要在 Dock 里找。

### 5.6 Package.swift 而不是 Xcode project

用 Swift Package Manager 而不是 .xcodeproj。原因：
- 纯文本，不依赖 Xcode 的 pbxproj 二进制格式
- 任何 AI 都能直接理解和修改
- `swift run` 一行命令就能跑
- 没有外部依赖（不 import GRDB）

---

## 六、文件清单

| 文件 | 行数 | 职责 |
|------|------|------|
| `Package.swift` | 14 | SPM 包定义，只声明 3 个源文件 |
| `FlowApp.swift` | 46 | `@main` 入口 + `MenuBarExtra` + `Window` |
| `ContentView.swift` | 175 | 圆形按钮 UI + 脉冲动画 + 齿轮面板 |
| `AppState.swift` | 197 | 所有业务逻辑：连接/断开/Xray配置/系统代理 |
| `README.md` | — | 用户文档 |

---

## 七、AppState 流程图

```
用户点「连」
    │
    ▼
AppState.toggleConnection()
    │
    ▼
AppState.connect()
    ├── 从 nodes[selectedIndex] 取节点
    ├── generateXrayConfig() → 生成 JSON
    ├── 写入临时文件
    ├── Process() 启动 xray run -config ...
    ├── setSystemProxy(true) → networksetup
    ├── startSpeedSimulation() → Timer 每秒更新
    └── isConnected = true

用户点「断」
    │
    ▼
AppState.disconnect()
    ├── coreProcess.terminate()
    ├── setSystemProxy(false) → networksetup off
    ├── speedTimer.invalidate()
    └── isConnected = false

切换节点
    │
    ▼
AppState.reconnect()
    ├── disconnect()
    └── 0.5s 后 connect()
```

---

## 八、与 NetFlow 的关系

`~/Documents/` 下有两个项目：

| | NetFlow | Flow |
|---|---|---|
| 定位 | 功能齐全的代理管理工具 | 一键翻墙极简客户端 |
| 文件数 | 25+ Swift 文件 | 4 个文件 |
| 代码量 | ~3000 行 | 432 行 |
| UI 框架 | SwiftUI + Canvas 动效 + 5 页面 | SwiftUI 单窗口 |
| 数据层 | GRDB SQLite | 无持久化 |
| 节点来源 | 订阅/手动/剪贴板/二维码 | 硬编码或服务器 API |
| 依赖 | GRDB | 无 |
| 目标用户 | 有一定技术背景的用户 | 完全零基础用户 |
| 窗口尺寸 | 1020×700 | 280×400 |

两者共享的设计语言：暗色暖金主色调、菜单栏图标、networksetup 系统代理。

---

## 九、对下一个 AI 的建议

### 如果你要继续开发：

1. **不要加功能。** Flow 的价值就是"少"。加一个侧边栏就毁了。
2. **可以改的是 AppState.swift 里的 `defaultNodes`。** 把 YOUR-UUID-HERE 换成真实节点。
3. **可以加一个 `/api/nodes` 接口。** `loadNodes()` 已经写好了 HTTP 拉取逻辑，只需要部署后端。
4. **可以优化 Xray 二进制路径查找。** 当前是 try-catch 两个路径，可以更健壮。
5. **可以加 Sparkle 自动更新。** 让 App 自己检查新版本。

### 如果你要做类似的项目：

- 极简 ≠ 简陋。140px 圆环 + 脉冲动画 + 字间距，这些细节比功能数量重要。
- 暗色默认、琥珀金主色、墨绿状态色——这是 Jack 的审美体系，不是随便选的。
- `networksetup` 比 `NetworkExtension` 简单 100 倍，对翻墙场景够用。
- MenuBarExtra 是 Mac App 最好的"常驻"方式——不打扰、随时在。

---

## 十、Jack 的审美速查

| 追求 | 厌恶 |
|------|------|
| 真实、克制、高级 | PPT 式信息堆叠 |
| 纪录感、温情、情绪流动 | "只有概念没有执行" |
| 画面自己说话 | 堆砌信息、敷衍 |
| 电影感、统一世界观 | 虚假宏大叙事 |
| "写人话" | "假大空" |

**配色：** 底 `#141416` / 琥珀金 `#D4A853` / 墨绿 `#34C759` / 暗紫 `#B898A4`

**字体：** 系统 SF Pro，按钮里那个"连"字用 `.serif` 设计（更有手感）
