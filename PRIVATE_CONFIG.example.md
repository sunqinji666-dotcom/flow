# 本地私有配置

公开源码不包含可用节点。实际使用时，在 Flow 的“节点库”中导入链接；链接只保存到本机，不要提交到 Git。

Flow 不读取订阅地址、不保存服务器管理地址、也不向任何服务器上传节点。当前导入器支持 VLESS + Reality + TCP，例如：

    vless://…?encryption=none&flow=xtls-rprx-vision&security=reality&type=tcp#节点名称

真实连接信息始终只应保存在你自己的 Mac 本地配置中。
