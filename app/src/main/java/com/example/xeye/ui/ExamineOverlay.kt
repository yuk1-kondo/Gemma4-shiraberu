package com.example.xeye.ui

import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
import com.example.xeye.progress.Category
import com.example.xeye.progress.ExamineEntry
import com.example.xeye.progress.GameScreen
import com.example.xeye.progress.Rarity
import kotlinx.coroutines.delay

// Examining state animation duration
private const val TARGETING_PULSE_DURATION = 800

@Composable
fun ExamineOverlay(
    currentMessage: String,
    isInferring: Boolean,
    isModelReady: Boolean,
    isAutoExamine: Boolean = false,
    playerName: String = "",
    level: Int = 1,
    levelTitle: String = "鑑定見習い",
    totalExamined: Int = 0,
    currentLevelXp: Int = 0,
    xpToNextLevel: Int = 100,
    isMaxLevel: Boolean = false,
    leveledUp: Boolean = false,
    currentRarity: Rarity = Rarity.N,
    xpGained: Int = 0,
    currentCombo: Int = 0,
    showRarityResult: Boolean = false,
    newAchievements: List<String> = emptyList(),
    currentItemName: String = "",
    collectionCount: Int = 0,
    modelError: String? = null,
    onExamine: () -> Unit,
    onToggleAutoExamine: () -> Unit = {},
    onClearLevelUp: () -> Unit = {},
    onClearRarityResult: () -> Unit = {},
    onClearNewAchievements: () -> Unit = {},
    onSetPlayerName: (String) -> Unit = {},
    onOpenMenu: () -> Unit = {},
    onTypeChar: () -> Unit = {},
    onTypeEnd: () -> Unit = {},
    onDiscovery: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val displayedText = remember { mutableStateOf("") }
    val isTyping = remember { mutableStateOf(false) }
    val lastMessage = remember { mutableStateOf("") }
    var showNameDialog by remember { mutableStateOf(false) }

    // Show name dialog on first launch
    LaunchedEffect(playerName, isModelReady) {
        if (isModelReady && playerName.isEmpty()) {
            delay(1500)
            showNameDialog = true
        }
    }

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

            if (isAutoExamine) {
                delay(8_000)
                onExamine()
            }
        }
    }

    var showLevelUp by remember(leveledUp) { mutableStateOf(leveledUp) }
    LaunchedEffect(showLevelUp) {
        if (showLevelUp) {
            delay(3_000)
            showLevelUp = false
            onClearLevelUp()
        }
    }

    val initialMessage = if (!isModelReady) {
        modelError ?: "モデル読み込み中..."
    } else if (currentMessage.isEmpty() && !isInferring) {
        "カメラを向けて「調べる」を押そう"
    } else null

    // Name dialog
    if (showNameDialog) {
        NameInputDialog(
            currentName = playerName,
            onConfirm = { name ->
                onSetPlayerName(name)
                showNameDialog = false
            },
            onDismiss = {
                showNameDialog = false
            },
        )
    }

    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        // Targeting frame (always visible when ready)
        if (isModelReady) {
            TargetingFrame(
                isExamining = isInferring,
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(top = 40.dp),
            )
        }

        // Level HUD top-left
        if (isModelReady) {
            LevelHud(
                playerName = playerName,
                level = level,
                levelTitle = levelTitle,
                totalExamined = totalExamined,
                currentLevelXp = currentLevelXp,
                xpToNextLevel = xpToNextLevel,
                isMaxLevel = isMaxLevel,
                onEditName = { showNameDialog = true },
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(start = 12.dp, top = 48.dp),
            )
        }

        // Menu button top-right
        if (isModelReady) {
            MenuButton(
                onClick = onOpenMenu,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(end = 12.dp, top = 48.dp),
            )
        }

        // Combo display
        if (currentCombo >= 3 && !isInferring) {
            Text(
                text = "${currentCombo} COMBO! ×${if (currentCombo >= 10) "3" else if (currentCombo >= 5) "2" else "1.5"}",
                color = Color(0xFFFF4444),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 52.dp),
            )
        }

        // Level up popup
        if (showLevelUp) {
            LevelUpPopup(
                level = level,
                levelTitle = levelTitle,
                modifier = Modifier.align(Alignment.TopCenter),
            )
        }

        // Rarity result popup
        if (showRarityResult && !isInferring) {
            RarityResultPopup(
                rarity = currentRarity,
                xpGained = xpGained,
                combo = currentCombo,
                itemName = currentItemName,
                onDismiss = onClearRarityResult,
            )
        }

        // Achievement unlock popup
        if (newAchievements.isNotEmpty()) {
            AchievementPopup(
                titles = newAchievements,
                onDismiss = onClearNewAchievements,
            )
        }

        // Buttons
        if (isModelReady && !isInferring) {
            ExamineButton(onClick = onExamine)
        } else if (isInferring) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
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
        }

        // AUTO toggle at bottom-right
        if (isModelReady) {
            AutoToggleButton(
                isActive = isAutoExamine,
                onClick = onToggleAutoExamine,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = 16.dp, bottom = 140.dp),
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
private fun TargetingFrame(
    isExamining: Boolean,
    modifier: Modifier = Modifier,
) {
    val infiniteTransition = rememberInfiniteTransition(label = "targetingPulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = if (isExamining) 0.3f else 0.7f,
        animationSpec = infiniteRepeatable(
            animation = tween(TARGETING_PULSE_DURATION, easing = LinearOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "targetingPulse",
    )

    val cornerLength = 24.dp
    val strokeWidth = 3.dp
    val frameColor = if (isExamining) Color(0xFFFFD700) else Color.White.copy(alpha = 0.5f)

    Box(
        modifier = modifier
            .then(if (isExamining) Modifier.alpha(alpha) else Modifier)
            .size(220.dp),
        contentAlignment = Alignment.Center,
    ) {
        // Top-left corner
        Box(
            modifier = Modifier
                .align(Alignment.TopStart)
                .width(cornerLength)
                .height(strokeWidth)
                .background(frameColor)
        )
        Box(
            modifier = Modifier
                .align(Alignment.TopStart)
                .width(strokeWidth)
                .height(cornerLength)
                .background(frameColor)
        )
        // Top-right corner
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .width(cornerLength)
                .height(strokeWidth)
                .background(frameColor)
        )
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .width(strokeWidth)
                .height(cornerLength)
                .background(frameColor)
        )
        // Bottom-left corner
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .width(cornerLength)
                .height(strokeWidth)
                .background(frameColor)
        )
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .width(strokeWidth)
                .height(cornerLength)
                .background(frameColor)
        )
        // Bottom-right corner
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .width(cornerLength)
                .height(strokeWidth)
                .background(frameColor)
        )
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .width(strokeWidth)
                .height(cornerLength)
                .background(frameColor)
        )
        // Center crosshair (subtle)
        if (!isExamining) {
            Box(
                modifier = Modifier
                    .size(strokeWidth)
                    .background(Color.White.copy(alpha = 0.3f))
            )
        }
    }
}

