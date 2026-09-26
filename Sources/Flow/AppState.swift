import SwiftUI
import Combine
import Foundation
import Network
import Darwin

@MainActor
final class AppState: ObservableObject {
    @Published var isConnected = false
    @Published var activeNode: FlowNode?
    @Published var nodes: [FlowNode]?
    @Published var selectedIndex = 0
    @Published var isTestingLatency = false
    @Published var nodeUpdateMessage = "本机节点库"
    @Published var downloadSpeed = "—"
    @Published var uploadSpeed = "—"
    @Published var connectionStatus = "准备就绪"
    @Published var connectedDuration = "00:00"
    @Published var sessionTraffic = "0 MB"
    @Published var todayTraffic = "0 MB"
    @Published var totalTraffic = "0 MB"
    @Published var socksPort = "10606"
    @Published var httpPort = "10607"
    @Published var systemProxyEnabled = UserDefaults.standard.bool(forKey: "FlowSystemProxyEnabled")
    @Published var routingMode = UserDefaults.standard.string(forKey: "FlowRoutingMode") ?? "bypassCN"
    private var apiPort = 10608
    private var didApplySystemProxy = UserDefaults.standard.bool(forKey: "FlowDidApplySystemProxy")

    private var coreProcess: Process?
    private var speedTimer: Timer?
    private var connectedAt: Date?
    private var sessionUplinkBytes: Double = 0
    private var sessionDownlinkBytes: Double = 0
    private var lastTrafficBytes: Double = 0
    private var lastTrafficSampleAt: Date?
    private var todayBytes: Double {
        get { UserDefaults.standard.double(forKey: Self.todayTrafficKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.todayTrafficKey) }
    }
    private var totalBytes: Double {
        get { UserDefaults.standard.double(forKey: "FlowTotalTrafficBytes") }
        set { UserDefaults.standard.set(newValue, forKey: "FlowTotalTrafficBytes") }
    }

