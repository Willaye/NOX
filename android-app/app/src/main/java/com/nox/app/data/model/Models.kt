package com.nox.app.data.model

import com.google.gson.annotations.SerializedName

// Auth
data class SignupRequest(val email: String, val password: String)
data class LoginRequest(val email: String, val password: String)
data class AuthResponse(
    val user: UserInfo,
    val accessToken: String
)
data class UserInfo(
    val id: String,
    val email: String,
    val createdAt: String,
    val devices: List<DeviceSummary>? = null
)

// Device
data class DeviceSummary(
    val id: String,
    val name: String,
    val isPaired: Boolean,
    val isOnline: Boolean,
    val lastSeenAt: String? = null,
    val createdAt: String? = null
)

data class DeviceDetail(
    val id: String,
    val name: String,
    val isPaired: Boolean,
    val isOnline: Boolean,
    val lastSeenAt: String? = null,
    val createdAt: String? = null,
    val pairingCode: String? = null,
    val recentActivity: List<ActivityLogItem>? = null,
    val recentLocations: List<LocationLogItem>? = null
)

data class CreateDeviceRequest(val name: String)
data class PairDeviceRequest(val pairingCode: String)
data class UpdateDeviceRequest(val name: String)
data class HeartbeatRequest(
    val latitude: Double? = null,
    val longitude: Double? = null,
    val batteryLevel: Int? = null
)
data class HeartbeatResponse(val status: String, val timestamp: String)

// Activity Log
data class ActivityLogItem(
    val id: String,
    val deviceId: String,
    val type: String,
    val data: Map<String, Any>,
    val timestamp: String
)

data class CreateActivityLogRequest(
    val deviceId: String,
    val type: String,
    val data: Map<String, Any>
)

data class ActivityStats(
    val totalCount: Int,
    val todayCount: Int,
    val recentLogs: List<ActivityLogItem>
)

// Location Log
data class LocationLogItem(
    val id: String,
    val deviceId: String,
    val latitude: Double,
    val longitude: Double,
    val timestamp: String
)

data class CreateLocationLogRequest(
    val deviceId: String,
    val latitude: Double,
    val longitude: Double
)

data class BatchResponse<T>(
    val count: Int,
    val logs: List<T>
)
