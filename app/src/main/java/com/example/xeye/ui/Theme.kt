package com.example.xeye.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val DqColorScheme = darkColorScheme(
    primary = Color(0xFFFFD700),
    secondary = Color(0xFF4169E1),
    tertiary = Color(0xFFFFD700),
    background = Color(0xFF000000),
    surface = Color(0xFF0D0D2B),
    surfaceVariant = Color(0xFF1A1A2E),
    onPrimary = Color(0xFF1A1A2E),
    onSecondary = Color(0xFFFFFFFF),
    onSurface = Color(0xFFFFFFFF),
    onSurfaceVariant = Color(0xFFBBBBBB),
    outline = Color(0xFFFFFFFF),
    outlineVariant = Color(0xFF888888),
)

@Composable
fun XeyeTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DqColorScheme,
        typography = DqTypography,
        content = content
    )
}

val DqTypography = androidx.compose.material3.Typography(
    displayLarge = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 28.sp,
    ),
    headlineMedium = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 22.sp,
    ),
    titleLarge = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 18.sp,
    ),
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontSize = 18.sp,
        lineHeight = 26.sp,
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontSize = 16.sp,
        lineHeight = 22.sp,
    ),
    labelLarge = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 16.sp,
    ),
)
