import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var showSettings = false
    @State private var showNodePicker = false
    @State private var isPressing = false
    @State private var pulsePhase: Double = 0
    @State private var rocketLift = false
    @State private var flamePulse = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 12) {
                topBar

                Spacer(minLength: 0)

                speedLaunchButton

                nodeSummary

                selectedNodeButton
                    .padding(.horizontal, 26)

                proxyModeBanner
                    .padding(.horizontal, 26)

                HStack(spacing: 8) {
                    StatusPill(title: "状态", value: state.connectionStatus, isOn: state.isConnected)
                    StatusPill(title: "时长", value: state.connectedDuration, isOn: state.isConnected)
                }
                .padding(.horizontal, 26)

                HStack(spacing: 8) {
                    StatBox(title: "本次", value: state.sessionTraffic, note: "连接后统计")
                    StatBox(title: "今日", value: state.todayTraffic, note: "今天已用")
                    StatBox(title: "累计", value: state.totalTraffic, note: "设备累计")
                }
                .padding(.horizontal, 26)


                Spacer(minLength: 0)

                gearButton
                    .padding(.bottom, 12)
            }
            .padding(.top, 8)

            if showNodePicker {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { showNodePicker = false } }

                nodePickerPanel
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showSettings {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { showSettings = false } }

                settingsPanel
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            startAnimationsIfNeeded()
        }
        .onChange(of: state.isConnected) { _, _ in
            startAnimationsIfNeeded()
        }
    }

    private var topBar: some View {
        HStack {
            Text("Flow")
                .font(.system(size: 19, weight: .heavy, design: .rounded).italic())
                .tracking(3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "F2F7FF"), Color(hex: "45D6FF"), Color(hex: "F3B85B")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color(hex: "45D6FF").opacity(0.16), radius: 16)

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(state.isConnected ? Color(hex: "34C759") : Color(hex: "71859B"))
                    .frame(width: 7, height: 7)
                    .shadow(color: state.isConnected ? Color(hex: "34C759").opacity(0.7) : .clear, radius: 8)
                Text(state.proxyStatusTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "B8C8D8"))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .glassCapsule()
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
    }

    private var speedLaunchButton: some View {
        ZStack {
            if state.isConnected {
                Circle()
                    .stroke(Color(hex: "45D6FF").opacity(0.23), lineWidth: 3)
                    .frame(width: 196, height: 196)
                    .scaleEffect(1 + pulsePhase * 0.08)
                    .opacity(0.82 - pulsePhase * 0.4)
                    .shadow(color: Color(hex: "45D6FF").opacity(0.12), radius: 26)
            }

            if state.isConnected {
                RocketLaunchView(lift: rocketLift, flamePulse: flamePulse)
                    .offset(y: -84)
                    .zIndex(4)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isPressing = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.15)) { isPressing = false }
                    state.toggleConnection()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: state.isConnected
                                    ? [Color.white.opacity(0.16), Color(hex: "0D3146"), Color(hex: "071520")]
                                    : [Color(hex: "25242A"), Color(hex: "151519")],
                                center: .topLeading,
                                startRadius: 8,
                                endRadius: 145
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(state.isConnected ? Color(hex: "45D6FF") : Color(hex: "F3B85B").opacity(0.55), lineWidth: state.isConnected ? 6 : 3)
                        )
                        .shadow(color: state.isConnected ? Color(hex: "45D6FF").opacity(0.32) : .clear, radius: 34)
                        .shadow(color: Color.black.opacity(0.38), radius: 24, y: 16)

                    VStack(spacing: 7) {
                        if state.isConnected {
                            Text(speedParts.number)
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .tracking(-2)
                                .foregroundColor(Color(hex: "45D6FF"))
                                .shadow(color: Color(hex: "45D6FF").opacity(0.24), radius: 18)
                            Text(speedParts.unit)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "9DEAFF"))
                        } else {
                            Text("连")
                                .font(.system(size: 48, weight: .heavy, design: .serif))
                                .foregroundColor(Color(hex: "F3B85B"))
                        }
                    }
                }
                .frame(width: 148, height: 148)
                .scaleEffect(isPressing ? 0.96 : 1)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 210, height: 198)
    }

    private var nodeSummary: some View {
        VStack(spacing: 6) {
            if let node = state.isConnected ? state.activeNode : selectedNode {
                Text("\(node.flag) \(node.name)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "F2F7FF"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                Text("\(node.host) · \(node.protocolDisplay) · \(node.transportDisplay) · 局域网共享")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "71859B"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("Flow 已就绪")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "F2F7FF"))
                Text("点一下圆按钮，自动开启系统代理")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "71859B"))
            }
        }
        .padding(.horizontal, 28)
    }


    private var proxyModeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: state.proxyModeIcon)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(state.systemProxyEnabled ? Color(hex: "45D6FF") : Color(hex: "F3B85B"))
                .frame(width: 24, height: 24)
                .background((state.systemProxyEnabled ? Color(hex: "45D6FF") : Color(hex: "F3B85B")).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(state.proxyModeHeadline)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Color(hex: "F2F7FF"))
                Text(state.proxyModeDetail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "71859B"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            Text(state.routingModeTitle)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(Color(hex: "B8C8D8"))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.055))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(LinearGradient(colors: [Color.white.opacity(0.065), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke((state.systemProxyEnabled ? Color(hex: "45D6FF") : Color(hex: "F3B85B")).opacity(0.18), lineWidth: 1))
    }

    private var gearButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { showSettings.toggle() }
        } label: {
            Image(systemName: showSettings ? "gearshape.fill" : "gearshape")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "B8C8D8"))
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [Color.white.opacity(0.09), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var settingsPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("节点管理")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(Color(hex: "F2F7FF"))
                        Text(state.nodeUpdateMessage)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(state.nodeUpdateMessage.contains("失败") ? Color(hex: "FF6B5F") : Color(hex: "71859B"))
                    }
                    Spacer()
                    Button {
                        Task { await state.loadNodes() }
                    } label: {
                        if state.isUpdatingNodes {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("更新")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(Color(hex: "F3B85B"))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isUpdatingNodes)
                }

                NodeUpdateProgressView(
                    isUpdating: state.isUpdatingNodes,
                    current: state.nodeCheckCurrent,
                    total: state.nodeCheckTotal,
                    usable: state.nodeUsableCount
                )

                HStack(spacing: 10) {
                    PortBox(title: "SOCKS5", value: $state.socksPort)
                    PortBox(title: "HTTP", value: $state.httpPort)
                }

                SystemProxyRow(isOn: state.systemProxyEnabled) { enabled in
                    state.setSystemProxyEnabled(enabled)
                }

                RoutingModePicker(selected: state.routingMode) { mode in
                    state.setRoutingMode(mode)
                }

                VStack(spacing: 4) {
                    Text(state.localProxyAddressTitle)
                    Text(state.systemProxyEnabled ? "系统代理已开启，Mac 网络会自动经过 Flow" : "仅本地端口模式，其他软件可手动填端口")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "71859B"))
            }
            .padding(17)
        }
        .frame(maxHeight: 520)
        .background(Color(hex: "18202B").opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 40, y: 18)
    }

    private var selectedNodeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { showNodePicker = true }
        } label: {
            HStack(spacing: 10) {
                if let node = selectedNode {
                    Text(node.flag)
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(node.name)
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(Color(hex: "F2F7FF"))
                                .lineLimit(1)
                            if state.isConnected {
                                Circle().fill(Color(hex: "34C759")).frame(width: 6, height: 6)
                            }
                        }
                        Text("\(node.protocolDisplay) · \(node.transportDisplay) · \(node.host):\(node.port)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "71859B"))
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(node.latency.map { _ in node.latencyDisplay } ?? (state.isTestingLatency ? "检测中" : "—"))
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(latencyColor(node.latency))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "71859B"))
                    }
                } else {
                    Text("选择节点")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Color(hex: "F2F7FF"))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(Color(hex: "71859B"))
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var nodePickerPanel: some View {
        VStack(spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("选择节点")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Color(hex: "F2F7FF"))
                    Text(state.nodeUpdateMessage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(state.nodeUpdateMessage.contains("失败") ? Color(hex: "FF6B5F") : Color(hex: "71859B"))
                }
                Spacer()
                Button {
                    Task { await state.loadNodes() }
                } label: {
                    if state.isUpdatingNodes {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 30, height: 30)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "F3B85B"))
                            .frame(width: 30, height: 30)
                    }
                }
                .buttonStyle(.plain)
                .disabled(state.isUpdatingNodes)
            }

            if let nodes = state.nodes, !nodes.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(nodes.indices, id: \.self) { i in
                            NodeRow(
                                node: nodes[i],
                                isSelected: i == state.selectedIndex,
                                isConnected: state.isConnected && i == state.selectedIndex
                            ) {
                                state.selectNode(i)
                                withAnimation(.easeInOut(duration: 0.18)) { showNodePicker = false }
                            }
                        }
                    }
                }
                .frame(maxHeight: 390)
            } else {
                VStack(spacing: 8) {
                    if state.isUpdatingNodes {
                        ProgressView().controlSize(.small)
                    }
                    Text(state.isUpdatingNodes ? "正在真实检测节点" : "暂无可用节点")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Color(hex: "F2F7FF"))
                    Text(state.nodeUpdateMessage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(state.nodeUpdateMessage.contains("失败") ? Color(hex: "FF6B5F") : Color(hex: "71859B"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(hex: "151B24"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "2B3A4B"), lineWidth: 1))
            }
        }
        .padding(17)
        .background(Color(hex: "18202B").opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.48), radius: 42, y: 18)
    }

    private func latencyColor(_ latency: Int?) -> Color {
        guard let latency else { return Color(hex: "71859B") }
        if latency < 2000 { return Color(hex: "34C759") }
        return Color(hex: "F3B85B")
    }

    private var selectedNode: FlowNode? {
        guard let nodes = state.nodes, state.selectedIndex < nodes.count else { return nil }
        return nodes[state.selectedIndex]
    }

    private var speedParts: (number: String, unit: String) {
        let speed = state.downloadSpeed
        if speed == "—" { return ("—", "") }
        if speed.contains("MB/s") { return (speed.replacingOccurrences(of: " MB/s", with: ""), "MB/s") }
        if speed.contains("KB/s") { return (speed.replacingOccurrences(of: " KB/s", with: ""), "KB/s") }
        return (speed, "")
    }

    private func startAnimationsIfNeeded() {
        if state.isConnected {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulsePhase = 1 }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { rocketLift = true }
            withAnimation(.easeInOut(duration: 0.24).repeatForever(autoreverses: true)) { flamePulse = true }
        } else {
            withAnimation(.default) { pulsePhase = 0; rocketLift = false; flamePulse = false }
        }
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "151B24"), Color(hex: "10141B"), Color(hex: "090B10")], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(hex: "45D6FF").opacity(0.14), .clear], center: .top, startRadius: 10, endRadius: 260)
            RadialGradient(colors: [Color(hex: "F3B85B").opacity(0.10), .clear], center: .topLeading, startRadius: 20, endRadius: 240)
        }
        .ignoresSafeArea()
    }
}

