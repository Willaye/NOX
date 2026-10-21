package com.nox.mdm.nox_mdm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Captures screen on/off and unlock events. Buffers them to shared prefs so
 * the Flutter engine can drain them when it next connects (events may fire
 * while the engine is not running — e.g. phone just woke up).
 */
class UnlockReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "NoxUnlock"
        private const val PREFS = "nox_unlock_buffer"
        private const val KEY_PENDING = "pending_unlocks"
        private const val MAX_BUFFER = 50

        fun drainPending(context: Context): List<Long> {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING, "") ?: ""
            prefs.edit().remove(KEY_PENDING).apply()
            if (raw.isBlank()) return emptyList()
            return raw.split(',').mapNotNull { it.trim().toLongOrNull() }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        when (action) {
            Intent.ACTION_USER_PRESENT -> {
                val now = System.currentTimeMillis()
                Log.d(TAG, "unlock at $now")
                appendPending(context, now)
                // Nudge the engine via the foreground service so Flutter can
                // flush the buffer on its next tick.
                TrackingForegroundService.start(context)
                NativeBridge.notifyUnlock(now)
            }
            Intent.ACTION_SCREEN_ON -> Log.d(TAG, "screen on")
            Intent.ACTION_SCREEN_OFF -> Log.d(TAG, "screen off")
        }
    }

    private fun appendPending(context: Context, ts: Long) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY_PENDING, "") ?: ""
        val list = existing.split(',').filter { it.isNotBlank() }.toMutableList()
        list.add(ts.toString())
        val trimmed = if (list.size > MAX_BUFFER) list.takeLast(MAX_BUFFER) else list
        prefs.edit().putString(KEY_PENDING, trimmed.joinToString(",")).apply()
    }
}
