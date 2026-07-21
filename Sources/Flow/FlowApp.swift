import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var openMainWindow: (() -> Void)?
    weak var appState: AppState?

    private var statusItem: NSStatusItem?
    private let statusMenu = NSMenu()

    private func flowWindows() -> [NSWindow] {
        NSApplication.shared.windows.filter { window in
            window.title == "Flow" || window.identifier?.rawValue == "main"
        }
    }

    private func removeDuplicateWindows() {
        let windows = flowWindows()
        guard windows.count > 1 else { return }
        let keeper = windows.last!
        for window in windows where window != keeper {
            window.orderOut(nil)
            window.close()
        }
    }

    func configure(state: AppState, openMainWindow: @escaping () -> Void) {
        self.appState = state
        self.openMainWindow = openMainWindow
        setupStatusItemIfNeeded()
        refreshStatusIcon()
    }

    func bringMainWindowToFront() {
        if flowWindows().isEmpty {
            openMainWindow?()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            self.removeDuplicateWindows()
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
            self.flowWindows().forEach { window in
                window.setFrameAutosaveName("")
                window.makeKeyAndOrderFront(nil)
                if window.frame.origin.x < 0 || window.frame.origin.y < 0 {
                    window.center()
                }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        NSApplication.shared.setActivationPolicy(.regular)
        setupStatusItemIfNeeded()
        for delay in [0.15, 0.6, 1.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.bringMainWindowToFront()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        bringMainWindowToFront()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.cleanupSystemProxy()
    }

    private func setupStatusItemIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Flow"
        item.menu = statusMenu
        statusMenu.delegate = self
        statusItem = item
        refreshStatusIcon()
    }

    private func refreshStatusIcon() {
        guard let button = statusItem?.button else { return }
        button.image = makeFlowStatusImage(isConnected: appState?.isConnected == true)
    }

    private func makeFlowStatusImage(isConnected: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let color = NSColor.labelColor
        color.setFill()
        color.setStroke()

        let path = NSBezierPath()
        // Minimal Flow rocket mark. Template image, macOS will adapt to dark/light menu bar.
        path.move(to: NSPoint(x: 9.0, y: 16.2))
        path.curve(to: NSPoint(x: 12.0, y: 11.3), controlPoint1: NSPoint(x: 10.9, y: 15.0), controlPoint2: NSPoint(x: 12.0, y: 13.2))
        path.line(to: NSPoint(x: 12.0, y: 6.5))
        path.curve(to: NSPoint(x: 9.0, y: 3.6), controlPoint1: NSPoint(x: 12.0, y: 4.7), controlPoint2: NSPoint(x: 10.6, y: 3.6))
        path.curve(to: NSPoint(x: 6.0, y: 6.5), controlPoint1: NSPoint(x: 7.4, y: 3.6), controlPoint2: NSPoint(x: 6.0, y: 4.7))
        path.line(to: NSPoint(x: 6.0, y: 11.3))
        path.curve(to: NSPoint(x: 9.0, y: 16.2), controlPoint1: NSPoint(x: 6.0, y: 13.2), controlPoint2: NSPoint(x: 7.1, y: 15.0))
        path.close()
        path.fill()

        // fins
        NSBezierPath(points: [NSPoint(x: 6.0, y: 7.0), NSPoint(x: 2.8, y: 4.1), NSPoint(x: 6.0, y: 4.6)]).fill()
        NSBezierPath(points: [NSPoint(x: 12.0, y: 7.0), NSPoint(x: 15.2, y: 4.1), NSPoint(x: 12.0, y: 4.6)]).fill()

        // flame / active dot
        let flame = NSBezierPath()
        flame.move(to: NSPoint(x: 7.3, y: 3.4))
        flame.line(to: NSPoint(x: 9.0, y: 0.4))
        flame.line(to: NSPoint(x: 10.7, y: 3.4))
        flame.close()
        flame.fill()

        // window punch represented as stroke circle in template style
        NSColor.clear.setFill()
        let window = NSBezierPath(ovalIn: NSRect(x: 7.6, y: 9.8, width: 2.8, height: 2.8))
        window.fill()

        if isConnected {
            let ring = NSBezierPath(ovalIn: NSRect(x: 13.0, y: 12.2, width: 4.4, height: 4.4))
            ring.lineWidth = 1.5
            ring.stroke()
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildStatusMenu()
        refreshStatusIcon()
    }

    private func rebuildStatusMenu() {
        statusMenu.removeAllItems()
        guard let state = appState else {
            statusMenu.addItem(withTitle: "Flow 正在启动…", action: nil, keyEquivalent: "")
            statusMenu.addItem(NSMenuItem.separator())
            statusMenu.addItem(withTitle: "显示主界面", action: #selector(showMainWindowFromMenu), keyEquivalent: "")
            statusMenu.addItem(withTitle: "退出 Flow", action: #selector(quitFromMenu), keyEquivalent: "q")
            return
        }

        if state.isConnected, let node = state.activeNode {
            statusMenu.addItem(withTitle: "已连接 · \(node.name)", action: nil, keyEquivalent: "")
            statusMenu.addItem(withTitle: "\(node.flag) \(node.host) · \(node.latencyDisplay)", action: nil, keyEquivalent: "")
            statusMenu.addItem(withTitle: "⬇ \(state.downloadSpeed) · ⬆ \(state.uploadSpeed)", action: nil, keyEquivalent: "")
        } else {
            statusMenu.addItem(withTitle: "未连接", action: nil, keyEquivalent: "")
            statusMenu.addItem(withTitle: "本地端口：\(state.socksPort) / \(state.httpPort)", action: nil, keyEquivalent: "")
        }

        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(withTitle: "显示主界面", action: #selector(showMainWindowFromMenu), keyEquivalent: "")
        statusMenu.addItem(withTitle: state.isConnected ? "断开连接" : "连接", action: #selector(toggleConnectionFromMenu), keyEquivalent: "")
        statusMenu.addItem(NSMenuItem.separator())

        let systemProxyItem = NSMenuItem(title: "系统代理", action: #selector(toggleSystemProxyFromMenu), keyEquivalent: "")
        systemProxyItem.state = state.systemProxyEnabled ? .on : .off
        statusMenu.addItem(systemProxyItem)

        let routingItem = NSMenuItem(title: "分流策略 · \(state.routingModeTitle)", action: nil, keyEquivalent: "")
        let routingMenu = NSMenu()
        addRoutingItem(title: "不代理", mode: "direct", current: state.routingMode, to: routingMenu)
        addRoutingItem(title: "绕过大陆", mode: "bypassCN", current: state.routingMode, to: routingMenu)
        addRoutingItem(title: "绕过局域网", mode: "lanOnly", current: state.routingMode, to: routingMenu)
        addRoutingItem(title: "全局代理", mode: "global", current: state.routingMode, to: routingMenu)
        routingItem.submenu = routingMenu
        statusMenu.addItem(routingItem)

        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(withTitle: "退出 Flow", action: #selector(quitFromMenu), keyEquivalent: "q")
    }

    private func addRoutingItem(title: String, mode: String, current: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: #selector(selectRoutingFromMenu(_:)), keyEquivalent: "")
        item.representedObject = mode
        item.state = current == mode ? .on : .off
        menu.addItem(item)
    }

    @objc private func showMainWindowFromMenu() {
        bringMainWindowToFront()
    }

    @objc private func toggleConnectionFromMenu() {
        appState?.toggleConnection()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.refreshStatusIcon() }
    }

    @objc private func toggleSystemProxyFromMenu() {
        guard let state = appState else { return }
        state.setSystemProxyEnabled(!state.systemProxyEnabled)
        refreshStatusIcon()
    }

    @objc private func selectRoutingFromMenu(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        appState?.setRoutingMode(mode)
    }

    @objc private func quitFromMenu() {
        appState?.shutdown()
        NSApplication.shared.terminate(nil)
    }
}

private extension NSBezierPath {
    convenience init(points: [NSPoint]) {
        self.init()
        guard let first = points.first else { return }
        move(to: first)
        for point in points.dropFirst() { line(to: point) }
        close()
    }
}

@main
struct FlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("Flow", id: "main") {
            ContentView()
                .environmentObject(state)
                .frame(width: 380, height: 700)
                .fixedSize()
                .onAppear {
                    appDelegate.configure(state: state) {
                        openWindow(id: "main")
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        appDelegate.bringMainWindowToFront()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 380, height: 700)
    }
}
