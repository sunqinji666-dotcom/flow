# Flow App 设计基线

## Mac (SwiftUI) — 已完成 MVP，正在抛光

- 深色玻璃底，火箭发射感。
- 默认只提供本地代理；不改系统代理。
- SOCKS5:10606 HTTP:10607，端口自动顺延。
- 系统代理开关。
- 分流四档：不代理 / 绕过大陆 / 绕过局域网 / 全局代理。
- 远程节点订阅 + 真实验证 + 本机缓存。
- 菜单栏使用原生 NSStatusItem + 代码绘制模板图标。
- Xray 内核：内置 XA 26.6.1，通过 Process 启动 + 配置注入。

## Android (Kotlin + Jetpack Compose) — 工程完整

### 内核
- **AndroidLibXrayLite AAR** (2dust维护，v2rayNG 同款方案)。
- 通过 `libv2ray.LibV2ray.startXray/stopXray/isXrayRunning` 内嵌调用。
- 不需要外挂进程管理。

### 工程结构
```
android/
  build.gradle.kts / settings.gradle.kts / gradle.properties
  app/build.gradle.kts  — Compose + OkHttp + kotlinx.serialization + AndroidLibXrayLite AAR
  app/src/main/
    AndroidManifest.xml
    java/com/jacksun/flow/
      FlowNode.kt         — 节点模型
      FlowState.kt        — ViewModel (订阅/验证/连接/统计/分流)
      XrayCore.kt         — Xray 内核封装 (AndroidLibXrayLite)
      FlowVpnService.kt   — Android VPN Service
      MainActivity.kt     — Compose UI 主界面
    res/ — themes / colors / strings / xml
    libs/ — 放置 AndroidLibXrayLite .aar
```

### UI — 与 Mac 一致
- 深色玻璃底
- "Flow" 品牌
- 连接按钮
- 节点国旗 + 名称 + 延迟 + 弹出选择
- 模式条 (本地端口 / 系统代理 + 分流)
- 状态条 / 流量卡片
- 设置齿轮面板

## Windows (WPF + .NET 8) — 工程完整

### 内核
- **XTLS/Xray-core 官方预编译二进制** `xray.exe` (Xray-windows-64.zip)
- 通过 Process.Start 调用，与 Mac 逻辑完全一致。

### 工程结构
```
windows/
  Flow/
    Flow.csproj         — net8.0-windows WPF
    FlowNode.cs         — 节点模型
    XrayCoreManager.cs  — 内核管理 (启动/停止/检测/端口)
    MainWindow.xaml/.cs — 主界面
    NodePickerWindow.*  — 节点选择弹窗
    SettingsWindow.*    — 设置面板
    App.xaml/.cs        — 启动/退出清理
    xray-core/          — 放置 xray.exe
```

### UI — 与 Mac 一致
- 深色玻璃底
- 连接按钮 / 节点国旗 / 弹出选择
- 模式条 / 分流策略
- 状态 + 流量卡片
- 设置面板

## 三端统一规则
- SOCKS5:10606 HTTP:10607
- 默认不改系统代理
- 系统代理开关
- 分流四档
- 远程节点：通过本地私有配置注入，不在公开源码中写入地址或 token
- 真实验证：启动 Xray → SOCKS 代理访问 Google generate_204
- 不通过节点不显示
