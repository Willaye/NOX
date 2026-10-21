package com.nox.mdm.nox_mdm

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Captures notifications from monitored apps (WhatsApp, Instagram, Messenger,
 * SMS clients, etc.) and buffers them for the Flutter engine to drain and
 * ship to the backend as SocialAppEvent rows.
 *
 * The service must be enabled by the user in:
 *   Settings → Apps → Special access → Notification access → NOX
 */
class NoxNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "NoxNotifListener"
        private const val PREFS = "nox_notif_buffer"
        private const val KEY_PENDING = "pending_notifications"
        private const val MAX_BUFFER = 500

        // Apps we care about (package name → human-friendly tag used by the
        // backend's SocialAppEvent.appPackage field; we keep the exact
        // package name, not a tag, so the admin UI can group correctly).
        private val MONITORED_PACKAGES = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",            // WhatsApp Business
            "com.instagram.android",
            "com.facebook.orca",           // Messenger
            "com.facebook.mlite",          // Messenger Lite
            "com.facebook.katana",         // Facebook
            "org.telegram.messenger",
            "org.thunderdog.challegram",   // Telegram X
            "com.snapchat.android",
            "com.google.android.apps.messaging", // Google Messages (SMS)
        )

        fun drainPending(context: Context): List<JSONObject> {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING, "") ?: ""
            prefs.edit().remove(KEY_PENDING).apply()
            if (raw.isBlank()) return emptyList()
            return try {
                val arr = JSONArray(raw)
                (0 until arr.length()).mapNotNull { arr.optJSONObject(it) }
            } catch (t: Throwable) {
                Log.w(TAG, "drain parse failed: ${t.message}")
                emptyList()
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        if (!MONITORED_PACKAGES.contains(pkg)) return

        // Skip our own notifications (foreground service).
        if (pkg == applicationContext.packageName) return

        try {
            val extras = sbn.notification?.extras ?: return
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
            val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()

            // Skip empty/system notifications (e.g., ongoing call banner that
            // has no title/text).
            val best = bigText ?: text
            if (title.isNullOrBlank() && best.isNullOrBlank()) return

            // Skip WhatsApp's "N new messages from M chats" summary — it adds
            // no content and would spam the backend.
            if (pkg.startsWith("com.whatsapp") && best?.contains("new message", ignoreCase = true) == true) {
                return
            }

            val payload = JSONObject().apply {
                put("appPackage", pkg)
                put("eventType", "MESSAGE_INCOMING") // best-effort label
                put("content", best ?: "")
                put("metadata", JSONObject().apply {
                    put("contactName", title ?: "")
                    put("subText", subText ?: "")
                    put("direction", "IN")
                    put("source", "notification")
                })
                put("occurredAt", isoNow(sbn.postTime))
            }

            buffer(payload)
        } catch (t: Throwable) {
            Log.w(TAG, "onNotificationPosted error: ${t.message}")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Intentionally no-op. We only track posted notifications.
    }

    private fun buffer(payload: JSONObject) {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING, "") ?: ""
        val arr = if (raw.isBlank()) JSONArray() else try { JSONArray(raw) } catch (_: Throwable) { JSONArray() }
        arr.put(payload)
        // Trim to MAX_BUFFER (keep tail).
        val trimmed = if (arr.length() > MAX_BUFFER) {
            val start = arr.length() - MAX_BUFFER
            val out = JSONArray()
            for (i in start until arr.length()) out.put(arr.get(i))
            out
        } else arr
        prefs.edit().putString(KEY_PENDING, trimmed.toString()).apply()
        NativeBridge.notifyNotification()
    }

    private fun isoNow(epochMs: Long): String {
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
        sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return sdf.format(java.util.Date(epochMs))
    }
}
