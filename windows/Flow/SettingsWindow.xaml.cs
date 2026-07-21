using System;
using System.Windows;
using System.Windows.Controls;

namespace Flow;

public partial class SettingsWindow : Window
{
    private readonly Action<bool>? _onSystemProxy;
    private readonly Action<string>? _onRouting;
    private readonly Action? _onUpdate;

    public SettingsWindow(bool systemProxyEnabled, string routingMode, Action<bool>? onSystemProxyToggled, Action<string>? onRoutingChanged, Action? onUpdateNodes)
    {
        InitializeComponent();
        _onSystemProxy = onSystemProxyToggled;
        _onRouting = onRoutingChanged;
        _onUpdate = onUpdateNodes;

        SystemProxyCheck.IsChecked = systemProxyEnabled;

        switch (routingMode)
        {
            case "direct": RbDirect.IsChecked = true; break;
            case "lanOnly": RbLanOnly.IsChecked = true; break;
            case "global": RbGlobal.IsChecked = true; break;
            default: RbBypassCN.IsChecked = true; break;
        }
    }

    private void SystemProxy_Changed(object sender, RoutedEventArgs e) =>
        _onSystemProxy?.Invoke(SystemProxyCheck.IsChecked == true);

    private void Routing_Changed(object sender, RoutedEventArgs e)
    {
        var mode = "bypassCN";
        if (RbDirect.IsChecked == true) mode = "direct";
        else if (RbLanOnly.IsChecked == true) mode = "lanOnly";
        else if (RbGlobal.IsChecked == true) mode = "global";
        _onRouting?.Invoke(mode);
    }

    private void UpdateNodes_Click(object sender, RoutedEventArgs e) => _onUpdate?.Invoke();
}
