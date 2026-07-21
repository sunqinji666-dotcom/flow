using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;

namespace Flow;

public partial class NodePickerWindow : Window
{
    private readonly List<FlowNode> _nodes;
    private readonly Action<int> _onSelect;

    public NodePickerWindow(List<FlowNode> nodes, int selectedIndex, Action<int> onSelect)
    {
        InitializeComponent();
        _nodes = nodes;
        _onSelect = onSelect;
        NodeListBox.ItemsSource = nodes.Select((n, i) => new { Index = i, Display = $"{n.Flag} {n.Name}  {n.LatencyDisplay}" }).ToList();
        NodeListBox.SelectedIndex = selectedIndex;
    }

    private void NodeListBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (NodeListBox.SelectedIndex >= 0)
        {
            _onSelect(NodeListBox.SelectedIndex);
            Close();
        }
    }
}
