# Flow for macOS

> 不想研究一堆网络名词？打开 Flow，选好节点，点一下就行。

![Flow 主视觉：Mac、连接按钮与网络光流](assets/flow-hero-v2.png)

Flow 是一款只为 macOS 做的轻量代理客户端。它把复杂的 Xray 配置藏在后台，把真正需要看的东西留在前面：有没有连上、正在用哪个节点、速度怎么样、系统代理有没有开启。

这不是一个“什么功能都往里塞”的网络控制台。Flow 的目标很简单：**让连接这件事变得直观、安静、容易确认。**

## 先说人话：它到底是干什么的？

平时使用代理工具，最麻烦的往往不是“连不上”，而是不知道哪里出了问题：节点有没有加载？核心有没有启动？系统代理有没有打开？端口有没有被占用？

Flow 把这些步骤收进一个小窗口：

- 打开 App，看到当前节点和连接状态
- 点中间的圆形按钮，Flow 启动本地 Xray
- 如果开启了系统代理，Mac 会自动使用 Flow
- 再点一次，Flow 停止连接并清理系统代理
- 菜单栏里也可以连接、断开、切换节点和查看端口

你不需要先理解 VLESS、Reality、SOCKS5 或路由规则，照样能知道“现在能不能用”。想深入研究时，源码和设置又都在那里。

## 点下按钮之后，发生了什么？

![Flow 工作流程：Mac、Flow、本地核心与私有节点](assets/flow-how-it-works.png)

可以把它理解成四段：

```text
你的 Mac → Flow 界面 → 本地 Xray 核心 → 你自己的私有节点
```

1. **Flow 读取节点**：可以使用本地缓存，也可以从你自己的私有地址更新。
2. **Flow 做真实检测**：临时启动测试连接，检查节点是不是真的能用，而不只看服务器端口有没有回应。
3. **Flow 启动本地代理**：默认提供 SOCKS5 `10606` 和 HTTP `10607` 两个端口。
4. **Flow 按你的选择接管网络**：系统代理打开时，macOS 中遵守系统代理的应用会自动经过 Flow；关闭时，只保留本地端口给指定软件使用。

## 界面上的信息，分别是什么意思？

### 大圆按钮

它只有两个动作：连接和断开。连接成功后，按钮、状态颜色和菜单栏图标会一起变化，不用靠猜。

### 节点

节点就是“从哪里出去”。Flow 会显示节点名称、协议、传输方式和检测结果，也可以重新拉取并验证节点。

### 系统代理

- **打开**：Mac 上支持系统代理的软件自动走 Flow。
- **关闭**：Flow 只提供本地端口，哪个软件需要代理，就在哪个软件里手动填写端口。

### 分流策略

Flow 目前保留四种清晰的选择：不代理、绕过大陆、绕过局域网、全局代理。普通使用建议从“绕过大陆”开始。

### 流量与时长

界面会显示连接状态、连接时长、本次流量、今日流量和设备累计流量。它们主要用于快速判断连接是否真的在工作，不是运营商级别的计费统计。

## Flow 和 NetFlow 有什么区别？

这两个名字很像，但它们不是同一个项目：

| 项目 | 定位 | 适合谁 |
| --- | --- | --- |
| **Flow** | 一个按钮为核心的轻量 macOS 客户端 | 想简单连接、少看设置的人 |
| **NetFlow** | 更完整的节点、订阅、路由和流量管理工具 | 想深入管理网络配置的人 |

这个仓库现在只放 **Flow for macOS**。Android、Windows、Electron 实验代码和 NetFlow 源码都不在这里。

## 什么可以公开，什么必须留在本机？

![公开源码与私有配置分开保存](assets/flow-public-private.png)

程序源码可以公开，真实连接信息不可以公开。这个仓库已经把两者分开：

| 可以放在 GitHub | 只应保存在私有位置 |
| --- | --- |
| SwiftUI 界面和程序逻辑 | 真实服务器 IP 或域名 |
| 构建脚本和设计说明 | UUID、Reality 公钥、shortId |
| 示例节点结构 | 订阅地址和访问 token |
| 不含凭据的图片和文档 | `.env`、SSH、Cookie、Keychain |

公开源码里的默认节点故意写成不能直接使用的占位符：

```text
example.com
00000000-0000-0000-0000-000000000000
REPLACE_WITH_PRIVATE_REALITY_PUBLIC_KEY
```

这意味着：**公开版本不会偷偷附送作者的私人线路。** 你需要配置自己的合法节点或私有节点服务，Flow 才能真正连接。

## 配置自己的远程节点地址

macOS 版本会从 `FlowRemoteNodesURL` 读取你的私有节点地址：

```bash
defaults write com.jacksun.flow FlowRemoteNodesURL "https://你的私有域名/flow/nodes.json"
```

要恢复为空值，可以执行：

```bash
defaults delete com.jacksun.flow FlowRemoteNodesURL
```

不要把带 token 的真实地址写回公开源码。

## 下载与使用

最新版本是 **v1.1.0 · 纯 macOS 整理版**。

可以在 [GitHub Releases](https://github.com/sunqinji666-dotcom/flow/releases/latest) 查看下载文件和校验值。当前公开安装包包含程序与 Xray 运行核心，但不包含私人节点。

由于网页上传单文件大小限制，完整安装包可能被拆成两个分片；Release 页面会提供合并命令和 SHA-256 校验值。

## 从源码运行

要求：macOS 14 或更高版本、Swift 5.9 或更高版本。

```bash
cd Sources/Flow
swift run
```

注意：只运行 Swift 源码可以看到界面，但真正连接还需要本机有可用的 Xray core 和你自己的节点配置。

## 打包成 macOS App

```bash
./Scripts/build_app.sh
```

把本机的 Xray core 一起放进应用包：

```bash
FLOW_CORE_SRC="/你的本地路径/Resources/Cores" ./Scripts/build_app.sh
```

如果还要复制本地路由数据：

```bash
FLOW_CORE_SRC="/你的本地路径/Resources/Cores" \
FLOW_GEO_SRC="/你的本地路径/路由数据" \
./Scripts/build_app.sh
```

构建结果会出现在：

```text
build-output/Flow.app
```

## 项目目录

```text
Sources/Flow/
├── FlowApp.swift       App 入口、窗口和菜单栏
├── ContentView.swift   主界面、设置和节点选择
├── AppState.swift      节点检测、Xray、代理和流量状态
└── Package.swift       Swift Package 配置

Scripts/                macOS 构建脚本
assets/                 图标与 README 图片
FLOW_DESIGN_DOC.md      完整产品设计说明
SECURITY.md             公开仓库的安全边界
CHANGELOG.md            版本变化记录
```

## 当前状态

- 平台：macOS 14+
- 架构：当前 Release 为 Apple Silicon（arm64）
- 应用版本：`1.1.0`
- 构建号：`2`
- Xray：构建时从本机指定目录复制，不把私人配置打进源码
- 公开仓库：已移除真实节点、订阅 token 和本地凭据

## 一句话总结

Flow 不是为了让网络工具看起来更复杂，而是为了让你随时知道：**现在连没连上、从哪里走、出了问题该看哪里。**

## License

暂未指定开源许可证。公开内容用于个人项目展示与后续开发；如需复制、分发或商业使用，请先联系作者确认授权。