@Composable
private fun NameInputDialog(
    currentName: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var name by remember { mutableStateOf(currentName) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF0D0D2B),
        shape = RoundedCornerShape(8.dp),
        title = {
            Text(
                text = "名前を登録しよう",
                color = Color(0xFFFFD700),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            )
        },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { if (it.length <= 12) name = it },
                label = { Text("名前") },
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    focusedBorderColor = Color(0xFFFFD700),
                    unfocusedBorderColor = Color.White.copy(alpha = 0.5f),
                    cursorColor = Color(0xFFFFD700),
                    focusedLabelColor = Color(0xFFFFD700),
                ),
                textStyle = androidx.compose.ui.text.TextStyle(
                    fontFamily = FontFamily.Monospace,
                    fontSize = 16.sp,
                ),
            )
        },
        confirmButton = {
            TextButton(onClick = { onConfirm(name.trim()) }) {
                Text("決定", color = Color(0xFFFFD700), fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("後で", color = Color.White.copy(alpha = 0.7f), fontFamily = FontFamily.Monospace)
            }
        },
    )
}

@Composable
private fun LevelHud(
    playerName: String,
    level: Int,
    levelTitle: String,
    totalExamined: Int,
    currentLevelXp: Int,
    xpToNextLevel: Int,
    isMaxLevel: Boolean,
    onEditName: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val progress = if (isMaxLevel || xpToNextLevel <= 0) 1f
    else currentLevelXp.toFloat() / xpToNextLevel.toFloat()

    Column(
        modifier = modifier
            .clip(RoundedCornerShape(6.dp))
            .background(Color(0xFF0D0D2B).copy(alpha = 0.85f))
            .border(
                border = BorderStroke(2.dp, Color(0xFFFFD700)),
                shape = RoundedCornerShape(6.dp),
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onEditName,
            )
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "Lv.$level",
                color = Color(0xFFFFD700),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = if (playerName.isNotEmpty()) playerName else "ななしさん",
                color = Color.White.copy(alpha = if (playerName.isEmpty()) 0.5f else 1f),
                fontSize = 12.sp,
                fontFamily = FontFamily.Monospace,
            )
        }
        Text(
            text = levelTitle,
            color = Color.White.copy(alpha = 0.8f),
            fontSize = 11.sp,
            fontFamily = FontFamily.Monospace,
        )
        Spacer(modifier = Modifier.height(4.dp))
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp)),
            color = Color(0xFFFFD700),
            trackColor = Color.White.copy(alpha = 0.2f),
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = if (isMaxLevel) "MAX" else "${currentLevelXp}/${xpToNextLevel}  調べた数:$totalExamined",
            color = Color.White.copy(alpha = 0.6f),
            fontSize = 10.sp,
            fontFamily = FontFamily.Monospace,
        )
    }
}

