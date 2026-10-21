package com.nox.app.data.auth

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore by preferencesDataStore(name = "nox_prefs")

@Singleton
class TokenManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        private val ACCESS_TOKEN = stringPreferencesKey("access_token")
        private val USER_ID = stringPreferencesKey("user_id")
        private val USER_EMAIL = stringPreferencesKey("user_email")
        private val DEVICE_ID = stringPreferencesKey("device_id")
    }

    val tokenFlow: Flow<String?> = context.dataStore.data.map { it[ACCESS_TOKEN] }

    suspend fun getToken(): String? =
        context.dataStore.data.first()[ACCESS_TOKEN]

    suspend fun saveAuth(token: String, userId: String, email: String) {
        context.dataStore.data.first()
        context.dataStore.edit { prefs ->
            prefs[ACCESS_TOKEN] = token
            prefs[USER_ID] = userId
            prefs[USER_EMAIL] = email
        }
    }

    suspend fun saveDeviceId(deviceId: String) {
        context.dataStore.edit { prefs ->
            prefs[DEVICE_ID] = deviceId
        }
    }

    suspend fun getDeviceId(): String? =
        context.dataStore.data.first()[DEVICE_ID]

    suspend fun getUserId(): String? =
        context.dataStore.data.first()[USER_ID]

    suspend fun getUserEmail(): String? =
        context.dataStore.data.first()[USER_EMAIL]

    suspend fun clearAll() {
        context.dataStore.edit { it.clear() }
    }

    suspend fun isLoggedIn(): Boolean = getToken() != null
}
