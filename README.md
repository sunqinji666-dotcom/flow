<div align="center">

# Flow for macOS

### One click. Clear status. Private configuration.

**一个按钮，清楚连接。 · One button, clear connection. · ひとつのボタンで、接続をわかりやすく。**

[简体中文](docs/README.zh-CN.md) · [English](docs/README.en.md) · [日本語](docs/README.ja.md)

</div>

![Flow for macOS hero](assets/flow-hero-v2.png)

<p align="center">
  <img src="assets/readme-status.png" alt="Flow version 1.1.0, macOS 14+, Apple Silicon, Swift 5.9+, private by default" width="100%">
</p>

<p align="center">
  <a href="https://github.com/sunqinji666-dotcom/flow/releases/latest"><img src="assets/readme-release.png" alt="Download Flow v1.1.0" width="340"></a>
  <a href="https://github.com/sunqinji666-dotcom/flow"><img src="assets/readme-star.png" alt="Star Flow on GitHub" width="340"></a>
</p>

<p align="center">
  <a href="#overview">Overview</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#privacy">Privacy</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#documentation">Documentation</a>
</p>

---

<a id="overview"></a>

## 01 · Overview / 项目概览 / 概要

Flow 是一款只为 macOS 制作的轻量代理客户端。它把 Xray、节点检测、系统代理和路由这些复杂步骤放到后台，把普通人真正关心的信息留在前面：**有没有连上、正在走哪里、系统代理是否开启、连接是否真的工作。**

Flow is a focused macOS proxy client that keeps Xray, validation, routing, and system proxy details behind a calm one-button interface.

Flow は、Xray・ノード検証・ルーティング・システムプロキシの複雑さを、シンプルな macOS インターフェースの裏側にまとめます。

| **Simple by design** | **Real connection checks** | **Private by default** |
| --- | --- | --- |
| 一个核心按钮，连接状态一眼可见。 | 不只测试端口，而是启动临时代理验证节点。 | 公开源码不包含真实节点、UUID 或 token。 |
| One primary action with visible state. | Nodes are tested through a temporary proxy. | Real credentials stay outside the repository. |
| 操作はひとつ、状態は明確。 | 一時プロキシで実際の接続を確認。 | 実際の認証情報は公開しません。 |

> **Flow is not NetFlow.** Flow focuses on quick everyday connection. NetFlow is the separate, more advanced management project.

---

<a id="how-it-works"></a>

## 02 · How it works / 工作方式 / 仕組み

![Flow architecture: Mac to Flow to local core to private node](assets/flow-how-it-works.png)

```text
Your Mac / 你的 Mac / あなたの Mac
              ↓
       Flow interface
              ↓
     Local Xray core
              ↓
  Your private node / 私有节点 / プライベートノード
```

| Stage | What Flow does | 大白话解释 |
| --- | --- | --- |
| **1 · Load** | Loads cached nodes or your private remote endpoint. | 先把你自己的节点读取进来。 |
| **2 · Validate** | Starts temporary local proxies and checks real traffic. | 不只看端口通不通，而是真的试着走一遍。 |
| **3 · Connect** | Starts local SOCKS5 and HTTP listeners through Xray. | 在 Mac 上开两个本地代理入口。 |
| **4 · Apply** | Optionally configures the macOS system proxy. | 你开启系统代理后，常用软件自动经过 Flow。 |

### The four ideas worth knowing

| Concept | Plain explanation | Default |
| --- | --- | --- |
| **Node / 节点** | Where your connection exits. / 连接从哪里出去。 | Private configuration |
| **SOCKS5** | A local proxy port for apps that support it. | `127.0.0.1:10606` |
| **HTTP Proxy** | A local HTTP/HTTPS proxy endpoint. | `127.0.0.1:10607` |
| **System Proxy** | Lets compatible macOS apps use Flow automatically. | User-controlled |

Routing modes include **Direct**, **Bypass Mainland China**, **Bypass LAN**, and **Global Proxy**. The default source setting is **Bypass Mainland China**.

---

<a id="privacy"></a>

## 03 · Privacy boundary / 隐私边界 / プライバシー境界

