package com.example.xeye.ui

import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.xeye.progress.AchievementDefinitions
import android.graphics.Bitmap
import com.example.xeye.progress.Category
import com.example.xeye.progress.DateFormatter
import com.example.xeye.progress.ExamineEntry
import com.example.xeye.progress.GameScreen
import com.example.xeye.progress.QuestDefinitions
import com.example.xeye.progress.Rarity
import kotlinx.coroutines.delay

// ========== Rarity Result Popup ==========

@Composable
fun RarityResultPopup(
    rarity: Rarity,
    xpGained: Int,
    combo: Int,
    itemName: String = "",
    onDismiss: () -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = 1f,
        animationSpec = tween(300, easing = LinearOutSlowInEasing),
        label = "rarityPopup",
    )
    val infiniteTransition = rememberInfiniteTransition(label = "rarityGlow")
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 0.6f,
        animationSpec = infiniteRepeatable(
            animation = tween(500, easing = LinearOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "rarityGlow",
    )

    LaunchedEffect(Unit) {
        delay(2_500)
        onDismiss()
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 32.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .scale(scale)
                .clip(RoundedCornerShape(8.dp))
                .background(Color(0xFF0D0D2B).copy(alpha = 0.95f))
                .border(
                    border = BorderStroke(3.dp, Color(rarity.color)),
                    shape = RoundedCornerShape(8.dp),
                )
                .padding(horizontal = 24.dp, vertical = 16.dp),
        ) {
            Text(
                text = when (rarity) {
                    Rarity.SSR -> "★ 超レア発見！！ ★"
                    Rarity.SR -> "★ レア発見！ ★"
                    Rarity.R -> "レア発見！"
                    Rarity.N -> "鑑定完了"
                },
                color = Color(rarity.color),
                fontSize = when (rarity) {
                    Rarity.SSR, Rarity.SR -> 22.sp
                    Rarity.R -> 18.sp
                    Rarity.N -> 16.sp
                },
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            )
            if (rarity == Rarity.SSR || rarity == Rarity.SR) {
                Spacer(modifier = Modifier.height(4.dp))
                if (itemName.isNotEmpty()) {
                    Text(
                        text = "「${itemName}」",
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                }
                Text(
                    text = "+${xpGained} XP",
                    color = Color(0xFFFFD700),
                    fontSize = 14.sp,
                    fontFamily = FontFamily.Monospace,
                    modifier = Modifier.alpha(glowAlpha),
                )
            } else {
                Spacer(modifier = Modifier.height(4.dp))
                if (itemName.isNotEmpty()) {
                    Text(
                        text = "「${itemName}」",
                        color = Color.White.copy(alpha = 0.9f),
                        fontSize = 13.sp,
                        fontFamily = FontFamily.Monospace,
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                }
                Text(
                    text = "+${xpGained} XP",
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                )
            }
            if (combo >= 3) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "${combo} COMBO!",
                    color = Color(0xFFFF4444),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                )
            }
        }
    }
}

// ========== Achievement Unlock Popup ==========

@Composable
fun AchievementPopup(
    titles: List<String>,
    onDismiss: () -> Unit,
) {
    LaunchedEffect(titles) {
        delay(3_000)
        onDismiss()
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 32.dp),
    ) {
        titles.forEach { title ->
            Text(
                text = "🏅 実績解除: $title",
                color = Color(0xFFFFD700),
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(4.dp))
        }
    }
}

// ========== Menu Button ==========

@Composable
fun MenuButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(6.dp))
            .background(Color(0xFF0D0D2B).copy(alpha = 0.85f))
            .border(
                border = BorderStroke(2.dp, Color.White),
                shape = RoundedCornerShape(6.dp),
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            )
            .padding(horizontal = 12.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "☰ メニュー",
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
        )
    }
}

// ========== DQ Menu Overlay ==========

@Composable
fun DqMenuOverlay(
    onSelect: (GameScreen) -> Unit,
    onBack: () -> Unit,
    collectionCount: Int,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.7f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onBack,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .width(220.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Color(0xFF0D0D2B))
                .border(
                    border = BorderStroke(3.dp, Color.White),
                    shape = RoundedCornerShape(4.dp),
                )
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "コマンド",
                color = Color(0xFFFFD700),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            )
            Spacer(modifier = Modifier.height(12.dp))
            MenuMenuItem("図鑑", "$collectionCount 件", onClick = { onSelect(GameScreen.COLLECTION) })
            Spacer(modifier = Modifier.height(4.dp))
            MenuMenuItem("日記", "", onClick = { onSelect(GameScreen.DIARY) })
            Spacer(modifier = Modifier.height(4.dp))
            MenuMenuItem("クエスト", "", onClick = { onSelect(GameScreen.QUESTS) })
            Spacer(modifier = Modifier.height(4.dp))
            MenuMenuItem("実績", "", onClick = { onSelect(GameScreen.ACHIEVEMENTS) })
            Spacer(modifier = Modifier.height(8.dp))
            HorizontalDivider(color = Color.White.copy(alpha = 0.3f))
            Spacer(modifier = Modifier.height(8.dp))
            MenuMenuItem("やめる", "", isDestructive = true, onClick = onBack)
        }
    }
}

