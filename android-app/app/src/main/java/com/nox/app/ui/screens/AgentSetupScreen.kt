package com.nox.app.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nox.app.ui.components.GlassCard
import com.nox.app.ui.components.GradientDivider
import com.nox.app.ui.components.NoxButton
import com.nox.app.ui.theme.NoxColors

/**
 * Screen shown on the monitored device.
 * User enters their credentials + device name to register this device
 * and start the background agent service.
 */
@Composable
fun AgentSetupScreen(
    isAgentRunning: Boolean,
    deviceId: String?,
    pairingCode: String?,
    onStartAgent: (email: String, password: String, deviceName: String) -> Unit,
    onStopAgent: () -> Unit
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var deviceName by remember { mutableStateOf("") }

    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.3f, targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = EaseInOutSine),
            repeatMode = RepeatMode.Reverse
        ), label = "alpha"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(NoxColors.VoidBlack)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Agent status indicator
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(
                    Brush.linearGradient(
                        if (isAgentRunning)
                            listOf(NoxColors.OnlineGlow.copy(alpha = 0.15f * pulseAlpha), NoxColors.PhantomGreen.copy(alpha = 0.1f))
                        else
                            listOf(NoxColors.ShadowPurple.copy(alpha = 0.1f), NoxColors.MistGray.copy(alpha = 0.05f))
                    )
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                if (isAgentRunning) Icons.Default.Shield else Icons.Default.PhoneAndroid,
                contentDescription = null,
                modifier = Modifier.size(40.dp),
                tint = if (isAgentRunning) NoxColors.OnlineGlow else NoxColors.ShadowPurple
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = if (isAgentRunning) "Agent Active" else "Device Agent Setup",
            style = MaterialTheme.typography.headlineMedium,
            color = NoxColors.PureLight,
            textAlign = TextAlign.Center
        )

        Text(
            text = if (isAgentRunning) "This device is being monitored remotely"
                   else "Configure this device for remote monitoring",
            style = MaterialTheme.typography.bodyMedium,
            color = NoxColors.ShadowPurple,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(32.dp))

        if (isAgentRunning) {
            // ── Running State ───────────────────────────────
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp)) {
                    InfoRow("Device ID", deviceId ?: "Unknown")
                    GradientDivider(modifier = Modifier.padding(vertical = 12.dp))
                    InfoRow("Pairing Code", pairingCode ?: "Paired")
                    GradientDivider(modifier = Modifier.padding(vertical = 12.dp))
                    InfoRow("Status", "✅ Monitoring Active")
                    GradientDivider(modifier = Modifier.padding(vertical = 12.dp))
                    InfoRow("Network", "Any network (remote)")
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            NoxButton(
                text = "Stop Agent",
                onClick = onStopAgent
            )
        } else {
            // ── Setup State ─────────────────────────────────
            GlassCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text("Sign in with your Nox account", style = MaterialTheme.typography.titleMedium, color = NoxColors.EtherealBlue)
                    Spacer(modifier = Modifier.height(16.dp))

                    com.nox.app.ui.components.NoxTextField(
                        value = email,
                        onValueChange = { email = it },
                        label = "Email",
                        leadingIcon = Icons.Default.Email
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    com.nox.app.ui.components.NoxTextField(
                        value = password,
                        onValueChange = { password = it },
                        label = "Password",
                        leadingIcon = Icons.Default.Lock,
                        isPassword = true
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    com.nox.app.ui.components.NoxTextField(
                        value = deviceName,
                        onValueChange = { deviceName = it },
                        label = "Device Name",
                        leadingIcon = Icons.Default.PhoneAndroid
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            NoxButton(
                text = "Start Monitoring",
                onClick = { onStartAgent(email, password, deviceName) },
                enabled = email.isNotBlank() && password.isNotBlank() && deviceName.isNotBlank()
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        Text(
            text = "🔒 All data transmitted securely over HTTPS",
            style = MaterialTheme.typography.bodySmall,
            color = NoxColors.ShadowPurple,
            letterSpacing = 0.5.sp
        )
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = NoxColors.ShadowPurple)
        Text(value, style = MaterialTheme.typography.bodyMedium, color = NoxColors.WhisperWhite, fontWeight = FontWeight.Medium)
    }
}
