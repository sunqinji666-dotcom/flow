package com.jacksun.flow

import android.content.Context
import android.util.Log
import libv2ray.CoreController
import libv2ray.Libv2ray

object XrayCore {
    private var controller: CoreController? = null
    private var initDone = false

    fun init(context: Context) {
        if (initDone) return
        Thread {
            try {
                Libv2ray.initCoreEnv(
                    context.filesDir.absolutePath,
                    context.filesDir.absolutePath
                )
                initDone = true
                Log.d("Flow", "Libv2ray.initCoreEnv OK")
            } catch (e: Exception) {
                Log.e("Flow", "Libv2ray.initCoreEnv failed", e)
            }
        }.start()
    }

    fun start(config: String): Boolean {
        stop()
        return try {
            val c = Libv2ray.newCoreController(null)
            c.startLoop(config, 10)
            controller = c
            Log.d("Flow", "Xray started via Libv2ray")
            true
        } catch (e: Exception) {
            Log.e("Flow", "Xray start failed", e)
            false
        }
    }

    fun stop() {
        try { controller?.stopLoop() } catch (_: Exception) {}
        controller = null
    }

    fun isRunning() = try { controller?.isRunning == true } catch (_: Exception) { false }

    fun measureDelay(configJson: String): Long? {
        return try {
            Libv2ray.measureOutboundDelay(configJson, "https://www.google.com/generate_204")
        } catch (_: Exception) { null }
    }
}
