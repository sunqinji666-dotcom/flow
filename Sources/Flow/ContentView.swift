import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @State private var showLibrary = false
    @State private var showSettings = false
    @State private var isPressed = false

    var body: some View {
        ZStack {
            FlowAmbientBackground()
            VStack(spacing: 0) {
                header
                Spacer(minLength: 20)
                connectionControl
                Spacer(minLength: 22)
                nodeCard.padding(.horizontal, 24)
                statusStrip.padding(.horizontal, 24).padding(.top, 12)
                trafficStrip.padding(.horizontal, 24).padding(.top, 10)
                Spacer(minLength: 18)
                bottomBar.padding(.horizontal, 24).padding(.bottom, 22)
            }
            .padding(.top, 20)
        }
        .sheet(isPresented: $showLibrary) {
            NodeLibrarySheet().environmentObject(state)
        }
        .sheet(isPresented: $showSettings) {
            LocalSettingsSheet().environmentObject(state)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.thinMaterial).frame(width: 42, height: 42)
                    .overlay(Circle().stroke(.white.opacity(0.52), lineWidth: 0.8))
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(state.isConnected ? Color.cyan : Color.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Flow").font(.system(size: 24, weight: .bold, design: .rounded))
                Text("本机节点库 · 不读取服务器")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(state.isConnected ? Color.green : Color.secondary.opacity(0.6))
                    .frame(width: 7, height: 7)
                Text(state.isConnected ? "已连接" : "待连接").font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 11).padding(.vertical, 8).glassCapsule()
        }
        .padding(.horizontal, 24)
    }

    private var connectionControl: some View {
        Button {
            withAnimation(.smooth(duration: 0.18)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.smooth(duration: 0.25)) { isPressed = false }
                state.toggleConnection()
            }
        } label: {
            ZStack {
                if state.isConnected {
                    Circle().stroke(Color.cyan.opacity(0.26), lineWidth: 1.5).frame(width: 190, height: 190)
                    Circle().stroke(Color.cyan.opacity(0.11), lineWidth: 10).frame(width: 215, height: 215)
                }
                Circle().fill(.regularMaterial).frame(width: 156, height: 156)
                    .overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 1))
                    .shadow(color: state.isConnected ? .cyan.opacity(0.22) : .black.opacity(0.16), radius: 22, y: 10)
                VStack(spacing: 8) {
                    Image(systemName: state.isConnected ? "power" : "bolt.fill")
                        .font(.system(size: 31, weight: .medium))
                    Text(state.isConnected ? "断开连接" : "立即连接").font(.headline.weight(.semibold))
                    Text(state.isConnected ? state.downloadSpeed : "使用所选节点")
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                .foregroundStyle(state.isConnected ? Color.cyan : Color.primary)
            }
            .scaleEffect(isPressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
    }

    private var nodeCard: some View {
        Button { showLibrary = true } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle().fill(.ultraThinMaterial).frame(width: 43, height: 43)
                    Text(selectedNode?.flag ?? "＋").font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedNode?.name ?? "导入一个节点").font(.headline.weight(.semibold)).lineLimit(1)
                    Text(selectedNode.map(nodeDescription) ?? "仅保存于此 Mac")
                        .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(selectedNode?.latencyDisplay ?? "本机")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(latencyColor(selectedNode?.latency))
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
            }
            .padding(14).glassCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            MiniMetric(icon: "circle.fill", title: "状态", value: state.connectionStatus, tint: state.isConnected ? .green : .secondary)
            MiniMetric(icon: "timer", title: "时长", value: state.connectedDuration, tint: .secondary)
        }
    }

    private var trafficStrip: some View {
        HStack(spacing: 10) {
            TrafficMetric(title: "本次", value: state.sessionTraffic)
            TrafficMetric(title: "今日", value: state.todayTraffic)
            TrafficMetric(title: "累计", value: state.totalTraffic)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button { showLibrary = true } label: {
                Label("节点库", systemImage: "point.3.connected.trianglepath.dotted")
            }.buttonStyle(FlowGlassButtonStyle())
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3").frame(width: 18)
            }.buttonStyle(FlowGlassButtonStyle())
            Spacer()
            Text(state.systemProxyEnabled ? "系统代理" : "本地端口")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.vertical, 9).glassCapsule()
        }
    }

    private var selectedNode: FlowNode? {
        guard let nodes = state.nodes, nodes.indices.contains(state.selectedIndex) else { return nil }
        return nodes[state.selectedIndex]
    }

    private func nodeDescription(_ node: FlowNode) -> String {
        "\(node.protocolDisplay) · \(node.transportDisplay) · \(node.host):\(node.port)"
    }

    private func latencyColor(_ latency: Int?) -> Color {
        guard let latency else { return .secondary }
        return latency < 800 ? .green : latency < 1600 ? .orange : .red
    }
}

