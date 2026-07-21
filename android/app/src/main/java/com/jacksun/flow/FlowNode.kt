package com.jacksun.flow

data class FlowNode(
    val flag: String = "🌐",
    val name: String = "",
    val host: String = "",
    val port: Int = 443,
    val protocolType: String = "vless",
    val uuid: String = "",
    val flow: String? = null,
    val sni: String = "",
    val fingerprint: String = "chrome",
    val publicKey: String? = null,
    val shortId: String? = null,
    val spiderX: String? = null,
    val transport: String? = null,
    val security: String? = null,
    val rawLink: String? = null,
    var latency: Int? = null
) {
    val protocolDisplay: String get() = when (protocolType.lowercase()) {
        "vless" -> "VLESS"; "vmess" -> "VMess"; "hysteria", "hysteria2" -> "Hysteria2"
        "trojan" -> "Trojan"; "shadowsocks" -> "SS"; else -> protocolType.uppercase()
    }
    val transportDisplay: String get() = when ((transport ?: "").lowercase()) {
        "grpc" -> "gRPC"; "hysteria" -> "UDP"; "tcp" -> "TCP"; "ws" -> "WS"
        else -> (security ?: "AUTO").uppercase()
    }
    val latencyDisplay: String get() = when {
        latency == null -> "—"
        latency!! >= 500 -> "%.1fs".format(latency!! / 1000.0)
        else -> "${latency}ms"
    }
}