    private static var todayTrafficKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "FlowTrafficBytes-\(formatter.string(from: Date()))"
    }

    init() {
        Self.cleanupOrphanFlowCores()
        // Remove the legacy remote-subscription preference during upgrade.
        // Flow no longer reads, writes, or contacts a node server.
        UserDefaults.standard.removeObject(forKey: "FlowRemoteNodesURL")
        if let cached = Self.loadCachedValidNodes(), !cached.isEmpty {
            nodes = cached
            nodeUpdateMessage = "本机节点库 · \(cached.count) 个"
        } else {
            nodes = []
            nodeUpdateMessage = "本机节点库为空"
        }
    }

    nonisolated private static func forceStop(process: Process) {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        Darwin.kill(pid, SIGTERM)
        Thread.sleep(forTimeInterval: 0.25)
        if process.isRunning {
            Darwin.kill(pid, SIGKILL)
            Thread.sleep(forTimeInterval: 0.1)
        }
        if !process.isRunning {
            process.waitUntilExit()
        }
    }

    nonisolated private static func cleanupOrphanFlowCores() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        p.arguments = ["-f", "Flow.app/Contents/Resources/Cores/xray/xray"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    nonisolated private static func cacheURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Flow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("valid-nodes.json")
    }

    nonisolated private static func saveCachedValidNodes(_ nodes: [FlowNode]) {
        let envelope = FlowNodeEnvelope(version: 1, updatedAt: ISO8601DateFormatter().string(from: Date()), nodes: nodes)
        if let data = try? JSONEncoder().encode(envelope) {
            try? data.write(to: cacheURL(), options: .atomic)
        }
    }

    nonisolated private static func loadCachedValidNodes() -> [FlowNode]? {
        guard let data = try? Data(contentsOf: cacheURL()),
              let envelope = try? JSONDecoder().decode(FlowNodeEnvelope.self, from: data) else { return nil }
        return envelope.nodes
    }

    @discardableResult
    func importVLESSLink(_ rawLink: String) throws -> FlowNode {
        let trimmed = rawLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "vless",
              let host = components.host,
              let port = components.port,
              let uuid = components.user,
              !host.isEmpty,
              !uuid.isEmpty else {
            throw LocalNodeImportError.invalidLink
        }

        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        guard query["encryption"] == "none" else {
            throw LocalNodeImportError.unsupportedEncryption
        }

        let transport = query["type"]?.lowercased() ?? "tcp"
        guard transport == "tcp" else {
            throw LocalNodeImportError.unsupportedTransport(transport)
        }

        let security = query["security"]?.lowercased() ?? "none"
        guard security == "reality" else {
            throw LocalNodeImportError.unsupportedSecurity(security)
        }

        guard let sni = query["sni"], !sni.isEmpty,
              let publicKey = query["pbk"], !publicKey.isEmpty else {
            throw LocalNodeImportError.missingRealityParameters
        }

        let displayName = components.percentEncodedFragment?
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (displayName?.isEmpty == false ? displayName! : "\(host):\(port)")
        let flag = name.localizedCaseInsensitiveContains("us") ? "🇺🇸" : "🌐"
        let node = FlowNode(
            flag: flag,
            name: name,
            host: host,
            port: port,
            protocolType: "vless",
            uuid: uuid,
            flow: query["flow"]?.isEmpty == false ? query["flow"] : nil,
            sni: sni,
            fingerprint: query["fp"]?.isEmpty == false ? query["fp"]! : "chrome",
            publicKey: publicKey,
            shortId: query["sid"]?.isEmpty == false ? query["sid"] : nil,
            spiderX: query["spx"]?.isEmpty == false ? query["spx"] : nil,
            transport: transport,
            security: security,
            source: "local-import",
            rawLink: trimmed,
            latency: nil
        )

        var current = nodes ?? []
        if let existing = current.firstIndex(where: { $0.host == node.host && $0.port == node.port && $0.uuid == node.uuid }) {
            current[existing] = node
            selectedIndex = existing
            nodeUpdateMessage = "已更新本机链接"
        } else {
            current.append(node)
            selectedIndex = current.count - 1
            nodeUpdateMessage = "已导入到本机 · \(current.count) 个节点"
        }
        nodes = current
        Self.saveCachedValidNodes(current)
        return node
    }

    func deleteNode(at index: Int) {
        guard var current = nodes, current.indices.contains(index) else { return }
        let node = current[index]
        if isConnected, activeNode?.id == node.id {
            disconnect()
        }
        current.remove(at: index)
        nodes = current
        selectedIndex = max(0, min(selectedIndex, max(0, current.count - 1)))
        nodeUpdateMessage = current.isEmpty ? "本机节点库为空" : "已从本机移除 · \(current.count) 个节点"
        Self.saveCachedValidNodes(current)
    }

    func persistLocalNodes() {
        Self.saveCachedValidNodes(nodes ?? [])
    }

    func exportableVLESSLinks() -> [String] {
        (nodes ?? []).compactMap { node in
            if let rawLink = node.rawLink?.trimmingCharacters(in: .whitespacesAndNewlines),
               !rawLink.isEmpty {
                return rawLink
            }
            guard node.protocolType.lowercased() == "vless",
                  !node.uuid.isEmpty,
                  !node.host.isEmpty,
                  node.port > 0,
                  !node.sni.isEmpty,
                  let publicKey = node.publicKey,
                  !publicKey.isEmpty else { return nil }

            var components = URLComponents()
            components.scheme = "vless"
            components.user = node.uuid
            components.host = node.host
            components.port = node.port
            var queryItems = [
                URLQueryItem(name: "encryption", value: "none"),
                URLQueryItem(name: "flow", value: node.flow ?? "xtls-rprx-vision"),
                URLQueryItem(name: "security", value: node.security ?? "reality"),
                URLQueryItem(name: "sni", value: node.sni),
                URLQueryItem(name: "fp", value: node.fingerprint),
                URLQueryItem(name: "pbk", value: publicKey),
                URLQueryItem(name: "type", value: node.transport ?? "tcp")
            ]
            if let shortId = node.shortId, !shortId.isEmpty {
                queryItems.append(URLQueryItem(name: "sid", value: shortId))
            }
            if let spiderX = node.spiderX, !spiderX.isEmpty {
                queryItems.append(URLQueryItem(name: "spx", value: spiderX))
            }
            components.queryItems = queryItems
            components.fragment = node.name
            return components.string
        }
    }

    private func generateValidationConfig(node: FlowNode, socksPort: Int) -> String {
        let proxyOutbound: [String: Any]
        if let rawOutbound = node.rawOutbound?.any as? [String: Any] {
            proxyOutbound = rawOutbound
        } else {
            proxyOutbound = generatedOutbound(node: node)
        }

        let config: [String: Any] = [
            "log": ["loglevel": "error"],
            "inbounds": [
                ["tag": "socks-in", "port": socksPort, "listen": "127.0.0.1", "protocol": "socks", "settings": ["udp": true]]
            ],
            "outbounds": [
                proxyOutbound,
                ["tag": "direct", "protocol": "freedom"]
            ],
            "routing": [
                "domainStrategy": "AsIs",
                "rules": [
                    ["type": "field", "inboundTag": ["socks-in"], "outboundTag": "proxy"]
                ]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }


    nonisolated private static func xrayEnvironment(for executableURL: URL) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let assetDir = executableURL.deletingLastPathComponent().path
        env["XRAY_LOCATION_ASSET"] = assetDir
        env["V2RAY_LOCATION_ASSET"] = assetDir
        return env
    }

    nonisolated private static func runProxyValidation(xrayURL: URL, config: String, socksPort: Int) -> (ok: Bool, latency: Int?) {
        let configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("flow-validation-\(UUID().uuidString).json")
        do {
            try config.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            return (false, nil)
        }
        defer { try? FileManager.default.removeItem(at: configURL) }

        let xray = Process()
        xray.executableURL = xrayURL
        xray.arguments = ["run", "-config", configURL.path]
        xray.environment = Self.xrayEnvironment(for: xrayURL)
        xray.standardOutput = FileHandle.nullDevice
        xray.standardError = FileHandle.nullDevice

        do {
            try xray.run()
        } catch {
            return (false, nil)
        }
        defer {
            Self.forceStop(process: xray)
        }

        Thread.sleep(forTimeInterval: 0.9)
        guard xray.isRunning else { return (false, nil) }

        return testSocksProxy(socksPort: socksPort, connectTimeout: 4, maxTime: 8)
    }


    nonisolated private static func testSocksProxy(socksPort: Int, connectTimeout: Int, maxTime: Int) -> (ok: Bool, latency: Int?) {
        let testURLs = [
            "https://www.google.com/generate_204",
            "https://www.gstatic.com/generate_204",
            "https://www.cloudflare.com/cdn-cgi/trace"
        ]

        for testURL in testURLs {
            let started = Date()
            let curl = Process()
            curl.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            curl.arguments = [
                "--socks5-hostname", "127.0.0.1:\(socksPort)",
                "--connect-timeout", "\(connectTimeout)",
                "--max-time", "\(maxTime)",
                "-s",
                "-o", "/dev/null",
                "-w", "%{http_code}",
                testURL
            ]
            let pipe = Pipe()
            curl.standardOutput = pipe
            curl.standardError = FileHandle.nullDevice

            do {
                try curl.run()
                curl.waitUntilExit()
            } catch {
                continue
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let code = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ok = curl.terminationStatus == 0 && (code == "204" || code == "200")
            if ok {
                return (true, max(1, Int(Date().timeIntervalSince(started) * 1000)))
            }
        }
        return (false, nil)
    }

    nonisolated private static func shortTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    func toggleConnection() {
        if isConnected { disconnect() }
        else { connect() }
    }

    func reconnect() {
        disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.connect()
        }
    }

    func selectNode(_ index: Int) {
        guard let nodes, nodes.indices.contains(index) else { return }
        selectedIndex = index
        if isConnected { reconnect() }
    }

    var proxyStatusTitle: String {
        if isConnected {
            return systemProxyEnabled ? "系统代理模式" : "本地端口模式"
        }
        return "准备就绪"
    }

    var proxyModeHeadline: String {
        systemProxyEnabled ? "系统代理模式" : "本地端口模式"
    }

    var proxyModeDetail: String {
        if systemProxyEnabled {
            return isConnected ? "Mac 全局网络已接管" : "连接后自动接管 Mac 网络"
        }
        return "不改系统代理，其他软件手动填端口"
    }

    var proxyModeIcon: String {
        systemProxyEnabled ? "network" : "link"
    }

    var localProxyAddressTitle: String {
        "SOCKS5 127.0.0.1:\(socksPort) · HTTP 127.0.0.1:\(httpPort)"
    }

    func setSystemProxyEnabled(_ enabled: Bool) {
        systemProxyEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "FlowSystemProxyEnabled")
        if isConnected {
            let ok = setSystemProxy(enabled)
            if enabled {
                didApplySystemProxy = ok
                UserDefaults.standard.set(ok, forKey: "FlowDidApplySystemProxy")
                connectionStatus = ok ? "系统代理已开启" : "系统代理失败"
            } else {
                didApplySystemProxy = false
                UserDefaults.standard.set(false, forKey: "FlowDidApplySystemProxy")
                connectionStatus = "本地代理已启动"
            }
        }
    }

    func setRoutingMode(_ mode: String) {
        routingMode = mode
        UserDefaults.standard.set(mode, forKey: "FlowRoutingMode")
        if isConnected { reconnect() }
    }

    var routingModeTitle: String {
        switch routingMode {
        case "direct": return "不代理"
        case "global": return "全局代理"
        case "lanOnly": return "绕过局域网"
        default: return "绕过大陆"
        }
    }

    func testAllLatencies() {
        guard let nodes, !nodes.isEmpty else { return }
        isTestingLatency = true
        for index in nodes.indices {
            let node = nodes[index]
            Task {
                let latency = await Task.detached(priority: .background) {
                    Self.measureTCPConnectLatency(host: node.host, port: node.port)
                }.value
                updateLatency(index: index, latency: latency)
            }
        }
    }

    private func updateLatency(index: Int, latency: Int?) {
        guard var current = nodes, current.indices.contains(index) else { return }
        current[index].latency = latency
        nodes = current
        isTestingLatency = current.contains { $0.latency == nil }
    }

    nonisolated private static func measureTCPConnectLatency(host: String, port: Int) -> Int? {
        let start = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        process.arguments = ["-G", "2", "-z", host, "\(port)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return max(1, Int(Date().timeIntervalSince(start) * 1000))
        } catch {
            return nil
        }
    }

    private func connect() {
        guard let nodes = nodes, selectedIndex < nodes.count else {
            connectionStatus = "无可用节点"
            return
        }
        let node = nodes[selectedIndex]
        activeNode = node
        connectionStatus = "启动核心中"

        guard var socks = Int(socksPort), var http = Int(httpPort), socks > 0, http > 0 else {
            activeNode = nil
            connectionStatus = "端口无效"
            return
        }

        if !Self.isPortAvailable(socks) {
            socks = Self.findAvailablePort(startingAt: max(10609, socks + 2))
            socksPort = "\(socks)"
        }
        if !Self.isPortAvailable(http) || http == socks {
            http = Self.findAvailablePort(startingAt: max(socks + 1, http + 2))
            httpPort = "\(http)"
        }
        if !Self.isPortAvailable(apiPort) || apiPort == socks || apiPort == http {
            apiPort = Self.findAvailablePort(startingAt: 10608)
        }

        let config = generateXrayConfig(node: node, socksPort: socks, httpPort: http, apiPort: apiPort)
        let configDir = FileManager.default.temporaryDirectory.appendingPathComponent("flow-configs")
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        } catch {
            activeNode = nil
            connectionStatus = "配置目录失败"
            return
        }
        let configPath = configDir.appendingPathComponent("config.json")
        do {
            try config.write(to: configPath, atomically: true, encoding: .utf8)
        } catch {
            activeNode = nil
            connectionStatus = "配置写入失败"
            return
        }

        guard let xrayURL = findXrayExecutable() else {
            activeNode = nil
            connectionStatus = "找不到 Xray"
            return
        }

        let task = Process()
        task.executableURL = xrayURL
        task.arguments = ["run", "-config", configPath.path]
        task.environment = Self.xrayEnvironment(for: xrayURL)
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            Thread.sleep(forTimeInterval: 0.8)
            guard task.isRunning else {
                activeNode = nil
                connectionStatus = "Xray 启动失败"
                return
            }
            connectionStatus = "验证节点中"
            let realCheck = Self.testSocksProxy(socksPort: socks, connectTimeout: 3, maxTime: 6)
            guard realCheck.ok else {
                Self.forceStop(process: task)
                activeNode = nil
                connectionStatus = "节点不可用"
                return
            }
            var verifiedNode = node
            verifiedNode.latency = realCheck.latency ?? node.latency
            activeNode = verifiedNode
            coreProcess = task
            if systemProxyEnabled {
                let proxyOK = setSystemProxy(true)
                guard proxyOK else {
                    Self.forceStop(process: task)
                    coreProcess = nil
                    activeNode = nil
                    didApplySystemProxy = false
                    UserDefaults.standard.set(false, forKey: "FlowDidApplySystemProxy")
                    connectionStatus = "系统代理失败"
                    return
                }
                didApplySystemProxy = true
                UserDefaults.standard.set(true, forKey: "FlowDidApplySystemProxy")
            } else {
                didApplySystemProxy = false
                UserDefaults.standard.set(false, forKey: "FlowDidApplySystemProxy")
            }
            isConnected = true
            connectionStatus = systemProxyEnabled ? "系统代理已开启" : "本地代理已启动"
            connectedAt = Date()
            sessionUplinkBytes = 0
            sessionDownlinkBytes = 0
            lastTrafficBytes = 0
            lastTrafficSampleAt = nil
            refreshTrafficLabels()
            startSpeedSimulation()
        } catch {
            activeNode = nil
            connectionStatus = "连接失败"
        }
    }

    nonisolated private static func findAvailablePort(startingAt start: Int) -> Int {
        var port = start
        while port < 65000 {
            if isPortAvailable(port) { return port }
            port += 1
        }
        return start
    }

    nonisolated private static func isPortAvailable(_ port: Int) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus != 0
        } catch {
            return true
        }
    }

    private func disconnect() {
        if let coreProcess { Self.forceStop(process: coreProcess) }
        coreProcess = nil
        isConnected = false
        activeNode = nil
        downloadSpeed = "—"
        uploadSpeed = "—"
        connectionStatus = "已断开"
        connectedDuration = "00:00"
        sessionTraffic = formatBytes(sessionUplinkBytes + sessionDownlinkBytes)
        if didApplySystemProxy {
            _ = setSystemProxy(false)
            didApplySystemProxy = false
            UserDefaults.standard.set(false, forKey: "FlowDidApplySystemProxy")
        }
        speedTimer?.invalidate()
        speedTimer = nil
        connectedAt = nil
    }

    func shutdown() {
        disconnect()
    }

    @discardableResult
    private func setSystemProxy(_ enable: Bool) -> Bool {
        var ok = true
        for service in Self.networkServices() {
            if enable {
                ok = runNetworksetup(["-setwebproxy", service, "127.0.0.1", httpPort]) && ok
                ok = runNetworksetup(["-setsecurewebproxy", service, "127.0.0.1", httpPort]) && ok
                ok = runNetworksetup(["-setsocksfirewallproxy", service, "127.0.0.1", socksPort]) && ok
                ok = runNetworksetup(["-setwebproxystate", service, "on"]) && ok
                ok = runNetworksetup(["-setsecurewebproxystate", service, "on"]) && ok
                ok = runNetworksetup(["-setsocksfirewallproxystate", service, "on"]) && ok
            } else {
                ok = runNetworksetup(["-setwebproxystate", service, "off"]) && ok
                ok = runNetworksetup(["-setsecurewebproxystate", service, "off"]) && ok
                ok = runNetworksetup(["-setsocksfirewallproxystate", service, "off"]) && ok
            }
        }
        return ok
    }

    nonisolated static func cleanupSystemProxy() {
        guard UserDefaults.standard.bool(forKey: "FlowDidApplySystemProxy") else { return }
        for service in networkServices() {
            runNetworksetupStatic(["-setwebproxystate", service, "off"])
            runNetworksetupStatic(["-setsecurewebproxystate", service, "off"])
            runNetworksetupStatic(["-setsocksfirewallproxystate", service, "off"])
        }
        UserDefaults.standard.set(false, forKey: "FlowDidApplySystemProxy")
    }

    nonisolated private static func networkServices() -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-listallnetworkservices"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ["Wi-Fi"]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let services = String(data: data, encoding: .utf8)?
            .split(separator: "\n")
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("*") } ?? []
        return services.isEmpty ? ["Wi-Fi"] : services
    }

    private func findXrayExecutable() -> URL? {
        let bundleResource = Bundle.main.resourceURL ?? URL(fileURLWithPath: "/")
        let candidates = [
            bundleResource.appendingPathComponent("Cores/xray/xray"),
            bundleResource.appendingPathComponent("Cores/xray"),
            bundleResource.appendingPathComponent("xray/xray"),
            bundleResource.appendingPathComponent("xray"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/bin/xray/xray"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/bin/xray"),
            URL(fileURLWithPath: "/usr/local/bin/xray"),
            URL(fileURLWithPath: "/opt/homebrew/bin/xray"),
            URL(fileURLWithPath: "/Applications/v2rayN.app/Contents/MacOS/bin/xray/xray")
        ]

        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    @discardableResult
    private func runNetworksetup(_ args: [String]) -> Bool {
        Self.runNetworksetupStatic(args)
    }

    @discardableResult
    nonisolated private static func runNetworksetupStatic(_ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func startSpeedSimulation() {
        speedTimer?.invalidate()
        speedTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refreshStatsFromXray()
            }
        }
        refreshStatsFromXray()
    }

    private func refreshTrafficLabels() {
        if let connectedAt {
            let seconds = max(0, Int(Date().timeIntervalSince(connectedAt)))
            connectedDuration = String(format: "%02d:%02d", seconds / 60, seconds % 60)
        }
        sessionTraffic = formatBytes(sessionUplinkBytes + sessionDownlinkBytes)
        todayTraffic = formatBytes(todayBytes)
        totalTraffic = formatBytes(totalBytes)
    }

    private func refreshStatsFromXray() {
        guard isConnected, let xrayURL = findXrayExecutable() else { return }
        let stats = queryXrayTraffic(xrayURL: xrayURL)
        guard let stats else {
            downloadSpeed = "—"
            uploadSpeed = "—"
            refreshTrafficLabels()
            return
        }

        sessionUplinkBytes = stats.uplink
        sessionDownlinkBytes = stats.downlink

        let total = stats.uplink + stats.downlink
        let now = Date()
        if let lastSample = lastTrafficSampleAt {
            let interval = max(0.1, now.timeIntervalSince(lastSample))
            let delta = max(0, total - lastTrafficBytes)
            todayBytes += delta
            totalBytes += delta
            downloadSpeed = formatSpeed(max(0, stats.downlink - stats.previousDownlink) / interval)
            uploadSpeed = formatSpeed(max(0, stats.uplink - stats.previousUplink) / interval)
        }
        lastTrafficBytes = total
        lastTrafficSampleAt = now
        refreshTrafficLabels()
    }

    private func queryXrayTraffic(xrayURL: URL) -> (uplink: Double, downlink: Double, previousUplink: Double, previousDownlink: Double)? {
        let previousUplink = sessionUplinkBytes
        let previousDownlink = sessionDownlinkBytes

        let process = Process()
        process.executableURL = xrayURL
        process.arguments = ["api", "statsquery", "--server=127.0.0.1:\(apiPort)", "-pattern", "traffic"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let statItems = root["stat"] as? [[String: Any]]
        else { return nil }

        var outboundUplink: Double = 0
        var outboundDownlink: Double = 0
        var inboundUplink: Double = 0
        var inboundDownlink: Double = 0

        for item in statItems {
            guard let name = item["name"] as? String, name.contains(">>>traffic>>>") else { continue }
            let value: Double
            if let intValue = item["value"] as? Int {
                value = Double(intValue)
            } else if let doubleValue = item["value"] as? Double {
                value = doubleValue
            } else {
                value = 0
            }
            guard value > 0 else { continue }

            if name.contains("outbound>>>proxy>>>traffic>>>uplink") {
                outboundUplink += value
            } else if name.contains("outbound>>>proxy>>>traffic>>>downlink") {
                outboundDownlink += value
            } else if name.contains("inbound>>>socks-in>>>traffic>>>uplink") || name.contains("inbound>>>http-in>>>traffic>>>uplink") {
                inboundUplink += value
            } else if name.contains("inbound>>>socks-in>>>traffic>>>downlink") || name.contains("inbound>>>http-in>>>traffic>>>downlink") {
                inboundDownlink += value
            }
        }

        let hasOutbound = outboundUplink + outboundDownlink > 0
        let uplink = hasOutbound ? outboundUplink : inboundUplink
        let downlink = hasOutbound ? outboundDownlink : inboundDownlink

        guard uplink + downlink > 0 else { return nil }
        return (uplink, downlink, previousUplink, previousDownlink)
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let mb = bytesPerSecond / 1024 / 1024
        if mb >= 0.1 {
            return String(format: "%.1f MB/s", mb)
        }
        let kb = bytesPerSecond / 1024
        return String(format: "%.0f KB/s", kb)
    }

    private func formatBytes(_ bytes: Double) -> String {
        let gb = bytes / 1024 / 1024 / 1024
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        }
        let mb = bytes / 1024 / 1024
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        }
        return "0 MB"
    }

    private func generateXrayConfig(node: FlowNode, socksPort: Int, httpPort: Int, apiPort: Int) -> String {
        let listen = "0.0.0.0"
        let proxyOutbound: [String: Any]

        if let rawOutbound = node.rawOutbound?.any as? [String: Any] {
            proxyOutbound = rawOutbound
        } else {
            proxyOutbound = generatedOutbound(node: node)
        }

        let config: [String: Any] = [
            "log": ["loglevel": "warning"],
            "api": [
                "tag": "api",
                "services": ["StatsService"]
            ],
            "policy": [
                "system": [
                    "statsInboundUplink": true,
                    "statsInboundDownlink": true,
                    "statsOutboundUplink": true,
                    "statsOutboundDownlink": true
                ]
            ],
            "stats": [:],
            "inbounds": [
                ["tag": "socks-in", "port": socksPort, "listen": listen, "protocol": "socks", "settings": ["udp": true]],
                ["tag": "http-in", "port": httpPort, "listen": listen, "protocol": "http"],
                ["tag": "api-in", "port": apiPort, "listen": "127.0.0.1", "protocol": "dokodemo-door", "settings": ["address": "127.0.0.1"]]
            ],
            "outbounds": [
                proxyOutbound,
                ["tag": "direct", "protocol": "freedom"]
            ],
            "routing": [
                "domainStrategy": "IPIfNonMatch",
                "domainMatcher": "hybrid",
                "rules": routingRules()
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }


    private func routingRules() -> [[String: Any]] {
        let apiRule: [String: Any] = ["type": "field", "inboundTag": ["api-in"], "outboundTag": "api"]
        let lanRule: [String: Any] = [
            "type": "field",
            "ip": [
                "geoip:private",
                "127.0.0.0/8",
                "10.0.0.0/8",
                "172.16.0.0/12",
                "192.168.0.0/16",
                "169.254.0.0/16",
                "::1/128",
                "fc00::/7",
                "fe80::/10"
            ],
            "outboundTag": "direct"
        ]
        let proxyRule: [String: Any] = ["type": "field", "inboundTag": ["socks-in", "http-in"], "outboundTag": "proxy"]

        switch routingMode {
        case "direct":
            let directRule: [String: Any] = ["type": "field", "inboundTag": ["socks-in", "http-in"], "outboundTag": "direct"]
            return [apiRule, directRule]
        case "global":
            return [apiRule, proxyRule]
        case "lanOnly":
            return [apiRule, lanRule, proxyRule]
        default:
            let cnDomainRule: [String: Any] = [
                "type": "field",
                "domain": ["geosite:cn"],
                "outboundTag": "direct"
            ]
            let cnIPRule: [String: Any] = [
                "type": "field",
                "ip": ["geoip:cn"],
                "outboundTag": "direct"
            ]
            return [apiRule, lanRule, cnDomainRule, cnIPRule, proxyRule]
        }
    }

    private func generatedOutbound(node: FlowNode) -> [String: Any] {
        let user: [String: Any] = [
            "id": node.uuid,
            "encryption": "none",
            "flow": node.flow ?? "xtls-rprx-vision"
        ]

        let settings: [String: Any] = [
            "vnext": [[
                "address": node.host,
                "port": node.port,
                "users": [user]
            ]]
        ]

        var streamSettings: [String: Any] = [
            "network": node.transport ?? "tcp"
        ]

        if node.security == "reality" {
            var realitySettings: [String: Any] = [
                "serverName": node.sni,
                "fingerprint": node.fingerprint
            ]
            if let publicKey = node.publicKey, !publicKey.isEmpty { realitySettings["publicKey"] = publicKey }
            if let shortId = node.shortId, !shortId.isEmpty { realitySettings["shortId"] = shortId }
            if let spiderX = node.spiderX, !spiderX.isEmpty { realitySettings["spiderX"] = spiderX }

            streamSettings["security"] = "reality"
            streamSettings["realitySettings"] = realitySettings
        } else if node.security == "tls" {
            streamSettings["security"] = "tls"
            streamSettings["tlsSettings"] = ["serverName": node.sni]
        }

        return [
            "tag": "proxy",
            "protocol": node.protocolType,
            "settings": settings,
            "streamSettings": streamSettings
        ]
    }
}

enum LocalNodeImportError: LocalizedError {
    case invalidLink
    case unsupportedEncryption
    case unsupportedTransport(String)
    case unsupportedSecurity(String)
    case missingRealityParameters

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "这不是完整的 VLESS 链接。"
        case .unsupportedEncryption:
            return "仅支持 encryption=none 的 VLESS 链接。"
        case .unsupportedTransport(let transport):
            return "当前仅支持 TCP 传输，收到：\(transport)。"
        case .unsupportedSecurity(let security):
            return "当前仅支持 Reality 安全协议，收到：\(security)。"
        case .missingRealityParameters:
            return "Reality 链接缺少 SNI 或公钥参数。"
        }
    }
}

