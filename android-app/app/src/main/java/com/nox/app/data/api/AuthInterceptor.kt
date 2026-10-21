package com.nox.app.data.api

import com.nox.app.data.auth.TokenManager
import kotlinx.coroutines.runBlocking
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthInterceptor @Inject constructor(
    private val tokenManager: TokenManager
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()

        // Skip auth header for login/signup endpoints
        val path = originalRequest.url.encodedPath
        if (path.contains("auth/login") || path.contains("auth/signup")) {
            return chain.proceed(originalRequest)
        }

        // Skip for device agent endpoints (heartbeat, activity-logs POST, location-logs POST)
        if (path.contains("heartbeat") ||
            (originalRequest.method == "POST" && (path.contains("activity-logs") || path.contains("location-logs")))
        ) {
            return chain.proceed(originalRequest)
        }

        val token = runBlocking { tokenManager.getToken() }

        return if (token != null) {
            val authenticatedRequest = originalRequest.newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
            chain.proceed(authenticatedRequest)
        } else {
            chain.proceed(originalRequest)
        }
    }
}
