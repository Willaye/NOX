package com.nox.app.ui.navigation

sealed class NoxRoute(val route: String) {
    data object Auth : NoxRoute("auth")
    data object Dashboard : NoxRoute("dashboard")
    data object DeviceDetail : NoxRoute("device/{deviceId}") {
        fun createRoute(deviceId: String) = "device/$deviceId"
    }
}