private struct RocketLaunchView: View {
    let lift: Bool
    let flamePulse: Bool

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: "45D6FF").opacity(0.14))
                .frame(width: 52, height: 92)
                .blur(radius: 8)
                .offset(y: 50)
                .scaleEffect(y: flamePulse ? 1.16 : 0.86)

            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color(hex: "FFF7DA"), Color(hex: "F8D47A"), Color(hex: "D88A32")], startPoint: .top, endPoint: .bottom))
                        .frame(width: 22, height: 38)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.65), lineWidth: 1))
                        .shadow(color: Color(hex: "F8D47A").opacity(0.55), radius: 14)

                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: "DDF8FF"), Color(hex: "052433")], center: .topLeading, startRadius: 1, endRadius: 8))
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1))
                        .offset(y: -7)

                    HStack(spacing: 18) {
                        RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [Color(hex: "FFE18A"), Color(hex: "F09A3B")], startPoint: .top, endPoint: .bottom)).frame(width: 10, height: 15).rotationEffect(.degrees(-25))
                        RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [Color(hex: "FFE18A"), Color(hex: "F09A3B")], startPoint: .top, endPoint: .bottom)).frame(width: 10, height: 15).rotationEffect(.degrees(25))
                    }
                    .offset(y: 16)
                }

                Capsule()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.95), Color(hex: "FFE18A"), Color(hex: "FF7A35"), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: flamePulse ? 16 : 12, height: flamePulse ? 34 : 24)
                    .blur(radius: 0.3)
                    .shadow(color: Color(hex: "FF7A35").opacity(0.75), radius: 12)
                    .offset(y: -1)
            }
            .offset(y: lift ? -8 : 4)
        }
        .frame(width: 70, height: 120)
    }
}



