package com.nox.app.ui.screens

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nox.app.data.model.DeviceSummary
import com.nox.app.ui.components.*
import com.nox.app.ui.theme.NoxColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    devices: List<DeviceSummary>,
    isLoading: Boolean,
    onDeviceClick: (String) -> Unit,
    onAddDevice: () -> Unit,
    onPairDevice: () -> Unit,
    onLogout: () -> Unit,
    onRefresh: () -> Unit
) {
    val onlineCount = devices.count { it.isOnline }
    val totalCount = devices.size

    Scaffold(
        containerColor = NoxColors.VoidBlack,
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            "NOX",
                            fontWeight = FontWeight.Black,
                            letterSpacing = 4.sp,
                            color = NoxColors.PureLight
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            "Dashboard",
                            style = MaterialTheme.typography.bodyMedium,
                            color = NoxColors.ShadowPurple
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(Icons.Default.Refresh, "Refresh", tint = NoxColors.EtherealBlue)
                    }
                    IconButton(onClick = onLogout) {
                        Icon(Icons.Default.Logout, "Logout", tint = NoxColors.ShadowPurple)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = NoxColors.VoidBlack
                )
            )
        },
        floatingActionButton = {
            Column {
                SmallFloatingActionButton(
                    onClick = onPairDevice,
                    containerColor = NoxColors.GlowCyan,
                    contentColor = NoxColors.VoidBlack
                ) {
                    Icon(Icons.Default.Link, "Pair Device")
                }
                Spacer(modifier = Modifier.height(12.dp))
                FloatingActionButton(
                    onClick = onAddDevice,
                    containerColor = NoxColors.EtherealBlue,
                    contentColor = NoxColors.PureLight
                ) {
                    Icon(Icons.Default.Add, "Add Device")
                }
            }
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Status summary card
            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.padding(20.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                "Remote Monitoring",
                                style = MaterialTheme.typography.bodySmall,
                                color = NoxColors.ShadowPurple,
                                letterSpacing = 2.sp
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                "$onlineCount / $totalCount Online",
                                style = MaterialTheme.typography.headlineMedium,
                                color = NoxColors.PureLight
                            )
                        }
                        Box(
                            modifier = Modifier
                                .size(56.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(
                                    Brush.linearGradient(
                                        listOf(NoxColors.EtherealBlue, NoxColors.GlowCyan)
                                    )
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.Devices,
                                contentDescription = null,
                                modifier = Modifier.size(28.dp),
                                tint = NoxColors.PureLight
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(4.dp))
            }

            // Section header
            item {
                SectionHeader("Your Devices")
            }

            // Loading indicator
            if (isLoading && devices.isEmpty()) {
                item {
                    Box(modifier = Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = NoxColors.EtherealBlue)
                    }
                }
            }

            // Empty state
            if (!isLoading && devices.isEmpty()) {
                item {
                    EmptyState(
                        icon = Icons.Default.PhoneAndroid,
                        title = "No devices yet",
                        subtitle = "Add a device to start remote monitoring"
                    )
                }
            }

            // Device cards
            items(devices, key = { it.id }) { device ->
                DeviceCard(device = device, onClick = { onDeviceClick(device.id) })
            }

            item { Spacer(modifier = Modifier.height(80.dp)) }
        }
    }
}

@Composable
private fun DeviceCard(device: DeviceSummary, onClick: () -> Unit) {
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Device icon with status
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(
                        if (device.isOnline) NoxColors.OnlineGlow.copy(alpha = 0.1f)
                        else NoxColors.OfflineRed.copy(alpha = 0.1f)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.PhoneAndroid,
                    contentDescription = null,
                    tint = if (device.isOnline) NoxColors.OnlineGlow else NoxColors.OfflineRed
                )
            }

            Spacer(modifier = Modifier.width(14.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(device.name, style = MaterialTheme.typography.titleLarge, color = NoxColors.PureLight)
                Spacer(modifier = Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    StatusDot(isOnline = device.isOnline, size = 8.dp)
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = if (device.isOnline) "Online" else if (device.lastSeenAt != null) "Last seen: ${device.lastSeenAt}" else "Offline",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (device.isOnline) NoxColors.OnlineGlow else NoxColors.ShadowPurple
                    )
                }
                if (!device.isPaired) {
                    Text("⏳ Awaiting pairing", style = MaterialTheme.typography.bodySmall, color = NoxColors.WarningAmber)
                }
            }

            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = NoxColors.ShadowPurple
            )
        }
    }
}
