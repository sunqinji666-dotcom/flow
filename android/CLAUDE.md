# Flow — Android VPN 代理应用

## 项目概要
- 包名: `com.jacksun.flow`
- 语言: Kotlin + Jetpack Compose
- 最低 SDK: 26, 目标/编译 SDK: 35
- 版本: v2.2（状态栏标注）

## 核心架构

```
用户点"连"按钮
  → MainActivity.toggleConnection()
  → FlowState.connect()
  → FlowState.xrayConfig(node)   // 根据选中节点生成 JSON 配置
  → XrayCore.start(context, config)
      → 从 assets/flow-core/ 提取 xray 二进制到 filesDir
      → 写 flow-config.json
      → ProcessBuilder 启动 xray run
  → FlowVpnService (Android VpnService)
      → 建立 TUN 接口 (10.0.0.2/24, route 0.0.0.0/0)
      → 前台通知栏显示连接状态
```

## 文件职责

| 文件 | 路径 | 作用 |
|------|------|------|
| `MainActivity.kt` | `app/src/main/java/com/jacksun/flow/` | 唯一的 Activity, Compose UI, 深色主题 |
| `FlowState.kt` | 同上 | ViewModel, 管理连接状态/节点列表/流量统计/分流策略 |
| `FlowNode.kt` | 同上 | 节点数据类, 支持 VLESS/VMess/Trojan/SS/Hysteria2 |
| `XrayCore.kt` | 同上 | Xray 核心封装: 提取二进制→写配置→启动进程 |
| `FlowVpnService.kt` | 同上 | Android VpnService, TUN 隧道 + 前台通知 |

## 关键配置
- 本地 SOCKS5 代理: `127.0.0.1:10606`
- 本地 HTTP 代理: `127.0.0.1:10607`
- 默认分流策略: `bypassCN` (绕过大陆)
- 远程节点订阅：通过本地私有配置注入，不写入公开源码
- SDK 路径 (Apple Silicon Mac): `/opt/homebrew/share/android-commandlinetools`
- Java: `/opt/homebrew/opt/openjdk@21`

## 编译命令

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/35.0.0:/opt/homebrew/bin:$PATH

cd /Users/jacksun/Documents/Flow/android
./gradlew assembleDebug
# APK 在 app/build/outputs/apk/debug/app-debug.apk
```

---

## ⚠️ 核心问题：点"连"后显示"核心启动失败"

### 现象
- 点"连"→ 状态栏显示"核心启动失败"
- `adb logcat -s Flow:*` 显示 Xray 进程 `isAlive=false`
- APK 本身不闪退，UI 正常，节点能拉取

### 根因
**Android 10+ (API 29+) 的 W^X 安全策略禁止从私有数据目录执行二进制文件。**

当前代码流程（`XrayCore.kt`）：
1. 从 `assets/flow-core/xray` 解压 xray 二进制到 `context.filesDir/xray`
2. `binary.setExecutable(true)`
3. `ProcessBuilder(binary.absolutePath, "run", "-config", ...).start()`

第 3 步时，Android 系统检测到 `filesDir`（路径类似 `/data/data/com.jacksun.flow/files/xray`）不是系统认可的可执行目录，直接拒绝，进程立即退出。

这不是权限问题（`setExecutable` 返回 true），也不是文件不存在问题——是 **Android 安全机制层面禁止**。

### 日志特征
```
Flow: XrayCore.start() called
Flow: Binary: /data/data/com.jacksun.flow/files/xray, exists: true
Flow: Config written to /data/data/com.jacksun.flow/files/flow-config.json
Flow: Process started
Flow: Xray alive: false    ← 关键：进程立即退出
```

---

## 推荐修复方案：Go Mobile 编译 Xray 为 AAR

### 原理
v2rayNG 在 Android 上的做法：把 Xray-core 通过 gomobile 编译成一个 AAR 文件（包含 `libgojni.so`），然后通过 JNI 调用。`.so` 文件由 Android 系统在 APK 安装时自动解压到 `/data/app/.../lib/arm64/`——这个目录天然可执行，不受 W^X 限制。

### 具体步骤

**1. 写一个 Go wrapper（导出两个函数给 JNI）**

```go
// xray_wrapper.go
package xray

import (
    "github.com/xtls/xray-core/core"
)

var instance *core.Instance