private struct NodeUpdateProgressView: View {
    let isUpdating: Bool
    let current: Int
    let total: Int
    let usable: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(isUpdating ? "真实检测中" : "节点状态")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Color(hex: "F2F7FF"))
                Spacer()
                Text(total > 0 ? "\(min(current, total))/\(total) · 可用 \(usable)" : "等待更新")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isUpdating ? Color(hex: "F3B85B") : Color(hex: "71859B"))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "45D6FF"), Color(hex: "F3B85B")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: progressWidth(totalWidth: proxy.size.width))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "151B24"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "2B3A4B"), lineWidth: 1))
    }

    private func progressWidth(totalWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        return totalWidth * CGFloat(min(current, total)) / CGFloat(total)
    }
}

private struct SystemProxyRow: View {
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("系统代理")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(hex: "F2F7FF"))
                Text(isOn ? "会自动接管 Mac 网络代理" : "默认关闭，只提供本地代理端口")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "71859B"))
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: { onChange($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "151B24"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "2B3A4B"), lineWidth: 1))
    }
}

private struct RoutingModePicker: View {
    let selected: String
    let onSelect: (String) -> Void

    private let items: [(String, String)] = [
        ("direct", "不代理"),
        ("bypassCN", "绕过大陆"),
        ("lanOnly", "绕过局域网"),
        ("global", "全局")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("分流策略")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(hex: "F2F7FF"))
                Spacer()
                Text(title(for: selected))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "F3B85B"))
            }

            HStack(spacing: 6) {
                ForEach(items, id: \.0) { item in
                    Button { onSelect(item.0) } label: {
                        Text(item.1)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(selected == item.0 ? Color(hex: "071520") : Color(hex: "B8C8D8"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selected == item.0 ? Color(hex: "F3B85B") : Color.white.opacity(0.05))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "151B24"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "2B3A4B"), lineWidth: 1))
    }

    private func title(for key: String) -> String {
        items.first(where: { $0.0 == key })?.1 ?? "绕过大陆"
    }
}

