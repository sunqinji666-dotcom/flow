# 本地私有配置示例

公开源码只使用占位节点。实际使用时，把真实配置放在本机，不要提交到 Git：

```bash
defaults write com.jacksun.flow FlowRemoteNodesURL "https://你的私有域名/flow/nodes.json"
```

Windows Electron / WPF 可以使用：

```text
FLOW_REMOTE_NODES_URL=https://你的私有域名/flow/nodes.json
```

节点 JSON 的字段结构可参考 `FlowNode` 定义，但真实内容只应保存在私有配置系统中。