![Public source code and private connection configuration are separated](assets/flow-public-private.png)

The repository is public; your connection details should not be.

| Safe to publish | Keep private |
| --- | --- |
| SwiftUI interface and application logic | Real server IP addresses or private domains |
| Build scripts and design documents | UUID, Reality public key, shortId |
| Placeholder node structures | Subscription URLs and access tokens |
| Credential-free images and documentation | `.env`, SSH, Cookie, Keychain data |

The public source intentionally uses unusable placeholders:

```text
example.com
00000000-0000-0000-0000-000000000000
REPLACE_WITH_PRIVATE_REALITY_PUBLIC_KEY
```

This separation is deliberate: cloning the source does **not** grant access to the author's private network configuration.

---

<a id="quick-start"></a>

## 04 · Quick start / 快速开始 / クイックスタート

### Download

The latest public build is available on the [Releases page](https://github.com/sunqinji666-dotcom/flow/releases/latest). The macOS arm64 package includes the application and Xray runtime, but no private node credentials.

### Run from source

Requirements: macOS 14+, Swift 5.9+.

```bash
cd Sources/Flow
swift run
```

### Configure your private endpoint

```bash
defaults write com.jacksun.flow FlowRemoteNodesURL "https://your-private-domain.example/flow/nodes.json"
```

Remove the local setting:

```bash
defaults delete com.jacksun.flow FlowRemoteNodesURL
```

### Build the app

```bash
FLOW_CORE_SRC="/your/local/path/Resources/Cores" \
FLOW_GEO_SRC="/your/local/path/routing-data" \
./Scripts/build_app.sh
```

Output:

```text
build-output/Flow.app
```

---

<a id="documentation"></a>

## 05 · Documentation / 完整文档 / ドキュメント

| Language | Complete guide | 内容 |
| --- | --- | --- |
| 🇨🇳 **简体中文** | [阅读中文完整说明](docs/README.zh-CN.md) | 产品概念、界面、配置、安全、构建与故障定位 |
| 🇺🇸 **English** | [Read the complete English guide](docs/README.en.md) | Product model, interface, setup, privacy, build, troubleshooting |
| 🇯🇵 **日本語** | [日本語の完全ガイドを読む](docs/README.ja.md) | 製品概要、画面、設定、プライバシー、ビルド、問題の切り分け |

Additional project documents:

- [Product design document](FLOW_DESIGN_DOC.md)
- [Application design baseline](FLOW_APP_DESIGN_BASELINE.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [Private configuration example](PRIVATE_CONFIG.example.md)

---

## 06 · Project structure / 项目结构 / 構成

```text
Flow/
├── Sources/Flow/
│   ├── FlowApp.swift          Window, menu bar, app lifecycle
│   ├── ContentView.swift      Main UI, settings, node picker
│   ├── AppState.swift         Validation, Xray, proxy, traffic state
│   └── Package.swift          Swift Package configuration
├── Scripts/                   Build and README asset scripts
├── assets/                    App icon and raster documentation art
├── docs/                      Chinese, English, and Japanese guides
├── SECURITY.md                Public/private boundary
├── CHANGELOG.md               Version history
└── VERSION                    Single source of release version
```

---

## 07 · Release status / 版本状态 / リリース情報

| Item | Current value |
| --- | --- |
| Application version | `1.1.0` |
| Build number | `2` |
| Platform | macOS 14+ |
| Public architecture | Apple Silicon (`arm64`) |
| Swift tools | 5.9+ |
| Runtime core | Xray, supplied during packaging |
| Repository scope | Flow for macOS only |

---

<div align="center">

## If Flow feels useful, give it a Star ⭐

Stars make the project easier to find and show that clear, privacy-conscious software is worth building.

[Download the latest release](https://github.com/sunqinji666-dotcom/flow/releases/latest) · [Star the repository](https://github.com/sunqinji666-dotcom/flow) · [View source](Sources/Flow)

**Flow makes the connection understandable—not more complicated.**

</div>

---

## License

No open-source license has been selected yet. The public repository is available for personal project presentation and continued development. Contact the author before redistribution or commercial use.