private struct PortBox: View {
    let title: String
    @Binding var value: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "71859B"))
            Spacer()
            TextField("", text: $value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "F2F7FF"))
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                .frame(width: 58)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "151B24"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "2B3A4B"), lineWidth: 1))
    }
}

private struct NodeRow: View {
    let node: FlowNode
    let isSelected: Bool
    let isConnected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(node.flag)
                    .font(.system(size: 22))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(node.name)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(Color(hex: "F2F7FF"))
                            .lineLimit(1)
                        if isConnected {
                            Circle().fill(Color(hex: "34C759")).frame(width: 6, height: 6)
                        }
                    }
                    Text("\(node.protocolDisplay) · \(node.transportDisplay) · \(node.host):\(node.port)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "71859B"))
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(node.latencyDisplay)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(node.latency.map { $0 < 2000 ? Color(hex: "34C759") : Color(hex: "F3B85B") } ?? Color(hex: "71859B"))
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "F3B85B"))
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(isSelected ? Color(hex: "242321") : Color(hex: "151B24"))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(isSelected ? Color(hex: "F3B85B").opacity(0.48) : Color(hex: "2B3A4B"), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct StatusPill: View {
    let title: String
    let value: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(isOn ? Color(hex: "34C759") : Color(hex: "71859B")).frame(width: 7, height: 7).shadow(color: isOn ? Color(hex: "34C759").opacity(0.65) : .clear, radius: 10)
            Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "71859B"))
            Text(value).font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundColor(isOn ? Color(hex: "CDEFD4") : Color(hex: "B8C8D8"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(LinearGradient(colors: [Color.white.opacity(0.055), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct StatBox: View {
    let title: String
    let value: String
    let note: String

    var body: some View {
        VStack(spacing: 5) {
            Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(Color(hex: "71859B"))
            Text(value).font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundColor(Color(hex: "F3B85B")).lineLimit(1).minimumScaleFactor(0.7)
            Text(note).font(.system(size: 8, weight: .medium)).foregroundColor(Color(hex: "4E5965")).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(LinearGradient(colors: [Color.white.opacity(0.055), Color.white.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private extension View {
    func glassCapsule() -> some View {
        self.background(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.14), radius: 16, y: 6)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
