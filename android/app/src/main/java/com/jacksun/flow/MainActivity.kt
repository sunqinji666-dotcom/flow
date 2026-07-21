package com.jacksun.flow

import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModelProvider
import kotlinx.coroutines.*

class MainActivity : ComponentActivity() {
    private val state: FlowState by lazy {
        ViewModelProvider(this, FlowState.Factory(applicationContext))[FlowState::class.java]
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)



        setContent {
            MaterialTheme(colorScheme = darkColorScheme(background = Color(0xFF090B10), surface = Color(0xFF151B24), onSurface = Color(0xFFF2F7FF), onBackground = Color(0xFFB8C8D8))) {
                val isConnected by state.isConnected.collectAsState()
                val status by state.connectionStatus.collectAsState()
                val downSpeed by state.downloadSpeed.collectAsState()
                val session by state.sessionTraffic.collectAsState()
                val today by state.todayTraffic.collectAsState()
                val total by state.totalTraffic.collectAsState()
                val nodes by state.nodes.collectAsState()
                val selectedIdx by state.selectedIndex.collectAsState()
                val systemProxy by state.systemProxyEnabled.collectAsState()
                val routing by state.routingMode.collectAsState()
                val isUpdating by state.isUpdatingNodes.collectAsState()
                val updateMsg by state.nodeUpdateMessage.collectAsState()

                var showNodePicker by remember { mutableStateOf(false) }
                var showSettings by remember { mutableStateOf(false) }

                val node = nodes.getOrNull(selectedIdx) ?: FlowNode(name = "无节点")

                Box(modifier = Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0xFF151B24), Color(0xFF10141B), Color(0xFF090B10))))) {
                    Column(modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Spacer(modifier = Modifier.height(44.dp))

                        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Text("Flow v2.0", fontSize = 19.sp, fontWeight = FontWeight.ExtraBold, fontStyle = androidx.compose.ui.text.font.FontStyle.Italic, color = Color(0xFF45D6FF))
                            Spacer(modifier = Modifier.weight(1f))
                            Row(modifier = Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.08f)).padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                                Box(modifier = Modifier.size(7.dp).clip(CircleShape).background(if (isConnected) Color(0xFF34C759) else Color(0xFF71859B)))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(status, color = Color(0xFFB8C8D8), fontSize = 12.sp)
                            }
                        }

                        Spacer(modifier = Modifier.height(28.dp))

                        Button(onClick = { state.toggleConnection() }, modifier = Modifier.size(148.dp), shape = CircleShape, colors = ButtonDefaults.buttonColors(containerColor = if (isConnected) Color(0xFF0D3146) else Color(0xFF151519))) {
                            Text(if (isConnected) downSpeed else "连", fontSize = if (isConnected) 42.sp else 48.sp, fontWeight = FontWeight.ExtraBold, color = if (isConnected) Color(0xFF45D6FF) else Color(0xFFF3B85B))
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        Text("${node.flag} ${node.name}", fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFFF2F7FF))
                        Text("${node.protocolDisplay} · ${node.transportDisplay} · ${node.host}:${node.port}", fontSize = 13.sp, color = Color(0xFF71859B))

                        Spacer(modifier = Modifier.height(10.dp))

                        Button(onClick = { showNodePicker = true }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(14.dp), colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.05f))) {
                            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                Text(node.flag, fontSize = 22.sp); Spacer(modifier = Modifier.width(10.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(node.name, fontSize = 13.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFFF2F7FF))
                                    Text(updateMsg, fontSize = 9.sp, color = Color(0xFF71859B))
                                }
                                Text(node.latencyDisplay, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF34C759))
                            }
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        Row(modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.05f)).padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(state.proxyModeHeadline, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFFF2F7FF))
                                Text(state.proxyModeDetail, fontSize = 9.sp, color = Color(0xFF71859B))
                            }
                            Text(state.routingModeTitle, fontSize = 9.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFFB8C8D8), modifier = Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.05f)).padding(horizontal = 8.dp, vertical = 5.dp))
                        }

                        Spacer(modifier = Modifier.height(8.dp))

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Pill("状态", status, isConnected, Modifier.weight(1f))
                            Pill("时长", "00:00", isConnected, Modifier.weight(1f))
                        }

                        Spacer(modifier = Modifier.height(6.dp))

                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            TrafficBox("本次", session, "连接后统计", Modifier.weight(1f))
                            TrafficBox("今日", today, "今天已用", Modifier.weight(1f))
                            TrafficBox("累计", total, "设备累计", Modifier.weight(1f))
                        }

                        Spacer(modifier = Modifier.weight(1f))

                        Button(onClick = { showSettings = true }, modifier = Modifier.size(44.dp), shape = CircleShape, colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.06f))) { Text("⚙", fontSize = 18.sp) }

                        Spacer(modifier = Modifier.height(16.dp))
                    }

                    if (showNodePicker) {
                        AlertDialog(onDismissRequest = { showNodePicker = false }, title = { Text("选择节点", fontWeight = FontWeight.ExtraBold) }, text = {
                            Column {
                                Text(updateMsg, fontSize = 10.sp, color = Color(0xFF71859B))
                                nodes.forEachIndexed { i, n ->
                                    Surface(modifier = Modifier.fillMaxWidth().clickable { state.selectNode(i); showNodePicker = false }.padding(vertical = 2.dp), color = if (i == selectedIdx) Color(0xFF242321) else Color.Transparent, shape = RoundedCornerShape(10.dp)) {
                                        Row(modifier = Modifier.padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                                            Text(n.flag, fontSize = 20.sp); Spacer(modifier = Modifier.width(8.dp))
                                            Column(modifier = Modifier.weight(1f)) { Text(n.name, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp, color = Color(0xFFF2F7FF)); Text("${n.protocolDisplay} · ${n.transportDisplay} · ${n.host}:${n.port}", fontSize = 9.sp, color = Color(0xFF71859B)) }
                                            Text(n.latencyDisplay, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF34C759))
                                        }
                                    }
                                }
                            }
                        }, confirmButton = {})
                    }

                    if (showSettings) {
                        AlertDialog(onDismissRequest = { showSettings = false }, title = { Text("设置", fontWeight = FontWeight.ExtraBold) }, text = {
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) { Column(modifier = Modifier.weight(1f)) { Text("节点管理", fontWeight = FontWeight.ExtraBold, color = Color(0xFFF2F7FF)); Text(updateMsg, fontSize = 10.sp, color = Color(0xFF71859B)) } }
                                Row(verticalAlignment = Alignment.CenterVertically) { Text("系统代理", fontWeight = FontWeight.ExtraBold, color = Color(0xFFF2F7FF)); Spacer(modifier = Modifier.weight(1f)); Switch(checked = systemProxy, onCheckedChange = { state.setSystemProxyEnabled(it) }) }
                                Text("分流策略", fontWeight = FontWeight.ExtraBold, color = Color(0xFFF2F7FF))
                                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { listOf("direct" to "不代理", "bypassCN" to "绕过大陆", "lanOnly" to "绕过局域网", "global" to "全局").forEach { (k, v) -> FilterChip(selected = routing == k, onClick = { state.setRoutingMode(k) }, label = { Text(v, fontSize = 10.sp) }) } }
                            }
                        }, confirmButton = {})
                    }
                }
            }
        }
    }
}

@Composable fun Pill(title: String, value: String, isOn: Boolean, modifier: Modifier) { Row(modifier = modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.04f)).padding(horizontal = 12.dp, vertical = 9.dp), verticalAlignment = Alignment.CenterVertically) { Box(modifier = Modifier.size(7.dp).clip(CircleShape).background(if (isOn) Color(0xFF34C759) else Color(0xFF71859B))); Spacer(modifier = Modifier.width(6.dp)); Text(title, fontSize = 10.sp, color = Color(0xFF71859B)); Spacer(modifier = Modifier.width(6.dp)); Text(value, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFFB8C8D8)) } }
@Composable fun TrafficBox(title: String, value: String, note: String, modifier: Modifier) { Column(modifier = modifier.clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.04f)).padding(horizontal = 10.dp, vertical = 9.dp), horizontalAlignment = Alignment.CenterHorizontally) { Text(title, fontSize = 10.sp, color = Color(0xFF71859B)); Text(value, fontSize = 13.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFFF3B85B)); Text(note, fontSize = 8.sp, color = Color(0xFF4E5965)) } }
