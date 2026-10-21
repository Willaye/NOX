package com.nox.app.agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.nox.app.data.auth.TokenManager
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Restarts the device agent service after the device reboots.
 * Only starts if a device ID is configured (meaning the device has been registered).
 */
@AndroidEntryPoint
class BootReceiver : BroadcastReceiver() {

    @Inject lateinit var tokenManager: TokenManager

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.i("NoxAgent", "Boot completed — checking if agent should start")

            CoroutineScope(Dispatchers.IO).launch {
                val deviceId = tokenManager.getDeviceId()
                if (deviceId != null) {
                    Log.i("NoxAgent", "Device ID found, starting agent service")
                    DeviceAgentService.start(context)
                } else {
                    Log.i("NoxAgent", "No device ID — agent will not start")
                }
            }
        }
    }
}