@Composable
private fun LevelUpPopup(
    level: Int,
    levelTitle: String,
    modifier: Modifier = Modifier,
) {
    val scale by animateFloatAsState(
        targetValue = 1f,
        animationSpec = tween(400, easing = LinearOutSlowInEasing),
        label = "levelUp",
    )

    Box(
        modifier = modifier
            .padding(top = 80.dp)
            .scale(scale)
            .clip(RoundedCornerShape(8.dp))
            .background(Color(0xFFFFD700).copy(alpha = 0.95f))
            .border(
                border = BorderStroke(3.dp, Color.White),
                shape = RoundedCornerShape(8.dp),
            )
            .padding(horizontal = 24.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "LEVEL UP!",
                color = Color(0xFF1A1A2E),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            )
            Text(
                text = "Lv.$level $levelTitle",
                color = Color(0xFF1A1A2E),
                fontSize = 14.sp,
                fontFamily = FontFamily.Monospace,
            )
        }
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
private fun AutoToggleButton(
    isActive: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val infiniteTransition = rememberInfiniteTransition(label = "autoPulse")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = if (isActive) 0.6f else 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = LinearOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "autoPulse",
    )

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(
                if (isActive) Color(0xFFFFD700).copy(alpha = 0.9f)
                else Color(0xFF1A1A2E).copy(alpha = 0.9f)
            )
            .border(
                border = BorderStroke(2.dp, Color.White),
                shape = RoundedCornerShape(12.dp),
            )
            .then(if (isActive) Modifier.alpha(alpha) else Modifier)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            )
            .padding(horizontal = 20.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = if (isActive) "■ AUTO" else "AUTO",
            color = if (isActive) Color(0xFF1A1A2E) else Color.White.copy(alpha = 0.7f),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
        )
    }
}

@Composable
private fun DqMessageBox(
    text: String,
    modifier: Modifier = Modifier,
) {
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