struct FlowNodeEnvelope: Codable {
    var version: Int?
    var updatedAt: String?
    var nodes: [FlowNode]
}

// FlowNode model — kept minimal
struct FlowNode: Identifiable, Codable {
    var id = UUID()
    var flag: String
    var name: String
    var host: String
    var port: Int
    var protocolType: String
    var uuid: String
    var flow: String?
    var sni: String
    var fingerprint: String
    var publicKey: String?
    var shortId: String?
    var spiderX: String?
    var transport: String?
    var security: String?
    var source: String?
    var rawLink: String?
    var rawOutbound: JSONValue?
    var latency: Int?
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case flag, name, host, port, protocolType, uuid, flow, sni, fingerprint, publicKey, shortId, spiderX, transport, security, source, rawLink, rawOutbound, latency, isActive
    }

    var protocolDisplay: String {
        switch protocolType.lowercased() {
        case "vless": return "VLESS"
        case "vmess": return "VMess"
        case "hysteria", "hysteria2": return "Hysteria2"
        case "trojan": return "Trojan"
        case "shadowsocks": return "SS"
        default: return protocolType.uppercased()
        }
    }

    var transportDisplay: String {
        let value = (transport ?? "").lowercased()
        switch value {
        case "grpc": return "gRPC"
        case "hysteria": return "UDP"
        case "tcp": return "TCP"
        case "ws": return "WS"
        case "": return security?.uppercased() ?? "AUTO"
        default: return value.uppercased()
        }
    }


    var latencyDisplay: String {
        guard let latency else { return "—" }
        if latency >= 500 {
            return String(format: "%.1fs", Double(latency) / 1000.0)
        }
        return "\(latency)ms"
    }

}

enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var any: Any {
        switch self {
        case .string(let value): return value
        case .int(let value): return value
        case .number(let value): return value
        case .bool(let value): return value
        case .object(let value): return value.mapValues { $0.any }
        case .array(let value): return value.map { $0.any }
        case .null: return NSNull()
        }
    }
}
