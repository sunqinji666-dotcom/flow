package com.jacksun.flow

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import org.json.JSONObject
import org.json.JSONTokener
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.URL
import javax.net.ssl.HttpsURLConnection

class FlowState(private val appContext: Context) : ViewModel() {
    val isConnected = MutableStateFlow(false)
    val nodes = MutableStateFlow<List<FlowNode>>(emptyList())
    val selectedIndex = MutableStateFlow(0)
    val selectedNode = MutableStateFlow<FlowNode?>(null)
    val connectionStatus = MutableStateFlow("准备就绪")
    val downloadSpeed = MutableStateFlow("—")
    val sessionTraffic = MutableStateFlow("0 MB")
    val todayTraffic = MutableStateFlow("0 MB")
    val totalTraffic = MutableStateFlow("0 MB")
    val systemProxyEnabled = MutableStateFlow(false)
    val routingMode = MutableStateFlow("bypassCN")
    val isUpdatingNodes = MutableStateFlow(false)
    val nodeUpdateMessage = MutableStateFlow("")

    val proxyModeHeadline: String get() = if (systemProxyEnabled.value) "系统代理模式" else "本地端口模式"
    val proxyModeDetail: String get() = "SOCKS5 127.0.0.1:10606"
    val routingModeTitle: String get() = when (routingMode.value) { "direct" -> "不代理"; "global" -> "全局代理"; "lanOnly" -> "绕过局域网"; else -> "绕过大陆" }

    private val defaultNodes = listOf(FlowNode(flag = "🌐", name = "示例节点", host = "example.com", port = 443, protocolType = "vless", uuid = "00000000-0000-0000-0000-000000000000", flow = "xtls-rprx-vision", sni = "example.com", fingerprint = "chrome", publicKey = "REPLACE_WITH_PRIVATE_REALITY_PUBLIC_KEY", shortId = "00", spiderX = "/", transport = "tcp", security = "reality"))
    private val remoteNodesUrl = "https://your-server.example/flow/nodes.json"

    init {
        nodes.value = defaultNodes; selectedNode.value = defaultNodes.first(); nodeUpdateMessage.value = "v3.0"
        XrayCore.init(appContext)
        viewModelScope.launch { delay(500); loadNodes() }
    }

    fun selectNode(index: Int) { val l = nodes.value; if (index in l.indices) { selectedIndex.value = index; selectedNode.value = l[index] } }
    fun toggleConnection() { if (isConnected.value) disconnect() else connect() }
    fun setSystemProxyEnabled(e: Boolean) { systemProxyEnabled.value = e }
    fun setRoutingMode(m: String) { routingMode.value = m }

    private fun connect() {
        val node = selectedNode.value ?: run { connectionStatus.value = "无节点"; return }
        connectionStatus.value = "启动核心中"
        if (XrayCore.start(xrayConfig(node))) { isConnected.value = true; connectionStatus.value = "已连接" }
        else connectionStatus.value = "核心启动失败"
    }

    private fun disconnect() { XrayCore.stop(); isConnected.value = false; connectionStatus.value = "已断开" }

    private fun loadNodes() {
        viewModelScope.launch {
            isUpdatingNodes.value = true; nodeUpdateMessage.value = "拉取中…"
            val list = try {
                withContext(Dispatchers.IO) {
                    val c = URL(remoteNodesUrl).openConnection() as HttpsURLConnection; c.connectTimeout = 8000; c.readTimeout = 8000
                    val r = BufferedReader(InputStreamReader(c.inputStream, "UTF-8")); val b = r.readText(); r.close(); c.disconnect()
                    val a = JSONObject(JSONTokener(b)).getJSONArray("nodes")
                    (0 until a.length()).map { i -> val o = a.getJSONObject(i); FlowNode(flag = o.optString("flag","🌐"), name = o.optString("name","?"), host = o.optString("host",""), port = o.optInt("port",443), protocolType = o.optString("protocolType","vless"), uuid = o.optString("uuid",""), flow = o.optString("flow","").takeIf { it.isNotEmpty() }, sni = o.optString("sni",""), fingerprint = o.optString("fingerprint","chrome"), publicKey = o.optString("publicKey","").takeIf { it.isNotEmpty() }, shortId = o.optString("shortId","").takeIf { it.isNotEmpty() }, transport = o.optString("transport","tcp"), security = o.optString("security","reality")) }
                }
            } catch (e: Exception) { Log.e("Flow","fetch fail",e); defaultNodes }
            nodes.value = list; selectedNode.value = list.first(); nodeUpdateMessage.value = "${list.size} 个节点"; isUpdatingNodes.value = false
        }
    }

    private fun xrayConfig(node: FlowNode) = """{"log":{"loglevel":"warning"},"inbounds":[{"tag":"socks-in","port":10606,"listen":"127.0.0.1","protocol":"socks","settings":{"udp":true}},{"tag":"http-in","port":10607,"listen":"127.0.0.1","protocol":"http"}],"outbounds":[{"tag":"proxy","protocol":"${node.protocolType}","settings":{"vnext":[{"address":"${node.host}","port":${node.port},"users":[{"id":"${node.uuid}","encryption":"none","flow":"${node.flow ?: ""}"}]}]},"streamSettings":{"network":"${node.transport ?: "tcp"}","security":"${node.security ?: "reality"}","realitySettings":{"serverName":"${node.sni}","fingerprint":"${node.fingerprint}","publicKey":"${node.publicKey ?: ""}","shortId":"${node.shortId ?: ""}"}}},{"tag":"direct","protocol":"freedom"}],"routing":{"domainStrategy":"IPIfNonMatch","rules":[{"type":"field","inboundTag":["socks-in","http-in"],"outboundTag":"proxy"}]}}"""

    class Factory(private val context: Context) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST") override fun <T : ViewModel> create(modelClass: Class<T>): T = FlowState(context.applicationContext) as T
    }
}