private struct NodeLibrarySheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showImport = false
    @State private var nodeToDelete: Int?
    @State private var exportMessage: String?

    var body: some View {
        ZStack {
            FlowAmbientBackground()
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("本机节点库").font(.title2.weight(.bold))
                        Text("仅保存于这台 Mac；不会拉取或上传服务器配置。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark").font(.body.weight(.bold)).frame(width: 34, height: 34)
                    }.buttonStyle(FlowGlassButtonStyle())
                }

                if let nodes = state.nodes, !nodes.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 9) {
                            ForEach(nodes.indices, id: \.self) { index in
                                LocalNodeRow(node: nodes[index], isSelected: index == state.selectedIndex,
                                             isConnected: state.isConnected && index == state.selectedIndex,
                                             select: { state.selectNode(index); dismiss() },
                                             delete: { nodeToDelete = index })
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("还没有节点", systemImage: "point.3.connected.trianglepath.dotted",
                                           description: Text("导入 VLESS Reality TCP 链接后，会加密保存在这台 Mac。"))
                        .frame(maxHeight: .infinity)
                }

                HStack {
                    Button { state.testAllLatencies() } label: {
                        Label("测试延迟", systemImage: "waveform.path.ecg")
                    }.buttonStyle(FlowGlassButtonStyle()).disabled((state.nodes ?? []).isEmpty)
                    Spacer()
                    Button { exportNodes() } label: {
                        Label("导出节点", systemImage: "square.and.arrow.up")
                    }.buttonStyle(FlowGlassButtonStyle()).disabled((state.nodes ?? []).isEmpty)
                    Button { showImport = true } label: {
                        Label("导入链接", systemImage: "plus")
                    }.buttonStyle(FlowAccentButtonStyle())
                }
            }
            .padding(22)
        }
        .frame(minWidth: 500, minHeight: 520)
        .sheet(isPresented: $showImport) { ImportLinkSheet().environmentObject(state) }
        .alert("从本机移除此节点？", isPresented: Binding(
            get: { nodeToDelete != nil }, set: { if !$0 { nodeToDelete = nil } }
        )) {
            Button("移除", role: .destructive) {
                if let index = nodeToDelete { state.deleteNode(at: index) }
                nodeToDelete = nil
            }
            Button("取消", role: .cancel) { nodeToDelete = nil }
        } message: {
            Text("这会删除这台 Mac 上保存的链接；不会影响任何服务器。")
        }
        .alert("导出节点", isPresented: Binding(
            get: { exportMessage != nil }, set: { if !$0 { exportMessage = nil } }
        )) {
            Button("好") { exportMessage = nil }
        } message: {
            Text(exportMessage ?? "")
        }
    }

    private func exportNodes() {
        let links = state.exportableVLESSLinks()
        guard !links.isEmpty else {
            exportMessage = "当前没有可导出的 VLESS 节点。"
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let panel = NSSavePanel()
        panel.title = "导出 Flow 节点"
        panel.nameFieldStringValue = "Flow-Nodes-\(formatter.string(from: Date())).txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let content = links.joined(separator: "\n") + "\n"
            try content.write(to: url, atomically: true, encoding: .utf8)
            exportMessage = "已导出 \(links.count) 个节点到：\n\(url.path)"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }
}

private struct ImportLinkSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("导入 VLESS 链接").font(.title3.weight(.bold))
            Text("支持 VLESS + Reality + TCP。链接只保存到这台 Mac。")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $link)
                .font(.system(.body, design: .monospaced)).frame(height: 130).padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.45), lineWidth: 0.7))
            if let errorText { Text(errorText).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("取消", action: dismiss.callAsFunction).buttonStyle(FlowGlassButtonStyle())
                Spacer()
                Button("导入到本机") {
                    do {
                        _ = try state.importVLESSLink(link)
                        dismiss()
                    } catch {
                        errorText = error.localizedDescription
                    }
                }
                .buttonStyle(FlowAccentButtonStyle())
                .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22).frame(width: 480).background(FlowAmbientBackground())
    }
}

