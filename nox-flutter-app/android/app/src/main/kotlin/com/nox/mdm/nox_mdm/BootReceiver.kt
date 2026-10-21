package com.nox.mdm.nox_mdm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * On boot (and OEM-specific quick-boot variants), start the foreground
 * service so monitoring resumes without the user having to open the app.
 *
 * Also checks if Accessibility and Notification Listener are still enabled.
 * If they got disabled (some OEMs disable them on reboot), shows a persistent
 * notification asking the user to re-enable them.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID = "nox_permission_alert"
        private const val NOTIF_ID_A11Y = 42010
        private const val NOTIF_ID_NOTIF_LISTENER = 42011
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d("NoxBoot", "boot action: $action")
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                try {
                    TrackingForegroundService.start(context)
                } catch (t: Throwable) {
                    Log.w("NoxBoot", "start failed: ${t.message}")
                }
                // Check if critical permissions are still enabled
                checkAndPromptPermissions(context)
            }
        }
    }

    private fun checkAndPromptPermissions(context: Context) {
        try {
            createAlertChannel(context)

            val a11yEnabled = isAccessibilityEnabled(context)
            val notifEnabled = isNotificationListenerEnabled(context)

            if (!a11yEnabled) {
                showPermissionNotification(
                    context,
                    NOTIF_ID_A11Y,
                    "Accessibility Service Disabled",
                    "Tap to re-enable NOX Monitoring for WhatsApp & Browser tracking",
                    Settings.ACTION_ACCESSIBILITY_SETTINGS
                )
            }

            if (!notifEnabled) {
                showPermissionNotification(
                    context,
                    NOTIF_ID_NOTIF_LISTENER,
                    "Notification Access Disabled",
                    "Tap to re-enable NOX for message capture",
                    "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"
                )
            }
        } catch (t: Throwable) {
            Log.w("NoxBoot", "permission check failed: ${t.message}")
        }
    }

    private fun isAccessibilityEnabled(context: Context): Boolean {
        val service = "${context.packageName}/${NoxAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.contains(service, ignoreCase = true)
    }

    private fun isNotificationListenerEnabled(context: Context): Boolean {
        val listeners = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return listeners.contains(context.packageName, ignoreCase = true)
    }

    private fun showPermissionNotification(
        context: Context, notifId: Int, title: String, text: String, settingsAction: String
    ) {
        val intent = Intent(settingsAction).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pending = PendingIntent.getActivity(
            context, notifId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .setOngoing(true) // Persistent until user taps
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(notifId, notification)
    }

    private fun createAlertChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "NOX Permission Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alerts when critical permissions are disabled"
        }
        nm.createNotificationChannel(channel)
    }
}
