using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;

namespace Flow;

public partial class MainWindow : Window
{
    private List<FlowNode> _nodes = FlowNode.Builtin.ToList();
    private int _selectedIndex;
    private bool _isConnected;
    private bool _systemProxyEnabled;
    private string _routingMode = "bypassCN";
    private DispatcherTimer? _trafficTimer;
    private CancellationTokenSource? _updateCts;

    public MainWindow()
    {
        InitializeComponent();
        UpdateUi();
        _ = LoadNodesAsync();
    }

    private FlowNode SelectedNode => _nodes.Count > _selectedIndex ? _nodes[_selectedIndex] : _nodes[0];

    private async Task LoadNodesAsync()
    {
        _updateCts?.Cancel();
        _updateCts = new CancellationTokenSource();
        var ct = _updateCts.Token;

        var url = Environment.GetEnvironmentVariable("FLOW_REMOTE_NODES_URL") ?? "https://your-server.example/flow/nodes.json";
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
            var json = await http.GetStringAsync(url, ct);
            var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            var candidates = new List<FlowNode>();

            try
            {
                var env = System.Text.Json.JsonSerializer.Deserialize<FlowNodeEnvelope>(json, opts);
                if (env?.Nodes is { Length: > 0 }) candidates = env.Nodes.ToList();
            }
            catch { }
            if (candidates.Count == 0)
            {
                try
                {
                    var list = System.Text.Json.JsonSerializer.Deserialize<FlowNode[]>(json, opts);
                    if (list is { Length: > 0 }) candidates = list.ToList();
                }
                catch { }
            }

            if (candidates.Count > 0)
            {
                _nodes = await ValidateNodesAsync(candidates, ct);
                _selectedIndex = 0;
            }
        }
        catch (TaskCanceledException) { }
        catch (Exception) { }

