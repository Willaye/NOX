package com.nox.app.agent

import android.Manifest
import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.nox.app.R
import com.nox.app.data.api.NoxApiService
import com.nox.app.data.auth.TokenManager
import com.nox.app.data.model.CreateActivityLogRequest
import com.nox.app.data.model.HeartbeatRequest
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.*
import java.util.concurrent.TimeUnit
import javax.inject.Inject

/**
 * NoxAgentService — Runs as a foreground service on the monitored device.
 *
 * Responsibilities:
 * 1. Send periodic heartbeats to keep the device "online" on the server
 * 2. Track and report GPS location
 * 3. Track app usage via UsageStatsManager
 * 4. Report activity logs to the backend
 *
 * Works over ANY network (WiFi, mobile data, etc.) — no same-network restriction.
 */
@AndroidEntryPoint
class DeviceAgentService : Service() {

    @Inject lateinit var api: NoxApiService
    @Inject lateinit var tokenManager: TokenManager

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var lastLatitude: Double? = null
    private var lastLongitude: Double? = null

    companion object {
        const val CHANNEL_ID = "nox_agent_channel"
        const val NOTIFICATION_ID = 1001
        const val TAG = "NoxAgent"

        // Intervals
        const val HEARTBEAT_INTERVAL_MS = 60_000L       // 1 minute
        const val LOCATION_INTERVAL_MS = 120_000L        // 2 minutes
        const val USAGE_CHECK_INTERVAL_MS = 300_000L     // 5 minutes

        fun start(context: Context) {
            val intent = Intent(context, DeviceAgentService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, DeviceAgentService::class.java))
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification("Nox Agent is running"))
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        Log.i(TAG, "Device Agent service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "Device Agent service started")

        // Start all monitoring coroutines
        startHeartbeatLoop()
        startLocationTracking()
        startUsageMonitoring()

        return START_STICKY // Restart if killed
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        serviceScope.cancel()
        fusedLocationClient?.removeLocationUpdates(locationCallback)
        Log.i(TAG, "Device Agent service destroyed")
        super.onDestroy()
    }

    // ── Heartbeat Loop ──────────────────────────────────────────
    private fun startHeartbeatLoop() {
        serviceScope.launch {
            while (isActive) {
                try {
                    val deviceId = tokenManager.getDeviceId()
                    if (deviceId != null) {
                        val request = HeartbeatRequest(
                            latitude = lastLatitude,
                            longitude = lastLongitude
                        )
                        val response = api.heartbeat(deviceId, request)
                        if (response.isSuccessful) {
                            Log.d(TAG, "Heartbeat sent successfully")
                        } else {
                            Log.w(TAG, "Heartbeat failed: ${response.code()}")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Heartbeat error: ${e.message}")
                }
                delay(HEARTBEAT_INTERVAL_MS)
            }
        }
    }

    // ── Location Tracking ───────────────────────────────────────
    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.lastLocation?.let { location ->
                lastLatitude = location.latitude
                lastLongitude = location.longitude
                Log.d(TAG, "Location: ${location.latitude}, ${location.longitude}")
                updateNotification("Monitoring • ${location.latitude.format()}, ${location.longitude.format()}")
            }
        }
    }

    private fun startLocationTracking() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Location permission not granted")
            return
        }

        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            LOCATION_INTERVAL_MS
        ).setMinUpdateDistanceMeters(50f)
            .build()

        fusedLocationClient?.requestLocationUpdates(
            locationRequest, locationCallback, Looper.getMainLooper()
        )
    }

    // ── App Usage Monitoring ────────────────────────────────────
    private fun startUsageMonitoring() {
        serviceScope.launch {
            while (isActive) {
                try {
                    val deviceId = tokenManager.getDeviceId()
                    if (deviceId != null) {
                        val usageLogs = collectUsageStats(deviceId)
                        if (usageLogs.isNotEmpty()) {
                            api.createActivityLogBatch(usageLogs)
                            Log.d(TAG, "Sent ${usageLogs.size} usage logs")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Usage monitoring error: ${e.message}")
                }
                delay(USAGE_CHECK_INTERVAL_MS)
            }
        }
    }

    private fun collectUsageStats(deviceId: String): List<CreateActivityLogRequest> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val endTime = System.currentTimeMillis()
        val startTime = endTime - TimeUnit.MINUTES.toMillis(5)

        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_BEST, startTime, endTime
        )

        return stats
            .filter { it.totalTimeInForeground > 0 }
            .map { stat ->
                CreateActivityLogRequest(
                    deviceId = deviceId,
                    type = "app_usage",
                    data = mapOf(
                        "packageName" to stat.packageName,
                        "totalTimeMs" to stat.totalTimeInForeground,
                        "lastUsed" to stat.lastTimeUsed
                    )
                )
            }
    }

    // ── Notification ────────────────────────────────────────────
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Nox Device Agent",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps device monitoring active"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(content: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Nox Agent")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(content: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(content))
    }

    private fun Double.format(): String = "%.4f".format(this)
}
