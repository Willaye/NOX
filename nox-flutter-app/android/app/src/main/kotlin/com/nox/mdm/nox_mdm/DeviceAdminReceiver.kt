package com.nox.mdm.nox_mdm

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class DeviceAdminReceiver : DeviceAdminReceiver() {

    companion object {
        private const val TAG = "NoxDeviceAdmin"
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.i(TAG, "NOX Device Admin enabled")
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.i(TAG, "NOX Device Admin disabled")
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        return "Disabling NOX device admin requires administrator approval. Contact your IT admin."
    }
}
