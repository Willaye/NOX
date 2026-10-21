package com.nox.app.data.api

import com.nox.app.data.model.*
import retrofit2.Response
import retrofit2.http.*

interface NoxApiService {

    // ── Auth ────────────────────────────────────────────────────
    @POST("auth/signup")
    suspend fun signup(@Body request: SignupRequest): Response<AuthResponse>

    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): Response<AuthResponse>

    @GET("auth/profile")
    suspend fun getProfile(): Response<UserInfo>

    // ── Devices ─────────────────────────────────────────────────
    @POST("devices")
    suspend fun createDevice(@Body request: CreateDeviceRequest): Response<DeviceDetail>

    @POST("devices/pair")
    suspend fun pairDevice(@Body request: PairDeviceRequest): Response<DeviceSummary>

    @GET("devices")
    suspend fun getDevices(): Response<List<DeviceSummary>>

    @GET("devices/{id}")
    suspend fun getDevice(@Path("id") id: String): Response<DeviceDetail>

    @PUT("devices/{id}")
    suspend fun updateDevice(@Path("id") id: String, @Body request: UpdateDeviceRequest): Response<DeviceSummary>

    @DELETE("devices/{id}")
    suspend fun deleteDevice(@Path("id") id: String): Response<Map<String, String>>

    @POST("devices/{id}/heartbeat")
    suspend fun heartbeat(@Path("id") id: String, @Body request: HeartbeatRequest): Response<HeartbeatResponse>

    @POST("devices/{id}/regenerate-code")
    suspend fun regeneratePairingCode(@Path("id") id: String): Response<DeviceDetail>

    // ── Activity Logs ───────────────────────────────────────────
    @POST("activity-logs")
    suspend fun createActivityLog(@Body request: CreateActivityLogRequest): Response<ActivityLogItem>

    @POST("activity-logs/batch")
    suspend fun createActivityLogBatch(@Body requests: List<CreateActivityLogRequest>): Response<BatchResponse<ActivityLogItem>>

    @GET("activity-logs/device/{deviceId}")
    suspend fun getActivityLogs(
        @Path("deviceId") deviceId: String,
        @Query("type") type: String? = null,
        @Query("from") from: String? = null,
        @Query("to") to: String? = null
    ): Response<List<ActivityLogItem>>

    @GET("activity-logs/device/{deviceId}/stats")
    suspend fun getActivityStats(@Path("deviceId") deviceId: String): Response<ActivityStats>

    // ── Location Logs ───────────────────────────────────────────
    @POST("location-logs")
    suspend fun createLocationLog(@Body request: CreateLocationLogRequest): Response<LocationLogItem>

    @POST("location-logs/batch")
    suspend fun createLocationLogBatch(@Body requests: List<CreateLocationLogRequest>): Response<BatchResponse<LocationLogItem>>

    @GET("location-logs/device/{deviceId}")
    suspend fun getLocationLogs(
        @Path("deviceId") deviceId: String,
        @Query("from") from: String? = null,
        @Query("to") to: String? = null,
        @Query("limit") limit: Int? = null
    ): Response<List<LocationLogItem>>

    @GET("location-logs/device/{deviceId}/latest")
    suspend fun getLatestLocation(@Path("deviceId") deviceId: String): Response<LocationLogItem>
}