func StartXray(configJson string) error {
    config, err := core.LoadConfig("json", configJson)
    if err != nil { return err }
    server, err := core.New(config)
    if err != nil { return err }
    instance = server
    return server.Start()
}

func StopXray() {
    if instance != nil {
        instance.Close()
        instance = nil
    }
}
```

**2. 编译成 AAR**

```bash
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
gomobile bind -target=android -androidapi 21 -o xray-core.aar .
```

**3. 放入 Flow 工程**

```bash
cp xray-core.aar /Users/jacksun/Documents/Flow/android/app/libs/
```

**4. 修改 `build.gradle.kts`**

```kotlin
dependencies {
    implementation(files("libs/xray-core.aar"))
}
```

**5. 修改 `XrayCore.kt`**

```kotlin
import xray.Xray

object XrayCore {
    fun start(ctx: Context, config: String): Boolean {
        return try {
            Xray.startXray(config)
            true
        } catch (e: Exception) {
            false
        }
    }

    fun stop() {
        try { Xray.stopXray() } catch (_: Exception) {}
    }
}
```

### 优缺点

| 优点 | 缺点 |
|------|------|
| `.so` 放在系统认可的可执行目录，不受 W^X 限制 | 需要编译 Xray 源码（需 Go + gomobile + Android NDK） |
| v2rayNG 验证过的成熟方案 | AAR 体积约 35-56MB |
| JNI 调用比 ProcessBuilder 更稳定 | 需要理解 Go Mobile 的线程模型 |

### 备选方案：预编译的 libv2ray.aar

如果想跳过编译步骤，可以用 2dust 维护的预编译 AAR：

```
https://github.com/2dust/AndroidLibXrayLite/releases/download/v26.6.22/libv2ray.aar
```

这个 AAR 的 API：
- `Libv2ray.initCoreEnv(assetsPath, configDir)` — 初始化
- `Libv2ray.newCoreController(callback)` → `CoreController`
- `CoreController.startLoop(config, timeout)` — 等同于启动 Xray
- `CoreController.stopLoop()` — 停止
- `Libv2ray.measureOutboundDelay(config, url)` — 测延迟

之前尝试过这个方案但闪退了，原因是 `CoreCallbackHandler` 是抽象类，没正确实现。正确的实现：

```kotlin
import libv2ray.*

object XrayCore {
    private var controller: CoreController? = null
    private var initDone = false

    fun init(ctx: Context) {
        if (initDone) return
        // 必须在后台线程调用，否则 ANR
        Libv2ray.initCoreEnv(ctx.filesDir.path, ctx.filesDir.path)
        initDone = true
    }

    fun start(config: String): Boolean {
        stop()
        return try {
            val cb = object : CoreCallbackHandler() {
                override fun onEmitStatus(status: Long, msg: String?): Long {
                    Log.d("Flow", "Xray: $status $msg")
                    return 0L
                }
            }
            val c = Libv2ray.newCoreController(cb)
            c.startLoop(config, 10)
            controller = c
            true
        } catch (e: Exception) {
            false
        }
    }

    fun stop() {
        try { controller?.stopLoop() } catch (_: Exception) {}
        controller = null
    }
}
```

**注意**：`CoreCallbackHandler` 不是 abstract class——它是 Go 生成的普通类，不需要继承也不需要实现任何方法。直接用 `Libv2ray.newCoreController(null)` 即可。

---

## assets/flow-core/ 内容
- `xray` — ARM64 Go 静态编译的 Xray 二进制 (29MB)
- `geoip.dat` — IP 地理位置数据（可选，分流用）
- `geosite.dat` — 域名分类数据（可选，分流用）

> 如果改用 AAR 方案，assets 里的这些文件不再需要。

## 备份文件 (.bak)
- `XrayCore.kt.bak`
- `FlowState.kt.bak`
- `MainActivity.kt.bak`
- `app/build.gradle.kts.bak`

## Windows/Electron 版
- 代码在 `/Users/jacksun/Documents/Flow/windows-electron/`
- 用 electron-builder 打包, 包含 xray-core/xray.exe
- Mac 版在 `/Users/jacksun/Documents/Flow/Sources/Flow/`
- 下载站: `https://flow.jack-sun.com`
- 七牛 CDN: `https://cloud-cdn.jack-sun.com/flow-releases/`
