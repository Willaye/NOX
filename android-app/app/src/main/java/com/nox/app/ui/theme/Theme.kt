package com.nox.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// ── Ethereal Color Palette ──────────────────────────────────────
// Dark, mysterious base with glowing accents — like moonlight through mist
object NoxColors {
    val VoidBlack = Color(0xFF0A0A0F)
    val DeepAbyss = Color(0xFF0F1018)
    val Obsidian = Color(0xFF161622)
    val DarkSlate = Color(0xFF1E1E2E)
    val MistGray = Color(0xFF2A2A3E)
    val ShadowPurple = Color(0xFF3B3B5C)

    val EtherealBlue = Color(0xFF6C63FF)
    val GlowCyan = Color(0xFF00E5FF)
    val MoonlightSilver = Color(0xFFB8C0CC)
    val WhisperWhite = Color(0xFFE8EAF0)
    val PureLight = Color(0xFFF5F5FA)

    val NeonPink = Color(0xFFFF6B9D)
    val EmberOrange = Color(0xFFFF9B50)
    val PhantomGreen = Color(0xFF4ECDC4)
    val AuraViolet = Color(0xFF9B59B6)

    val OnlineGlow = Color(0xFF00E676)
    val OfflineRed = Color(0xFFFF5252)
    val WarningAmber = Color(0xFFFFD740)

    // Glassmorphism
    val GlassSurface = Color(0x1AFFFFFF)
    val GlassBorder = Color(0x33FFFFFF)
    val CardSurface = Color(0xFF161622)
    val CardBorder = Color(0xFF2A2A3E)
}

private val NoxDarkColorScheme = darkColorScheme(
    primary = NoxColors.EtherealBlue,
    onPrimary = NoxColors.PureLight,
    primaryContainer = NoxColors.EtherealBlue.copy(alpha = 0.15f),
    secondary = NoxColors.GlowCyan,
    onSecondary = NoxColors.VoidBlack,
    tertiary = NoxColors.NeonPink,
    background = NoxColors.VoidBlack,
    onBackground = NoxColors.WhisperWhite,
    surface = NoxColors.DeepAbyss,
    onSurface = NoxColors.WhisperWhite,
    surfaceVariant = NoxColors.Obsidian,
    onSurfaceVariant = NoxColors.MoonlightSilver,
    outline = NoxColors.ShadowPurple,
    error = NoxColors.OfflineRed,
)

@Composable
fun NoxTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = NoxDarkColorScheme,
        typography = Typography(
            headlineLarge = TextStyle(
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
                letterSpacing = (-0.5).sp,
                color = NoxColors.PureLight
            ),
            headlineMedium = TextStyle(
                fontWeight = FontWeight.SemiBold,
                fontSize = 22.sp,
                letterSpacing = (-0.3).sp,
                color = NoxColors.WhisperWhite
            ),
            titleLarge = TextStyle(
                fontWeight = FontWeight.SemiBold,
                fontSize = 18.sp,
                color = NoxColors.WhisperWhite
            ),
            titleMedium = TextStyle(
                fontWeight = FontWeight.Medium,
                fontSize = 15.sp,
                color = NoxColors.MoonlightSilver
            ),
            bodyLarge = TextStyle(
                fontWeight = FontWeight.Normal,
                fontSize = 16.sp,
                color = NoxColors.MoonlightSilver,
                lineHeight = 24.sp
            ),
            bodyMedium = TextStyle(
                fontWeight = FontWeight.Normal,
                fontSize = 14.sp,
                color = NoxColors.MoonlightSilver,
                lineHeight = 20.sp
            ),
            bodySmall = TextStyle(
                fontWeight = FontWeight.Normal,
                fontSize = 12.sp,
                color = NoxColors.ShadowPurple,
                lineHeight = 16.sp
            ),
            labelLarge = TextStyle(
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
                letterSpacing = 0.5.sp,
                color = NoxColors.PureLight
            ),
        ),
        content = content
    )
}
