package com.nox.app.ui.screens

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nox.app.ui.components.GlassCard
import com.nox.app.ui.components.NoxButton
import com.nox.app.ui.components.NoxTextField
import com.nox.app.ui.theme.NoxColors

@Composable
fun AuthScreen(
    isLoading: Boolean,
    error: String?,
    onLogin: (String, String) -> Unit,
    onSignup: (String, String) -> Unit,
    onClearError: () -> Unit
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var isLoginMode by remember { mutableStateOf(true) }

    // Animated floating orbs for ethereal background
    val infiniteTransition = rememberInfiniteTransition(label = "bgAnim")
    val orbOffset by infiniteTransition.animateFloat(
        initialValue = 0f, targetValue = 100f,
        animationSpec = infiniteRepeatable(
            animation = tween(8000, easing = EaseInOutSine),
            repeatMode = RepeatMode.Reverse
        ), label = "orb"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.radialGradient(
                    colors = listOf(
                        NoxColors.EtherealBlue.copy(alpha = 0.08f),
                        NoxColors.VoidBlack,
                        NoxColors.DeepAbyss
                    ),
                    center = Offset(200f + orbOffset, 400f - orbOffset * 0.5f),
                    radius = 800f
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Spacer(modifier = Modifier.weight(0.3f))

            // Logo / Brand
            Text(
                text = "NOX",
                fontSize = 48.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 12.sp,
                color = NoxColors.PureLight,
                textAlign = TextAlign.Center
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Remote Device Monitoring",
                style = MaterialTheme.typography.bodyMedium,
                color = NoxColors.EtherealBlue,
                letterSpacing = 2.sp
            )

            Spacer(modifier = Modifier.height(48.dp))

            // Auth Card
            GlassCard(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(24.dp)) {
                    Text(
                        text = if (isLoginMode) "Welcome Back" else "Create Account",
                        style = MaterialTheme.typography.headlineMedium,
                        color = NoxColors.PureLight
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = if (isLoginMode) "Sign in to monitor your devices"
                               else "Set up your monitoring account",
                        style = MaterialTheme.typography.bodyMedium,
                        color = NoxColors.ShadowPurple
                    )

                    Spacer(modifier = Modifier.height(24.dp))

                    NoxTextField(
                        value = email,
                        onValueChange = { email = it; onClearError() },
                        label = "Email",
                        leadingIcon = Icons.Default.Email,
                        keyboardType = KeyboardType.Email
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    NoxTextField(
                        value = password,
                        onValueChange = { password = it; onClearError() },
                        label = "Password",
                        leadingIcon = Icons.Default.Lock,
                        isPassword = true
                    )

                    // Error
                    AnimatedVisibility(visible = error != null) {
                        Text(
                            text = error ?: "",
                            color = NoxColors.OfflineRed,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(top = 12.dp)
                        )
                    }

                    Spacer(modifier = Modifier.height(28.dp))

                    NoxButton(
                        text = if (isLoginMode) "Sign In" else "Sign Up",
                        onClick = {
                            if (isLoginMode) onLogin(email, password)
                            else onSignup(email, password)
                        },
                        isLoading = isLoading,
                        enabled = email.isNotBlank() && password.length >= 6
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // Toggle auth mode
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center
                    ) {
                        Text(
                            text = if (isLoginMode) "Don't have an account? " else "Already have an account? ",
                            color = NoxColors.ShadowPurple,
                            style = MaterialTheme.typography.bodySmall
                        )
                        Text(
                            text = if (isLoginMode) "Sign Up" else "Sign In",
                            color = NoxColors.EtherealBlue,
                            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                            modifier = Modifier.clickable {
                                isLoginMode = !isLoginMode
                                onClearError()
                            }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(0.5f))

            Text(
                text = "Monitor from anywhere • Any network",
                style = MaterialTheme.typography.bodySmall,
                color = NoxColors.ShadowPurple,
                letterSpacing = 1.sp
            )
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