@Composable
private fun MenuMenuItem(
    label: String,
    subtitle: String,
    isDestructive: Boolean = false,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(4.dp))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            )
            .padding(vertical = 10.dp, horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "▸ $label",
            color = if (isDestructive) Color(0xFFFF6666) else Color.White,
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
        )
        if (subtitle.isNotEmpty()) {
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = subtitle,
                color = Color.White.copy(alpha = 0.5f),
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
            )
        }
    }
}

// ========== Collection Screen ==========

@Composable
fun CollectionScreen(
    entries: List<ExamineEntry>,
    categoryCounts: Map<Category, Int>,
    imageLoader: (String) -> Bitmap? = { null },
    onBack: () -> Unit,
    onFilterCategory: (Category?) -> Unit = {},
) {
    var selectedCategory by remember { mutableStateOf<Category?>(null) }
    val filteredEntries = remember(entries, selectedCategory) {
        if (selectedCategory == null) entries else entries.filter { it.category == selectedCategory }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF000000).copy(alpha = 0.92f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onBack,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxSize()
                .padding(16.dp),
        ) {
            Text(
                text = "鑑定図鑑",
                color = Color(0xFFFFD700),
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(8.dp))

            // Category filter pills
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                item {
                    FilterPill("全て", null, selectedCategory == null, onClick = { selectedCategory = null })
                }
                items(Category.entries.toList()) { cat ->
                    FilterPill(cat.label, cat, selectedCategory == cat, onClick = { selectedCategory = cat })
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "${filteredEntries.size}件",
                color = Color.White.copy(alpha = 0.6f),
                fontSize = 12.sp,
                fontFamily = FontFamily.Monospace,
            )
            Spacer(modifier = Modifier.height(8.dp))
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                items(filteredEntries) { entry ->
                    CollectionEntryItem(entry, imageLoader(entry.id))
                }
            }
        }
    }
}

@Composable
private fun FilterPill(
    label: String,
    category: Category?,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (isSelected) Color(0xFFFFD700) else Color(0xFF1A1A2E))
            .border(
                border = BorderStroke(1.dp, if (isSelected) Color(0xFFFFD700) else Color.White.copy(alpha = 0.4f)),
                shape = RoundedCornerShape(12.dp),
            )
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            )
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Text(
            text = label,
            color = if (isSelected) Color(0xFF1A1A2E) else Color.White.copy(alpha = 0.7f),
            fontSize = 11.sp,
            fontFamily = FontFamily.Monospace,
        )
    }
}

@Composable
private fun CollectionEntryItem(entry: ExamineEntry, thumbnail: Bitmap?) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(4.dp))
            .background(Color(0xFF0D0D2B).copy(alpha = 0.9f))
            .border(
                border = BorderStroke(1.dp, Color(entry.rarity.color).copy(alpha = 0.5f)),
                shape = RoundedCornerShape(4.dp),
            )
            .padding(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (thumbnail != null) {
                Image(
                    bitmap = thumbnail.asImageBitmap(),
                    contentDescription = entry.itemName,
                    modifier = Modifier
                        .size(48.dp)
                        .clip(RoundedCornerShape(4.dp)),
                )
                Spacer(modifier = Modifier.width(8.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (entry.itemName.isNotEmpty()) {
                        Text(
                            text = entry.itemName,
                            color = Color(entry.rarity.color),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace,
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                    }
                    Text(
                        text = "[${entry.rarity.label}]",
                        color = Color(entry.rarity.color),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "[${entry.category.label}]",
                        color = Color.White.copy(alpha = 0.5f),
                        fontSize = 10.sp,
                        fontFamily = FontFamily.Monospace,
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Text(
                        text = DateFormatter.format(entry.timestamp),
                        color = Color.White.copy(alpha = 0.4f),
                        fontSize = 10.sp,
                        fontFamily = FontFamily.Monospace,
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = entry.text,
                    color = Color.White,
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                    lineHeight = 16.sp,
                )
            }
        }
    }
}

// ========== Diary Screen ==========

@Composable
fun DiaryScreen(
    entries: List<ExamineEntry>,
    imageLoader: (String) -> Bitmap? = { null },
    onBack: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF000000).copy(alpha = 0.92f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onBack,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxSize()
                .padding(16.dp),
        ) {
            Text(
                text = "鑑定日記",
                color = Color(0xFFFFD700),
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "${entries.size}件の記録",
                color = Color.White.copy(alpha = 0.6f),
                fontSize = 12.sp,
                fontFamily = FontFamily.Monospace,
            )
            Spacer(modifier = Modifier.height(12.dp))
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(entries) { entry ->
                    DiaryEntryItem(entry, imageLoader(entry.id))
                }
            }
        }
    }
}

