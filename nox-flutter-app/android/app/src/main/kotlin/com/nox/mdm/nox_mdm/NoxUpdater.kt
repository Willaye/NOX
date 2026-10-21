package com.nox.mdm.nox_mdm

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File

/**
 * Thin wrapper around the system package installer. We don't do silent
 * installs (that would require the app to be a system-level privileged
 * installer); instead we hand the APK to the standard installer UI, which
 * only asks the user once if "Install unknown apps" hasn't been granted yet.
 *
 * Called from Dart over MethodChannel after `UpdateService` has downloaded
 * the APK to the app cache.
 */
object NoxUpdater {

    private const val TAG = "NoxUpdater"

    /**
     * Launches the system installer for [apkPath]. Returns true if the
     * intent could be started; false otherwise (e.g. missing file, URI
     * build failure). Any throwable is swallowed so a bad update attempt
     * can't crash the host app — the Dart layer gets a false result and
     * can retry on the next poll.
     */
    fun installApk(context: Context, apkPath: String): Boolean {
        return try {
            val file = File(apkPath)
            if (!file.exists() || file.length() == 0L) {
                Log.w(TAG, "installApk: file missing or empty at $apkPath")
                return false
            }

            // Use FileProvider for Android N+ — direct file:// URIs are
            // blocked by StrictMode since API 24 and will FileUriExposedException.
            val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.fileprovider",
                    file,
                )
            } else {
                @Suppress("DEPRECATION")
                Uri.fromFile(file)
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(intent)
            true
        } catch (t: Throwable) {
            Log.w(TAG, "installApk failed: ${t.message}", t)
            false
        }
    }

    /**
     * Opens Settings → "Install unknown apps" for THIS package. On Android O+
     * each app has its own toggle, so there's no system-wide screen to show.
     * Pre-O devices get the device-level unknown-sources screen as a fallback.
     */
    fun openManageInstallSources(context: Context): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(
                    android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            } else {
                @Suppress("DEPRECATION")
                Intent(android.provider.Settings.ACTION_SECURITY_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (t: Throwable) {
            Log.w(TAG, "openManageInstallSources failed: ${t.message}", t)
            false
        }
    }

    /**
     * Returns true if the user has granted this app permission to install
     * APKs. On API < 26 the per-app toggle doesn't exist, so we always
     * report true (the OS-level unknown-sources toggle is honoured instead).
     */
    fun canRequestPackageInstalls(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.packageManager.canRequestPackageInstalls()
            } else {
                true
            }
        } catch (_: Throwable) {
            false
        }
    }
}
