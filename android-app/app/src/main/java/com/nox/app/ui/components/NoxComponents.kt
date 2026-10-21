package com.nox.app.ui.components

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.nox.app.ui.theme.NoxColors

// ── Glass Card ──────────────────────────────────────────────────
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = modifier
            .border(1.dp, NoxColors.GlassBorder, RoundedCornerShape(20.dp)),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = NoxColors.CardSurface,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        content = content
    )
}

// ── Glowing Button ──────────────────────────────────────────────
@Composable
fun NoxButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isLoading: Boolean = false
) {
    Button(
        onClick = onClick,
        modifier = modifier
            .height(54.dp)
            .fillMaxWidth(),
        enabled = enabled && !isLoading,
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = NoxColors.EtherealBlue,
            disabledContainerColor = NoxColors.EtherealBlue.copy(alpha = 0.3f),
        ),
        elevation = ButtonDefaults.buttonElevation(
            defaultElevation = 8.dp,
            pressedElevation = 2.dp
        )
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(22.dp),
                color = NoxColors.PureLight,
                strokeWidth = 2.dp
            )
        } else {
            Text(text, style = MaterialTheme.typography.labelLarge)
        }
    }
}

// ── Ethereal Text Field ─────────────────────────────────────────
@Composable
fun NoxTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    leadingIcon: ImageVector? = null,
    isPassword: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    keyboardActions: KeyboardActions = KeyboardActions.Default
) {
    var passwordVisible by remember { mutableStateOf(false) }

    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label, color = NoxColors.ShadowPurple) },
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        singleLine = true,
        leadingIcon = leadingIcon?.let {
            { Icon(it, contentDescription = null, tint = NoxColors.EtherealBlue) }
        },
        trailingIcon = if (isPassword) {
            {
                IconButton(onClick = { passwordVisible = !passwordVisible }) {
                    Icon(
                        if (passwordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                        contentDescription = "Toggle password",
                        tint = NoxColors.ShadowPurple
                    )
                }
            }
        } else null,
        visualTransformation = if (isPassword && !passwordVisible)
            PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        keyboardActions = keyboardActions,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = NoxColors.EtherealBlue,
            unfocusedBorderColor = NoxColors.MistGray,
            focusedContainerColor = NoxColors.Obsidian,
            unfocusedContainerColor = NoxColors.DeepAbyss,
            cursorColor = NoxColors.GlowCyan,
            focusedTextColor = NoxColors.PureLight,
            unfocusedTextColor = NoxColors.MoonlightSilver,
        )
    )
}

// ── Status Pulse Dot ────────────────────────────────────────────
@Composable
fun StatusDot(isOnline: Boolean, size: Dp = 10.dp) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = if (isOnline) 0.4f else 1f,
        targetValue = if (isOnline) 1f else 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200, easing = EaseInOutSine),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseAlpha"
    )

    val color = if (isOnline) NoxColors.OnlineGlow else NoxColors.OfflineRed

    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(color.copy(alpha = alpha))
    )
}

// ── Section Header ──────────────────────────────────────────────
@Composable
fun SectionHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleMedium,
        color = NoxColors.EtherealBlue,
        modifier = modifier.padding(bottom = 8.dp)
    )
}

// ── Gradient Divider ────────────────────────────────────────────
@Composable
fun GradientDivider(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(
                Brush.horizontalGradient(
                    listOf(
                        Color.Transparent,
                        NoxColors.EtherealBlue.copy(alpha = 0.5f),
                        NoxColors.GlowCyan.copy(alpha = 0.3f),
                        Color.Transparent
                    )
                )
            )
    )
}

// ── Empty State ─────────────────────────────────────────────────
@Composable
fun EmptyState(
    icon: ImageVector,
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth().padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            icon, contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = NoxColors.ShadowPurple
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(title, style = MaterialTheme.typography.titleLarge, color = NoxColors.MoonlightSilver)
        Spacer(modifier = Modifier.height(8.dp))
        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = NoxColors.ShadowPurple)
    }
}
