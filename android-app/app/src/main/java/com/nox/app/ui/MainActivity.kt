package com.nox.app.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.nox.app.ui.navigation.NoxRoute
import com.nox.app.ui.screens.*
import com.nox.app.ui.theme.NoxTheme
import com.nox.app.ui.viewmodel.AuthViewModel
import com.nox.app.ui.viewmodel.DashboardViewModel
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            NoxTheme {
                NoxApp()
            }
        }
    }
}

@Composable
fun NoxApp() {
    val navController = rememberNavController()
    val authViewModel: AuthViewModel = hiltViewModel()
    val authState by authViewModel.uiState.collectAsState()

    // Determine start destination
    val startDest = if (authState.isLoggedIn) NoxRoute.Dashboard.route else NoxRoute.Auth.route

    NavHost(
        navController = navController,
        startDestination = startDest,
        modifier = Modifier.fillMaxSize()
    ) {
        // ── Auth Screen ────────────────────────────────────
        composable(NoxRoute.Auth.route) {
            AuthScreen(
                isLoading = authState.isLoading,
                error = authState.error,
                onLogin = { email, password -> authViewModel.login(email, password) },
                onSignup = { email, password -> authViewModel.signup(email, password) },
                onClearError = { authViewModel.clearError() }
            )

            // Navigate to dashboard on successful login
            LaunchedEffect(authState.isLoggedIn) {
                if (authState.isLoggedIn) {
                    navController.navigate(NoxRoute.Dashboard.route) {
                        popUpTo(NoxRoute.Auth.route) { inclusive = true }
                    }
                }
            }
        }

        // ── Dashboard Screen ───────────────────────────────
        composable(NoxRoute.Dashboard.route) {
            val dashboardViewModel: DashboardViewModel = hiltViewModel()
            val dashState by dashboardViewModel.uiState.collectAsState()

            var showAddDialog by remember { mutableStateOf(false) }
            var showPairDialog by remember { mutableStateOf(false) }

            LaunchedEffect(Unit) { dashboardViewModel.loadDevices() }

            DashboardScreen(
                devices = dashState.devices,
                isLoading = dashState.isLoading,
                onDeviceClick = { deviceId ->
                    navController.navigate(NoxRoute.DeviceDetail.createRoute(deviceId))
                },
                onAddDevice = { showAddDialog = true },
                onPairDevice = { showPairDialog = true },
                onLogout = {
                    authViewModel.logout()
                    navController.navigate(NoxRoute.Auth.route) {
                        popUpTo(0) { inclusive = true }
                    }
                },
                onRefresh = { dashboardViewModel.loadDevices() }
            )

            if (showAddDialog) {
                AddDeviceDialog(
                    onDismiss = { showAddDialog = false },
                    onAdd = { name ->
                        dashboardViewModel.createDevice(name)
                        showAddDialog = false
                    }
                )
            }

            if (showPairDialog) {
                PairDeviceDialog(
                    onDismiss = { showPairDialog = false },
                    onPair = { code ->
                        dashboardViewModel.pairDevice(code)
                        showPairDialog = false
                    }
                )
            }
        }

        // ── Device Detail Screen ───────────────────────────
        composable(
            route = NoxRoute.DeviceDetail.route,
            arguments = listOf(navArgument("deviceId") { type = NavType.StringType })
        ) { backStackEntry ->
            val deviceId = backStackEntry.arguments?.getString("deviceId") ?: return@composable
            val dashboardViewModel: DashboardViewModel = hiltViewModel()
            val dashState by dashboardViewModel.uiState.collectAsState()

            LaunchedEffect(deviceId) {
                dashboardViewModel.loadDeviceDetail(deviceId)
                dashboardViewModel.loadActivityLogs(deviceId)
                dashboardViewModel.loadActivityStats(deviceId)
                dashboardViewModel.loadLocationLogs(deviceId)
                dashboardViewModel.loadLatestLocation(deviceId)
            }

            DeviceDetailScreen(
                device = dashState.selectedDevice,
                activityLogs = dashState.activityLogs,
                locationLogs = dashState.locationLogs,
                activityStats = dashState.activityStats,
                latestLocation = dashState.latestLocation,
                isLoading = dashState.isLoading,
                onBack = { navController.popBackStack() },
                onDelete = {
                    dashboardViewModel.deleteDevice(deviceId)
                    navController.popBackStack()
                }
            )
        }
    }
}
