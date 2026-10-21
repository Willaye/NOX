package com.nox.mdm.nox_mdm

import io.flutter.plugin.common.EventChannel

/**
 * Keeps a static reference to the latest EventChannel.EventSink so native
 * services (which don't hold a FlutterEngine) can signal the Dart side.
 * The signals are informational nudges only — the actual data flows via
 * SharedPreferences buffers that Dart drains over MethodChannel.
 */
object NativeBridge {
    @Volatile var sink: EventChannel.EventSink? = null

    fun notifyUnlock(ts: Long) { postSafely(mapOf("type" to "unlock", "ts" to ts)) }
    fun notifyNotification() { postSafely(mapOf("type" to "notification")) }
    fun notifyA11y() { postSafely(mapOf("type" to "a11y")) }
    fun notifyBrowser() { postSafely(mapOf("type" to "browser")) }

    private fun postSafely(payload: Map<String, Any?>) {
        try {
            // sink.success must be called on the platform (main) thread.
            val s = sink ?: return
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                try { s.success(payload) } catch (_: Throwable) {}
            }
        } catch (_: Throwable) {}
    }
}
