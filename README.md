# Flow

> 点一下，连接就开始流动。

Flow 是一个给普通人用的轻量代理客户端：界面只有一个核心动作——连接 / 断开。它把 Xray 的复杂配置藏在后面，让你不用先学一堆网络术语，也能看懂现在是不是连上了、走的是哪个节点、局域网端口是多少。

![Flow concept](assets/flow-concept.png)

## 它解决什么问题？

很多代理工具功能很全，但第一次打开就像驾驶舱：按钮多、名词多、设置也多。Flow 的思路相反：

- 打开以后，先看到一个大按钮
- 点一下，启动本地代理和系统代理
- 再点一下，停止连接
- 需要换节点、改端口时，再进入设置

简单说，就是把“能不能用”放在第一位，把“高级设置”放在第二位。

## 它是怎么工作的？

```text
你的设备 → Flow 小界面 → 本地 SOCKS5 / HTTP 端口 → Xray → 你的节点
                                      └→ 局域网设备也可以按需使用
```

Flow 目前包含几个平台方向：

- macOS：SwiftUI 菜单栏 / 窗口客户端
- Windows：原生 WPF 客户端和 Electron 实验版本
- Android：Jetpack Compose 客户端实验版本
- prototype：用于讨论界面和交互的静态原型

## 安全说明

这个公开仓库故意不包含真实服务器、UUID、Reality 公钥、订阅 token 或本地认证信息。源码里的节点只是示例占位符：

```text
example.com
00000000-0000-0000-0000-000000000000
REPLACE_WITH_PRIVATE_REALITY_PUBLIC_KEY
```

你自己的节点请放在本地配置或私有服务里，不要直接提交到公开仓库。远程节点地址可以通过 `FlowRemoteNodesURL`（macOS）或 `FLOW_REMOTE_NODES_URL`（Windows Electron / WPF）注入。

## macOS：本地运行

要求：macOS 14+、Swift 5.9+。

```bash
cd Sources/Flow
swift run
```

## macOS：打包 `.app`

```bash
./Scripts/build_app.sh
```

如果要把 Xray core 放进应用包，请在本地设置路径，不要把私有节点配置一起提交：

```bash
FLOW_CORE_SRC="/你的本地路径/Resources/Cores" ./Scripts/build_app.sh
```

构建结果会在 `build-output/Flow.app`。

## 端口概念，用大白话说

- SOCKS5：给支持代理设置的软件用
- HTTP：给浏览器、手机或局域网设备用
- 系统代理：让 macOS 里遵守系统代理的应用自动走 Flow
- 局域网共享：同一 Wi‑Fi 下的其他设备可以手动填写这台 Mac 的局域网 IP 和端口

## 当前版本

`v1.0.0` · 首次整理发布版

这版的重点是把跨平台源码、设计文档和安全的公开配置整理到一起。它是可继续开发的源码版，不代表所有平台都已经达到同样成熟度。

## 目录速览

```text
Sources/Flow/       macOS SwiftUI 主程序
windows/            Windows WPF 版本
windows-electron/   Windows Electron 实验版本
android/            Android 实验版本
prototype/          界面原型
Scripts/            构建脚本
```

## License

暂未指定开源许可证。公开内容用于个人项目展示与后续开发；如果你要在其他项目中分发，请先联系作者确认授权方式。
