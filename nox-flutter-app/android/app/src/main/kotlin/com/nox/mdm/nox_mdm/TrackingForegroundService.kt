package com.nox.mdm.nox_mdm

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Persistent foreground service. Its only job is to keep the app's process
 * alive so our Flutter WebSocket + timers survive Doze mode and Android's
 * background-app killer. All actual data collection runs in the Flutter
 * engine inside the main process — the service just holds a wake lock and
 * shows the required notification.
 */
class TrackingForegroundService : Service() {

    companion object {
        private const val TAG = "NoxForeground"
        private const val NOTIFICATION_ID = 42001
        private const val CHANNEL_ID = "nox_monitoring"
        private const val CHANNEL_NAME = "NOX Monitoring"
        const val ACTION_START = "com.nox.mdm.action.START_FOREGROUND"
        const val ACTION_STOP = "com.nox.mdm.action.STOP_FOREGROUND"

        fun start(context: Context) {
            val intent = Intent(context, TrackingForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, TrackingForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.stopService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var permCheckHandler: android.os.Handler? = null
    private var permCheckRunnable: Runnable? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelfSafely()
                return START_NOT_STICKY
            }
            else -> startForegroundNow()
        }
        return START_STICKY
    }

    private fun startForegroundNow() {
        val notification = buildNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC or
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "startForeground failed: ${t.message}", t)
            // Fall back to a plain foreground start.
            startForeground(NOTIFICATION_ID, notification)
        }
        acquireWakeLock()
        startPermissionCheckLoop()
    }

    /**
     * Checks every 10 minutes if Accessibility and Notification Listener
     * are still enabled. If not, shows a persistent notification.
     */
    private fun startPermissionCheckLoop() {
        permCheckHandler?.removeCallbacksAndMessages(null)
        permCheckHandler = android.os.Handler(android.os.Looper.getMainLooper())
        permCheckRunnable = object : Runnable {
            override fun run() {
                try {
                    val a11yEnabled = isAccessibilityEnabled()
                    val notifEnabled = isNotificationListenerEnabled()
                    val nm = getSystemService(NotificationManager::class.java)

                    if (!a11yEnabled) {
                        val intent = android.content.Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        val pending = PendingIntent.getActivity(
                            this@TrackingForegroundService, 42010, intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        ensureAlertChannel()
                        val notif = NotificationCompat.Builder(this@TrackingForegroundService, "nox_permission_alert")
                            .setContentTitle("⚠️ Accessibility Disabled")
                            .setContentText("Tap to re-enable NOX Monitoring")
                            .setSmallIcon(android.R.drawable.ic_dialog_alert)
                            .setPriority(NotificationCompat.PRIORITY_HIGH)
                            .setAutoCancel(true)
                            .setContentIntent(pending)
                            .build()
                        nm?.notify(42010, notif)
                    } else {
                        nm?.cancel(42010)
                    }

                    if (!notifEnabled) {
                        val intent = android.content.Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        val pending = PendingIntent.getActivity(
                            this@TrackingForegroundService, 42011, intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        ensureAlertChannel()
                        val notif = NotificationCompat.Builder(this@TrackingForegroundService, "nox_permission_alert")
                            .setContentTitle("⚠️ Notification Access Disabled")
                            .setContentText("Tap to re-enable NOX message capture")
                            .setSmallIcon(android.R.drawable.ic_dialog_alert)
                            .setPriority(NotificationCompat.PRIORITY_HIGH)
                            .setAutoCancel(true)
                            .setContentIntent(pending)
                            .build()
                        nm?.notify(42011, notif)
                    } else {
                        nm?.cancel(42011)
                    }
                } catch (_: Throwable) {}

                permCheckHandler?.postDelayed(this, 10 * 60 * 1000L) // every 10 min
            }
        }
        // First check after 30 seconds (give system time to settle after boot)
        permCheckHandler?.postDelayed(permCheckRunnable!!, 30_000L)
    }

    private fun isAccessibilityEnabled(): Boolean {
        val service = "$packageName/${NoxAccessibilityService::class.java.canonicalName}"
        val enabled = android.provider.Settings.Secure.getString(
            contentResolver, android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.contains(service, ignoreCase = true)
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val listeners = android.provider.Settings.Secure.getString(
            contentResolver, "enabled_notification_listeners"
        ) ?: return false
        return listeners.contains(packageName, ignoreCase = true)
    }

    private fun ensureAlertChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel("nox_permission_alert") != null) return
        val channel = NotificationChannel(
            "nox_permission_alert", "NOX Permission Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply { description = "Alerts when critical permissions are disabled" }
        nm.createNotificationChannel(channel)
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "nox:tracking-wakelock"
            ).apply {
                setReferenceCounted(false)
                acquire(/* 24h */ 24L * 60 * 60 * 1000)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "wakelock acquire failed: ${t.message}")
        }
    }

    private fun stopSelfSafely() {
        try {
            permCheckHandler?.removeCallbacksAndMessages(null)
            permCheckHandler = null
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Throwable) {}
        wakeLock = null
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Throwable) {}
        stopSelf()
    }

    override fun onDestroy() {
        try {
            permCheckHandler?.removeCallbacksAndMessages(null)
            permCheckHandler = null
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Throwable) {}
        wakeLock = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pending = if (launchIntent != null) {
            PendingIntent.getActivity(
                this, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("NOX")
            .setContentText("Monitoring active")
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)

        if (pending != null) builder.setContentIntent(pending)
        return builder.build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "NOX runs in the background to keep monitoring active"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_SECRET
        }
        nm.createNotificationChannel(channel)
    }
}
