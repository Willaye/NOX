package com.nox.mdm.nox_mdm

import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import androidx.core.app.NotificationManagerCompat

/**
 * Tiny permission-state helpers used by Dart (via MethodChannel) to render
 * the setup checklist and open the right settings page.
 */
object NoxPermissions {

    private const val NOTIF_LISTENER_SETTINGS =
        "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"

    fun isNotificationListenerEnabled(context: Context): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver, "enabled_notification_listeners"
        ) ?: return false
        val myCn = ComponentName(context, NoxNotificationListenerService::class.java).flattenToString()
        return enabled.split(':').any { it.equals(myCn, ignoreCase = true) }
    }

    fun openNotificationListenerSettings(context: Context) {
        val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    fun isAccessibilityEnabled(context: Context): Boolean {
        return try {
            val mode = Settings.Secure.getInt(
                context.contentResolver,
                Settings.Secure.ACCESSIBILITY_ENABLED
            )
            if (mode != 1) return false
            val services = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            val myCn = ComponentName(context, NoxAccessibilityService::class.java).flattenToString()
            val splitter = TextUtils.SimpleStringSplitter(':')
            splitter.setString(services)
            while (splitter.hasNext()) {
                if (splitter.next().equals(myCn, ignoreCase = true)) return true
            }
            false
        } catch (_: Throwable) { false }
    }

    fun openAccessibilitySettings(context: Context) {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    fun isUsageAccessEnabled(context: Context): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    context.packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Throwable) { false }
    }

    fun openUsageAccessSettings(context: Context) {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    fun isBatteryOptimizationIgnored(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun requestIgnoreBatteryOptimizations(context: Context) {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try { context.startActivity(intent) } catch (_: Throwable) {
            // Some OEMs disable this intent; fall back to the battery settings
            // page.
            val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try { context.startActivity(fallback) } catch (_: Throwable) {}
        }
    }

    fun isPostNotificationsEnabled(context: Context): Boolean {
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    fun openAppNotificationSettings(context: Context) {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try { context.startActivity(intent) } catch (_: Throwable) {
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try { context.startActivity(fallback) } catch (_: Throwable) {}
        }
    }

    fun isMediaAccessEnabled(context: Context): Boolean {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(android.Manifest.permission.READ_MEDIA_IMAGES) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            context.checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        }
    }

    fun snapshot(context: Context): Map<String, Boolean> = mapOf(
        "notificationListener" to isNotificationListenerEnabled(context),
        "accessibility" to isAccessibilityEnabled(context),
        "usageAccess" to isUsageAccessEnabled(context),
        "batteryUnrestricted" to isBatteryOptimizationIgnored(context),
        "postNotifications" to isPostNotificationsEnabled(context),
        "mediaAccess" to isMediaAccessEnabled(context),
        "installPackages" to NoxUpdater.canRequestPackageInstalls(context),
        "smsAccess" to (context.checkSelfPermission(android.Manifest.permission.READ_SMS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED),
        "contactsAccess" to (context.checkSelfPermission(android.Manifest.permission.READ_CONTACTS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED),
        "callLogAccess" to (context.checkSelfPermission(android.Manifest.permission.READ_CALL_LOG) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED),
    )
}