        Dispatcher.Invoke(UpdateUi);
    }

    private async Task<List<FlowNode>> ValidateNodesAsync(List<FlowNode> candidates, CancellationToken ct)
    {
        var passed = new List<FlowNode>();
        var batchSize = 4;
        for (int cursor = 0; cursor < candidates.Count && !ct.IsCancellationRequested; cursor += batchSize)
        {
            var batch = candidates.Skip(cursor).Take(batchSize).ToList();
            foreach (var node in batch)
            {
                var testPort = 20080 + passed.Count;
                var testConfig = GenerateValidationConfig(node, testPort);
                var tempConfig = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"flow-test-{Guid.NewGuid()}.json");
                System.IO.File.WriteAllText(tempConfig, testConfig);

                var ok = XrayCoreManager.Start(testConfig);
                if (ok)
                {
                    await Task.Delay(1000, ct);
                    var latency = await XrayCoreManager.TestSocksProxy(testPort);
                    XrayCoreManager.Stop();
                    if (latency != null)
                    {
                        node.Latency = latency.Value;
                        passed.Add(node);
                    }
                }
                else XrayCoreManager.Stop();

                try { System.IO.File.Delete(tempConfig); } catch { }
            }
        }
        return passed;
    }

    private string GenerateValidationConfig(FlowNode node, int socksPort)
    {
        return $$"""
        {
          "log": {"loglevel": "error"},
          "inbounds": [{"tag": "socks-in", "port": {{socksPort}}, "listen": "127.0.0.1", "protocol": "socks"}],
          "outbounds": [
            {"tag": "proxy", "protocol": "{{node.ProtocolType}}", "settings": {"vnext": [{"address": "{{node.Host}}", "port": {{node.Port}}, "users": [{"id": "{{node.Uuid}}", "encryption": "none", "flow": "{{node.Flow ?? ""}}"}]}]}, "streamSettings": {"network": "{{node.Transport ?? "tcp"}}", "security": "{{node.Security ?? "reality"}}", "realitySettings": {"serverName": "{{node.Sni}}", "fingerprint": "{{node.Fingerprint}}", "publicKey": "{{node.PublicKey ?? ""}}", "shortId": "{{node.ShortId ?? ""}}"}}},
            {"tag": "direct", "protocol": "freedom"}
          ],
          "routing": {"domainStrategy": "AsIs", "rules": [{"type": "field", "inboundTag": ["socks-in"], "outboundTag": "proxy"}]}
        }
        """;
    }

    private void ConnectBtn_Click(object sender, RoutedEventArgs e)
    {
        if (_isConnected) Disconnect();
        else Connect();
    }

    private void Connect()
    {
        var node = SelectedNode;
        var config = GenerateXrayConfig(node);
        var ok = XrayCoreManager.Start(config);
        if (!ok)
        {
            StatusLabel.Text = "核心启动失败";
            return;
        }

        _isConnected = true;
        StatusLabel.Text = _systemProxyEnabled ? "系统代理模式" : "本地端口模式";
        StatusDot.Fill = new SolidColorBrush((Color)FindResource("GreenOn"));

        _trafficTimer = new DispatcherTimer(TimeSpan.FromSeconds(2), DispatcherPriority.Normal, (_, _) => UpdateTraffic(), Dispatcher);
        _trafficTimer.Start();
        UpdateUi();
    }

    private void Disconnect()
    {
        XrayCoreManager.Stop();
        _isConnected = false;
        _trafficTimer?.Stop();
        _trafficTimer = null;
        ConnectBtnLabel.Text = "连";
        ConnectBtnLabel.Foreground = new SolidColorBrush((Color)FindResource("AccentGold"));
        StatusLabel.Text = "已断开";
        StatusDot.Fill = new SolidColorBrush((Color)FindResource("TextSecondary"));
        UpdateUi();
    }

    private string GenerateXrayConfig(FlowNode node)
    {
        var socks = XrayCoreManager.FindAvailablePort(10606);
        var http = XrayCoreManager.FindAvailablePort(socks + 1);
        return $$"""
        {
          "log": {"loglevel": "warning"},
          "inbounds": [
            {"tag": "socks-in", "port": {{socks}}, "listen": "0.0.0.0", "protocol": "socks", "settings": {"udp": true}},
            {"tag": "http-in", "port": {{http}}, "listen": "0.0.0.0", "protocol": "http"}
          ],
          "outbounds": [
            {"tag": "proxy", "protocol": "{{node.ProtocolType}}", "settings": {"vnext": [{"address": "{{node.Host}}", "port": {{node.Port}}, "users": [{"id": "{{node.Uuid}}", "encryption": "none", "flow": "{{node.Flow ?? ""}}"}]}]}, "streamSettings": {"network": "{{node.Transport ?? "tcp"}}", "security": "{{node.Security ?? "reality"}}", "realitySettings": {"serverName": "{{node.Sni}}", "fingerprint": "{{node.Fingerprint}}", "publicKey": "{{node.PublicKey ?? ""}}", "shortId": "{{node.ShortId ?? ""}}"}}},
            {"tag": "direct", "protocol": "freedom"}
          ],
          "routing": {"domainStrategy": "IPIfNonMatch", "rules": [{"type": "field", "inboundTag": ["socks-in", "http-in"], "outboundTag": "proxy"}]}
        }
        """;
    }

    private void NodePicker_Click(object sender, RoutedEventArgs e)
    {
        var picker = new NodePickerWindow(_nodes, _selectedIndex, index =>
        {
            _selectedIndex = index;
            UpdateUi();
            if (_isConnected) { Disconnect(); Connect(); }
        });
        picker.Owner = this;
        picker.ShowDialog();
    }

    private void Settings_Click(object sender, RoutedEventArgs e)
    {
        var settings = new SettingsWindow(
            systemProxyEnabled: _systemProxyEnabled,
            routingMode: _routingMode,
            onSystemProxyToggled: enabled => { _systemProxyEnabled = enabled; UpdateUi(); },
            onRoutingChanged: mode => { _routingMode = mode; },
            onUpdateNodes: () => { _ = LoadNodesAsync(); }
        );
        settings.Owner = this;
        settings.ShowDialog();
    }

    private void UpdateTraffic() { /* Placeholder — real Xray stats API call in production */ }
    private void UpdateUi()
    {
        var node = SelectedNode;
        NodeNameLabel.Text = $"{node.Flag} {node.Name}";
        NodeDetailLabel.Text = $"{node.ProtocolDisplay} · {node.TransportDisplay} · {node.Host}:{node.Port}";
        ConnectBtnLabel.Text = _isConnected ? "—" : "连";
        StatusLabel.Text = _isConnected ? (_systemProxyEnabled ? "系统代理模式" : "本地端口模式") : "准备就绪";
        if (_isConnected) StatusDot.Fill = new SolidColorBrush((Color)FindResource("GreenOn"));
    }

    private void TitleBar_MouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton == MouseButton.Left) DragMove();
    }
}
