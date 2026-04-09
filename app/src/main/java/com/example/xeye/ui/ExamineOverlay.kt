package com.example.xeye.ui

import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

@Composable
fun ExamineOverlay(
    currentMessage: String,
    isInferring: Boolean,
    isModelReady: Boolean,
    modelError: String? = null,
    onExamine: () -> Unit,
    onTypeChar: () -> Unit = {},
    onTypeEnd: () -> Unit = {},
    onDiscovery: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val displayedText = remember { mutableStateOf("") }
    val isTyping = remember { mutableStateOf(false) }
    val lastMessage = remember { mutableStateOf("") }

    LaunchedEffect(currentMessage) {
        if (currentMessage.isNotEmpty() && currentMessage != lastMessage.value) {
            lastMessage.value = currentMessage
            displayedText.value = ""
            isTyping.value = true
            onDiscovery()
            currentMessage.forEachIndexed { index, _ ->
                delay(40)
                displayedText.value = currentMessage.substring(0, index + 1)
                onTypeChar()
            }
            onTypeEnd()
            isTyping.value = false
        }
    }

    val initialMessage = if (!isModelReady) {
        modelError ?: "モデル読み込み中..."
    } else if (currentMessage.isEmpty() && !isInferring) {
        "カメラを向けて「調べる」を押そう"
    } else null

    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        // Examine button
        if (isModelReady && !isInferring) {
            ExamineButton(onClick = onExamine)
        } else if (isInferring) {
            CircularProgressIndicator(
                modifier = Modifier.size(48.dp),
                color = MaterialTheme.colorScheme.primary,
                strokeWidth = 3.dp,
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = if (displayedText.value.isEmpty()) "調べています..." else "",
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                fontSize = 14.sp,
                fontFamily = FontFamily.Monospace,
            )
        }

        // Message box at bottom
        DqMessageBox(
            text = when {
                isInferring && displayedText.value.isEmpty() -> "・"
                isInferring -> displayedText.value
                displayedText.value.isNotEmpty() -> displayedText.value
                else -> initialMessage ?: ""
            },
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .padding(start = 16.dp, end = 16.dp, bottom = 32.dp)
        )
    }
}

@Composable
private fun ExamineButton(onClick: () -> Unit) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val scale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.03f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = LinearOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulse",
    )

    Box(
        modifier = Modifier
            .scale(scale)
            .clip(RoundedCornerShape(8.dp))
            .background(Color(0xFF1A1A2E).copy(alpha = 0.9f))
            .border(
                border = BorderStroke(3.dp, Color.White),
                shape = RoundedCornerShape(8.dp),
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            )
            .padding(horizontal = 40.dp, vertical = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "調べる",
            color = Color(0xFFFFD700),
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun DqMessageBox(
    text: String,
    modifier: Modifier = Modifier,
) {
    // Outer box with white border
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(Color(0xFF0D0D2B))
            .border(
                border = BorderStroke(3.dp, Color.White),
                shape = RoundedCornerShape(4.dp),
            ),
    ) {
        Text(
            text = text,
            color = Color.White,
            fontSize = 16.sp,
            fontFamily = FontFamily.Monospace,
            lineHeight = 24.sp,
            textAlign = TextAlign.Start,
            modifier = Modifier.padding(16.dp),
        )
    }
}