private struct LocalSettingsSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本地设置").font(.title3.weight(.bold))
                    Text("网络代理仅在你开启连接后生效。").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: dismiss.callAsFunction) { Image(systemName: "xmark") }
                    .buttonStyle(FlowGlassButtonStyle())
            }
            SettingsRow(title: "系统代理", detail: "开启后，Mac 的网络请求会经过 Flow") {
                Toggle("", isOn: Binding(get: { state.systemProxyEnabled }, set: { state.setSystemProxyEnabled($0) }))
                    .toggleStyle(.switch).labelsHidden()
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("分流策略").font(.headline)
                Picker("分流策略", selection: Binding(get: { state.routingMode }, set: { state.setRoutingMode($0) })) {
                    Text("绕过大陆").tag("bypassCN")
                    Text("全局代理").tag("global")
                    Text("绕过局域网").tag("lanOnly")
                    Text("不代理").tag("direct")
                }.pickerStyle(.segmented)
            }.padding(14).glassCard(cornerRadius: 17)
            HStack(spacing: 10) {
                PortField(title: "SOCKS5", value: $state.socksPort)
                PortField(title: "HTTP", value: $state.httpPort)
            }
            Text("本机地址：\(state.localProxyAddressTitle)")
                .font(.caption.monospaced()).foregroundStyle(.secondary).padding(.top, 2)
        }
        .padding(22).frame(width: 490).background(FlowAmbientBackground())
    }
}

private struct LocalNodeRow: View {
    let node: FlowNode
    let isSelected: Bool
    let isConnected: Bool
    let select: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: select) {
                Text(node.flag).font(.system(size: 22)).frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }.buttonStyle(.plain)
            Button(action: select) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(node.name).font(.headline.weight(.semibold))
                        if isConnected { Circle().fill(.green).frame(width: 7, height: 7) }
                    }
                    Text("\(node.protocolDisplay) · \(node.transportDisplay) · \(node.host):\(node.port)")
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            VStack(alignment: .trailing, spacing: 5) {
                Text(node.latencyDisplay).font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(isSelected ? Color.cyan : .secondary)
                Button(action: delete) {
                    Image(systemName: "trash").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        .frame(width: 27, height: 27)
                }.buttonStyle(.plain)
            }
        }
        .padding(12).glassCard(cornerRadius: 17, highlighted: isSelected)
    }
}

private struct SettingsRow<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let trailing: () -> Trailing
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            trailing()
        }.padding(14).glassCard(cornerRadius: 17)
    }
}

private struct PortField: View {
    let title: String
    @Binding var value: String
    var body: some View {
        HStack {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            TextField("", text: $value).font(.body.monospacedDigit()).multilineTextAlignment(.trailing)
                .textFieldStyle(.plain).frame(width: 72)
        }.padding(14).glassCard(cornerRadius: 17)
    }
}

private struct MiniMetric: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 8, weight: .bold)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption.weight(.semibold)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity).glassCard(cornerRadius: 15)
    }
}

private struct TrafficMetric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.72)
        }.padding(.vertical, 10).frame(maxWidth: .infinity).glassCard(cornerRadius: 15)
    }
}

private struct FlowAmbientBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Circle().fill(Color.cyan.opacity(0.22)).frame(width: 380, height: 380).blur(radius: 80).offset(x: -150, y: -260)
            Circle().fill(Color.indigo.opacity(0.20)).frame(width: 360, height: 360).blur(radius: 85).offset(x: 190, y: 260)
            LinearGradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }.ignoresSafeArea()
    }
}

private struct FlowGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.white.opacity(configuration.isPressed ? 0.75 : 0.48), lineWidth: 0.7))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct FlowAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            .padding(.horizontal, 15).padding(.vertical, 10)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.72 : 0.92), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.white.opacity(0.55), lineWidth: 0.7))
            .shadow(color: Color.accentColor.opacity(0.20), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat, highlighted: Bool = false) -> some View {
        background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(highlighted ? Color.cyan.opacity(0.72) : .white.opacity(0.52), lineWidth: highlighted ? 1.2 : 0.7))
            .shadow(color: .black.opacity(0.10), radius: 13, y: 7)
    }
    func glassCapsule() -> some View {
        background(.thinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.52), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.08), radius: 7, y: 3)
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}
