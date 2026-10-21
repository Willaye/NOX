package com.nox.app.ui.screens

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
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
import com.nox.app.data.model.*
import com.nox.app.ui.components.*
import com.nox.app.ui.theme.NoxColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeviceDetailScreen(
    device: DeviceDetail?,
    activityLogs: List<ActivityLogItem>,
    locationLogs: List<LocationLogItem>,
    activityStats: ActivityStats?,
    latestLocation: LocationLogItem?,
    isLoading: Boolean,
    onBack: () -> Unit,
    onDelete: () -> Unit
) {
    var selectedTab by remember { mutableIntStateOf(0) }

    Scaffold(
        containerColor = NoxColors.VoidBlack,
        topBar = {
            TopAppBar(
                title = { Text(device?.name ?: "Device", color = NoxColors.PureLight) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, "Back", tint = NoxColors.MoonlightSilver)
                    }
                },
                actions = {
                    IconButton(onClick = onDelete) {
                        Icon(Icons.Default.Delete, "Delete", tint = NoxColors.OfflineRed)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = NoxColors.VoidBlack)
            )
        }
    ) { paddingValues ->
        if (isLoading || device == null) {
            Box(modifier = Modifier.fillMaxSize().padding(paddingValues), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = NoxColors.EtherealBlue)
            }
            return@Scaffold
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(paddingValues).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // ── Status Header ───────────────────────────────────
            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(20.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(56.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(
                                        if (device.isOnline) Brush.linearGradient(listOf(NoxColors.OnlineGlow.copy(alpha = 0.2f), NoxColors.PhantomGreen.copy(alpha = 0.1f)))
                                        else Brush.linearGradient(listOf(NoxColors.OfflineRed.copy(alpha = 0.2f), NoxColors.NeonPink.copy(alpha = 0.1f)))
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.PhoneAndroid, null, modifier = Modifier.size(28.dp), tint = if (device.isOnline) NoxColors.OnlineGlow else NoxColors.OfflineRed)
                            }
                            Spacer(modifier = Modifier.width(16.dp))
                            Column {
                                Text(device.name, style = MaterialTheme.typography.headlineMedium, color = NoxColors.PureLight)
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    StatusDot(isOnline = device.isOnline)
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        if (device.isOnline) "Online — Connected" else "Offline",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = if (device.isOnline) NoxColors.OnlineGlow else NoxColors.OfflineRed
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))
                        GradientDivider()
                        Spacer(modifier = Modifier.height(12.dp))

                        // Quick stats row
                        Row(modifier = Modifier.fillMaxWidth()) {
                            QuickStat("Status", if (device.isPaired) "Paired" else "Unpaired", Modifier.weight(1f))
                            QuickStat("Activities", "${activityStats?.todayCount ?: 0} today", Modifier.weight(1f))
                            QuickStat("Last Seen", device.lastSeenAt?.take(10) ?: "Never", Modifier.weight(1f))
                        }
                    }
                }
            }

            // ── Location Card ───────────────────────────────────
            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(20.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.LocationOn, null, tint = NoxColors.GlowCyan)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Last Known Location", style = MaterialTheme.typography.titleMedium, color = NoxColors.EtherealBlue)
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        if (latestLocation != null) {
                            Text("Lat: ${latestLocation.latitude}", style = MaterialTheme.typography.bodyMedium, color = NoxColors.MoonlightSilver)
                            Text("Lng: ${latestLocation.longitude}", style = MaterialTheme.typography.bodyMedium, color = NoxColors.MoonlightSilver)
                            Text("At: ${latestLocation.timestamp}", style = MaterialTheme.typography.bodySmall, color = NoxColors.ShadowPurple)
                        } else {
                            Text("No location data available yet", style = MaterialTheme.typography.bodyMedium, color = NoxColors.ShadowPurple)
                        }
                    }
                }
            }

            // ── Tab Selector ────────────────────────────────────
            item {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TabChip("Activity", selectedTab == 0) { selectedTab = 0 }
                    TabChip("Locations", selectedTab == 1) { selectedTab = 1 }
                }
            }

            // ── Activity Logs Tab ───────────────────────────────
            if (selectedTab == 0) {
                if (activityLogs.isEmpty()) {
                    item {
                        EmptyState(Icons.Default.Timeline, "No Activity", "Activity data will appear here once the device agent starts reporting")
                    }
                }
                items(activityLogs) { log ->
                    ActivityLogCard(log)
                }
            }

            // ── Location History Tab ────────────────────────────
            if (selectedTab == 1) {
                if (locationLogs.isEmpty()) {
                    item {
                        EmptyState(Icons.Default.Map, "No Locations", "Location data will appear here once the device agent starts reporting")
                    }
                }
                items(locationLogs) { loc ->
                    LocationLogCard(loc)
                }
            }

            item { Spacer(modifier = Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun QuickStat(label: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleMedium, color = NoxColors.PureLight, fontWeight = FontWeight.SemiBold)
        Text(label, style = MaterialTheme.typography.bodySmall, color = NoxColors.ShadowPurple)
    }
}

@Composable
private fun TabChip(label: String, selected: Boolean, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(label) },
        colors = FilterChipDefaults.filterChipColors(
            selectedContainerColor = NoxColors.EtherealBlue.copy(alpha = 0.2f),
            selectedLabelColor = NoxColors.EtherealBlue,
            containerColor = NoxColors.Obsidian,
            labelColor = NoxColors.ShadowPurple
        ),
        border = FilterChipDefaults.filterChipBorder(
            borderColor = NoxColors.MistGray,
            selectedBorderColor = NoxColors.EtherealBlue,
            enabled = true,
            selected = selected
        )
    )
}

@Composable
private fun ActivityLogCard(log: ActivityLogItem) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(NoxColors.EtherealBlue.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    when (log.type) {
                        "app_usage" -> Icons.Default.Apps
                        "screen_on" -> Icons.Default.PhoneAndroid
                        "screen_off" -> Icons.Default.PhoneLocked
                        "notification" -> Icons.Default.Notifications
                        else -> Icons.Default.Info
                    },
                    contentDescription = null,
                    tint = NoxColors.EtherealBlue,
                    modifier = Modifier.size(20.dp)
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(log.type.replace("_", " ").replaceFirstChar { it.uppercase() }, style = MaterialTheme.typography.titleMedium, color = NoxColors.WhisperWhite)
                Text(log.timestamp, style = MaterialTheme.typography.bodySmall, color = NoxColors.ShadowPurple)
            }
        }
    }
}

@Composable
private fun LocationLogCard(location: LocationLogItem) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(NoxColors.GlowCyan.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Default.LocationOn, null, tint = NoxColors.GlowCyan, modifier = Modifier.size(20.dp))
            }
            Spacer(modifier = Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text("${location.latitude}, ${location.longitude}", style = MaterialTheme.typography.titleMedium, color = NoxColors.WhisperWhite)
                Text(location.timestamp, style = MaterialTheme.typography.bodySmall, color = NoxColors.ShadowPurple)
            }
        }
    }
}