@Composable
private fun DiaryEntryItem(entry: ExamineEntry, thumbnail: Bitmap?) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(4.dp))
            .background(Color(0xFF0D0D2B).copy(alpha = 0.9f))
            .padding(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (thumbnail != null) {
                Image(
                    bitmap = thumbnail.asImageBitmap(),
                    contentDescription = entry.itemName,
                    modifier = Modifier
                        .size(48.dp)
                        .clip(RoundedCornerShape(4.dp)),
                )
                Spacer(modifier = Modifier.width(8.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = DateFormatter.format(entry.timestamp),
                        color = Color.White.copy(alpha = 0.5f),
                        fontSize = 11.sp,
                        fontFamily = FontFamily.Monospace,
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "[${entry.rarity.label}]",
                        color = Color(entry.rarity.color),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = entry.category.label,
                        color = Color.White.copy(alpha = 0.5f),
                        fontSize = 10.sp,
                        fontFamily = FontFamily.Monospace,
                    )
                }
                if (entry.itemName.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = entry.itemName,
                        color = Color(entry.rarity.color),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace,
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = entry.text,
                    color = Color.White,
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                    lineHeight = 16.sp,
                )
            }
        }
    }
}

// ========== Quest Screen ==========

@Composable
fun QuestScreen(
    getQuests: () -> List<com.example.xeye.progress.Quest>,
    onBack: () -> Unit,
) {
    val quests = remember { getQuests() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF000000).copy(alpha = 0.92f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onBack,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxSize()
                .padding(16.dp),
        ) {
            Text(
                text = "クエスト",
                color = Color(0xFFFFD700),
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(12.dp))
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(quests) { quest ->
                    QuestItem(quest)
                }
            }
        }
    }
}

@Composable
private fun QuestItem(quest: com.example.xeye.progress.Quest) {
    val progress = quest.progress.coerceAtMost(quest.targetCount).toFloat() / quest.targetCount.toFloat()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(4.dp))
            .background(Color(0xFF0D0D2B).copy(alpha = 0.9f))
            .border(
                border = BorderStroke(1.dp, if (quest.completed) Color(0xFFFFD700) else Color.White.copy(alpha = 0.3f)),
                shape = RoundedCornerShape(4.dp),
            )
            .padding(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = quest.title,
                color = if (quest.completed) Color(0xFFFFD700) else Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            )
        }
        Text(
            text = quest.description,
            color = Color.White.copy(alpha = 0.6f),
            fontSize = 12.sp,
            fontFamily = FontFamily.Monospace,
        )
        Spacer(modifier = Modifier.height(6.dp))
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp)),
            color = if (quest.completed) Color(0xFFFFD700) else Color(0xFF4169E1),
            trackColor = Color.White.copy(alpha = 0.2f),
        )
        Spacer(modifier = Modifier.height(2.dp))
        Row {
            Text(
                text = "${quest.progress}/${quest.targetCount}",
                color = Color.White.copy(alpha = 0.5f),
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = "+${quest.rewardXp} XP",
                color = Color(0xFFFFD700).copy(alpha = if (quest.completed) 1f else 0.5f),
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
            )
        }
    }
}

// ========== Achievement Screen ==========

@Composable
fun AchievementScreen(
    unlockedIds: Set<String> = emptySet(),
    onBack: () -> Unit,
) {
    val allAchievements = AchievementDefinitions.all

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF000000).copy(alpha = 0.92f))
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onBack,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxSize()
                .padding(16.dp),
        ) {
            Text(
                text = "実績",
                color = Color(0xFFFFD700),
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(12.dp))
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                items(allAchievements) { achievement ->
                    AchievementItem(achievement, achievement.id in unlockedIds)
                }
            }
        }
    }
}

@Composable
private fun AchievementItem(achievement: com.example.xeye.progress.Achievement, isUnlocked: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(4.dp))
            .background(Color(0xFF0D0D2B).copy(alpha = 0.9f))
            .border(
                border = BorderStroke(1.dp, if (isUnlocked) Color(0xFFFFD700) else Color.White.copy(alpha = 0.2f)),
                shape = RoundedCornerShape(4.dp),
            )
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = if (isUnlocked) "★" else "☆",
            color = if (isUnlocked) Color(0xFFFFD700) else Color.White.copy(alpha = 0.3f),
            fontSize = 18.sp,
            fontFamily = FontFamily.Monospace,
        )
        Spacer(modifier = Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = achievement.title,
                color = if (isUnlocked) Color(0xFFFFD700) else Color.White.copy(alpha = 0.6f),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
            )
            Text(
                text = achievement.description,
                color = Color.White.copy(alpha = 0.4f),
                fontSize = 11.sp,
                fontFamily = FontFamily.Monospace,
            )
        }
    }
}
