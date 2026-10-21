package com.nox.mdm.nox_mdm

import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.provider.CallLog
import android.provider.ContactsContract
import android.provider.Telephony
import android.util.Log
import java.text.SimpleDateFormat
import java.util.*

/**
 * Reads ALL existing data from the device: SMS, Call Logs, Contacts, Browser History.
 * Not just recent — ALL history available on the device.
 */
object NoxDataReaders {

    private const val TAG = "NoxDataReaders"
    private const val SMS_LIMIT = 1000
    private const val CALL_LIMIT = 500
    private const val CONTACTS_LIMIT = 1000
    private const val BROWSER_LIMIT = 500

    private val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    /**
     * Reads ALL SMS from device (not just recent).
     */
    fun readSms(context: Context): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        var cursor: Cursor? = null
        try {
            cursor = context.contentResolver.query(
                Uri.parse("content://sms"),
                arrayOf("_id", "address", "body", "date", "type"),
                null, null,
                "date DESC"
            )
            if (cursor != null) {
                val iAddr = cursor.getColumnIndex("address")
                val iBody = cursor.getColumnIndex("body")
                val iDate = cursor.getColumnIndex("date")
                val iType = cursor.getColumnIndex("type")
                while (cursor.moveToNext() && out.size < SMS_LIMIT) {
                    val addr = if (iAddr >= 0) cursor.getString(iAddr) else null
                    val body = if (iBody >= 0) cursor.getString(iBody) else null
                    val date = if (iDate >= 0) cursor.getLong(iDate) else 0L
                    val type = if (iType >= 0) cursor.getInt(iType) else 1

                    if (addr.isNullOrBlank() && body.isNullOrBlank()) continue

                    out.add(mapOf(
                        "phoneNumber" to (addr ?: "Unknown"),
                        "body" to (body ?: ""),
                        "type" to when (type) {
                            Telephony.Sms.MESSAGE_TYPE_SENT, Telephony.Sms.MESSAGE_TYPE_OUTBOX -> "SENT"
                            Telephony.Sms.MESSAGE_TYPE_DRAFT -> "DRAFT"
                            else -> "INBOX"
                        },
                        "smsDate" to sdf.format(Date(date))
                    ))
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "readSms error: ${e.message}")
        } finally {
            cursor?.close()
        }
        return out
    }

    /**
     * Reads ALL call logs from device.
     */
    fun readCallLogs(context: Context): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        var cursor: Cursor? = null
        try {
            cursor = context.contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.DURATION,
                    CallLog.Calls.DATE,
                ),
                null, null,
                "${CallLog.Calls.DATE} DESC"
            )
            if (cursor != null) {
                val iNum = cursor.getColumnIndex(CallLog.Calls.NUMBER)
                val iName = cursor.getColumnIndex(CallLog.Calls.CACHED_NAME)
                val iType = cursor.getColumnIndex(CallLog.Calls.TYPE)
                val iDur = cursor.getColumnIndex(CallLog.Calls.DURATION)
                val iDate = cursor.getColumnIndex(CallLog.Calls.DATE)
                while (cursor.moveToNext() && out.size < CALL_LIMIT) {
                    val num = if (iNum >= 0) cursor.getString(iNum) else null
                    val name = if (iName >= 0) cursor.getString(iName) else null
                    val type = if (iType >= 0) cursor.getInt(iType) else 1
                    val dur = if (iDur >= 0) cursor.getLong(iDur) else 0L
                    val date = if (iDate >= 0) cursor.getLong(iDate) else 0L

                    if (num.isNullOrBlank()) continue

                    out.add(mapOf(
                        "phoneNumber" to num,
                        "contactName" to name,
                        "callType" to when (type) {
                            CallLog.Calls.OUTGOING_TYPE -> "OUTGOING"
                            CallLog.Calls.MISSED_TYPE -> "MISSED"
                            CallLog.Calls.REJECTED_TYPE -> "MISSED"
                            else -> "INCOMING"
                        },
                        "durationSec" to dur.toInt(),
                        "timestamp" to sdf.format(Date(date))
                    ))
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "readCallLogs error: ${e.message}")
        } finally {
            cursor?.close()
        }
        return out
    }

    /**
     * Reads phone contacts.
     */
    fun readContacts(context: Context): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val seen = mutableSetOf<String>()
        var cursor: Cursor? = null
        try {
            cursor = context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                ),
                null, null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
            )
            if (cursor != null) {
                val iName = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val iNumber = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (cursor.moveToNext() && out.size < CONTACTS_LIMIT) {
                    val name = if (iName >= 0) cursor.getString(iName) else null
                    val number = if (iNumber >= 0) cursor.getString(iNumber) else null
                    if (number.isNullOrBlank()) continue
                    val key = "${name ?: ""}|$number"
                    if (seen.contains(key)) continue
                    seen.add(key)
                    out.add(mapOf(
                        "name" to (name ?: "Unknown"),
                        "phoneNumber" to number,
                    ))
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "readContacts error: ${e.message}")
        } finally {
            cursor?.close()
        }
        return out
    }

    /**
     * Reads Chrome browser history from Content Provider.
     * Works on most Android devices with Chrome installed.
     */
    fun readBrowserHistory(context: Context): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        // Chrome bookmarks/history content provider
        val uris = listOf(
            "content://com.android.chrome.browser/bookmarks",
            "content://com.android.chrome.browser/history",
            "content://browser/bookmarks",
        )
        for (uri in uris) {
            try {
                val cursor = context.contentResolver.query(
                    Uri.parse(uri),
                    arrayOf("url", "title", "date", "visits"),
                    "bookmark = 0", null,  // bookmark=0 means history, not bookmarks
                    "date DESC"
                ) ?: continue

                val iUrl = cursor.getColumnIndex("url")
                val iTitle = cursor.getColumnIndex("title")
                val iDate = cursor.getColumnIndex("date")

                while (cursor.moveToNext() && out.size < BROWSER_LIMIT) {
                    val url = if (iUrl >= 0) cursor.getString(iUrl) else null
                    val title = if (iTitle >= 0) cursor.getString(iTitle) else null
                    val date = if (iDate >= 0) cursor.getLong(iDate) else 0L

                    if (url.isNullOrBlank()) continue

                    out.add(mapOf(
                        "url" to url,
                        "title" to title,
                        "browser" to "Chrome",
                        "visitedAt" to if (date > 0) sdf.format(Date(date)) else sdf.format(Date())
                    ))
                }
                cursor.close()
                if (out.isNotEmpty()) break // Found data, no need to try other URIs
            } catch (e: Throwable) {
                Log.d(TAG, "Browser history URI $uri not available: ${e.message}")
            }
        }
        return out
    }
}
