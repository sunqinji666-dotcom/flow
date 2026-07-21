# Flow for macOS: Complete English Guide

[Project home](../README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [Latest release](https://github.com/sunqinji666-dotcom/flow/releases/latest)

## Contents

1. [What Flow is](#what-flow-is)
2. [Who it is for](#who-it-is-for)
3. [How a connection works](#how-a-connection-works)
4. [Interface and concepts](#interface-and-concepts)
5. [Flow versus NetFlow](#flow-versus-netflow)
6. [Privacy boundary](#privacy-boundary)
7. [Download and configuration](#download-and-configuration)
8. [Run and build from source](#run-and-build-from-source)
9. [Troubleshooting](#troubleshooting)

## What Flow is

Flow is a focused proxy client built specifically for macOS. It keeps Xray, node validation, local listeners, system proxy configuration, and routing rules behind a calm interface.

The main window gives you a connection state, the selected node, and one primary circular control. Click once to connect, click again to disconnect. The menu bar provides the same common actions without keeping the window open.

Flow is guided by three goals:

- Keep the connection action simple
- Make the current state easy to verify
- Keep private credentials separate from public source code

## Who it is for

Flow is for people who want a small everyday connection tool without living inside a complex network dashboard. Most of the time, the status and primary button should be enough.

If you need large subscription libraries, advanced routing editors, detailed logs, or server administration, a full management tool such as NetFlow is a better fit. Flow does not try to replace it.

## How a connection works

```text
macOS application traffic
          ↓
Flow system proxy or local listener
          ↓
Local Xray core
          ↓
Your private node
          ↓
Destination network
```

### 1. Load nodes

Flow can reuse previously validated nodes or load a list from your private remote endpoint. The public repository does not include the author's working nodes.

### 2. Perform a real validation

A reachable server port does not prove that a proxy works. Flow starts temporary local proxy instances for candidate nodes and performs an actual traffic check through them.

### 3. Start local listeners

After validation, Flow starts the main Xray process. The defaults are:

- SOCKS5: `127.0.0.1:10606`
- HTTP: `127.0.0.1:10607`

### 4. Apply the system proxy

When System Proxy is enabled, Flow points the active macOS network services to its local HTTP, HTTPS, and SOCKS listeners. On disconnect, it attempts to restore and clean those settings.

## Interface and concepts

### Primary circular button

The connect/disconnect action. A successful connection updates the button, status text, colors, and menu bar icon together.

### Node

A node is the remote endpoint through which traffic exits. Flow shows its name, protocol, transport, and validation result. The actual node credentials remain private.

### System Proxy mode

Compatible macOS applications automatically use Flow. Some software may ignore the system proxy because it uses its own network stack.

### Local Port mode

With System Proxy disabled, Xray can continue running locally. Configure selected applications to use the SOCKS5 or HTTP listener manually.

### Routing modes

- **Direct**: do not send matching traffic through the proxy node
- **Bypass Mainland China**: direct common mainland traffic and route the rest by policy
- **Bypass LAN**: keep local network traffic direct
- **Global Proxy**: send as much matching traffic as possible through the node

### Traffic and duration

Flow displays session, daily, and accumulated traffic together with connection duration. These values are useful operational indicators, not carrier-grade billing records.

## Flow versus NetFlow

| Flow | NetFlow |
| --- | --- |
| Focused daily connection client | Full network and node management tool |
| Minimal controls and visible state | More subscriptions, routing, logs, and management features |
| This repository maintains macOS Flow only | A separate project with a different scope |

This repository contains neither NetFlow nor the older Android, Windows, or Electron experiments.

## Privacy boundary

### Appropriate for the public repository

- SwiftUI interface and application logic
- Build scripts and product documentation
- Placeholder node structures
- Images with no credentials or private customer data

### Keep private

- Real server IP addresses, domains, and identifying endpoint combinations
- UUID, Reality public key, and shortId
- Subscription URLs and access tokens
- `.env`, SSH private keys, cookies, and Keychain data

The placeholder node in the public source is intentionally unusable. Cloning the repository does not provide access to any private network service.

## Download and configuration

### Download

Get the latest version from [GitHub Releases](https://github.com/sunqinji666-dotcom/flow/releases/latest). The current public build targets Apple Silicon (`arm64`).

If the package is split into two files, follow the merge command on the Release page and verify the SHA-256 checksum before use.

### Configure your private node endpoint

```bash
defaults write com.jacksun.flow FlowRemoteNodesURL "https://your-private-domain.example/flow/nodes.json"
```

Remove the local preference:

```bash
defaults delete com.jacksun.flow FlowRemoteNodesURL
```

Never commit the working URL or token to the public repository.

## Run and build from source

### Run

Requirements: macOS 14+, Swift 5.9+.

```bash
cd Sources/Flow
swift run
```

This is enough to inspect the interface. A working connection also requires an Xray core and your own valid node configuration.

### Package the app

```bash
FLOW_CORE_SRC="/your/local/path/Resources/Cores" \
FLOW_GEO_SRC="/your/local/path/routing-data" \
./Scripts/build_app.sh
```

Output:

```text
build-output/Flow.app
```

## Troubleshooting

### The interface opens, but connection fails

Confirm that the Xray executable exists, then verify that your private node is still valid. The public placeholder cannot connect.

### The server port is reachable, but proxy validation fails

Port reachability is not protocol validity. Check the UUID, Reality public key, SNI, shortId, protocol, security, and transport values as one matching set.

### Some applications still connect directly

Some applications ignore the macOS system proxy. Configure their SOCKS5 or HTTP proxy explicitly if they support it.

### Networking remains unusual after disconnect

Reopen Flow once so it can perform cleanup. If the issue remains, inspect the proxy options for the current service in macOS Network Settings.

### Can I publish my node JSON?

Usually, no. A complete node document contains connection credentials and should live behind access control.

---

Current version: `1.1.0` · Build: `2` · Platform: macOS 14+ · Architecture: Apple Silicon
