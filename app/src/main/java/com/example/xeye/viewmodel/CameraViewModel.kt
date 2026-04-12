package com.example.xeye.viewmodel

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.xeye.inference.VlmInferenceEngine
import com.example.xeye.progress.*
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class CameraViewModel(application: Application) : AndroidViewModel(application) {

    private val vlmEngine = VlmInferenceEngine(application)
    private val progressStore = ProgressStore(application)
    private val collectionStore = CollectionStore(application)
    private val comboManager = ComboManager()

    private val _uiState = MutableStateFlow(XeyeUiState())
    val uiState: StateFlow<XeyeUiState> = _uiState.asStateFlow()

    private var isAnalyzing = false
    private var autoExamineJob: Job? = null
    private var currentScreen: GameScreen = GameScreen.CAMERA

    val isModelLoaded: Boolean get() = vlmEngine.isModelLoaded
    val modelError: String? get() = vlmEngine.errorMessage

    init {
        loadGameState()
        viewModelScope.launch {
            vlmEngine.loadModelAsync()
            Log.d("CameraVM", "Model loaded: ${vlmEngine.isModelLoaded}, error: ${vlmEngine.errorMessage}")
            _uiState.value = _uiState.value.copy(
                isModelReady = vlmEngine.isModelLoaded,
                modelError = vlmEngine.errorMessage,
            )
        }
    }

    private fun loadGameState() {
        _uiState.value = _uiState.value.copy(
            playerName = progressStore.playerName,
            level = progressStore.level,
            levelTitle = progressStore.levelTitle,
            totalExamined = progressStore.totalExamined,
            currentLevelXp = progressStore.currentLevelXp,
            xpToNextLevel = progressStore.xpToNextLevel,
            isMaxLevel = progressStore.isMaxLevel,
            collectionCount = collectionStore.getTotalCount(),
            recentEntries = collectionStore.getRecentEntries(30),
            categoryCounts = collectionStore.getCategoryCounts(),
            currentCombo = 0,
            unlockedAchievementIds = getUnlockedAchievements(),
        )
    }

    fun examineFrame(bitmap: Bitmap) {
        if (isAnalyzing || !vlmEngine.isModelLoaded) return
        isAnalyzing = true

        viewModelScope.launch {
            try {
                val rotatedBitmap = rotateBitmap(bitmap, 90f)
                val scaledBitmap = Bitmap.createScaledBitmap(rotatedBitmap, 512, 512, true)
                if (scaledBitmap != rotatedBitmap) rotatedBitmap.recycle()
                _uiState.value = _uiState.value.copy(isInferring = true)
                val result = vlmEngine.examine(scaledBitmap)

                // Rarity roll
                val rarity = RarityRoller.roll()
                // Category inference
                val category = CategoryInferencer.infer(result)
                // Combo
                val combo = comboManager.recordExamine()
                val comboMultiplier = comboManager.getComboMultiplier()
                // XP calculation
                val baseXp = ProgressStore.XP_PER_EXAMINE
                val xpGained = (baseXp * rarity.xpMultiplier * comboMultiplier).toInt()
                // Item name extraction
                val itemName = extractItemName(result)
                // Pixel art thumbnail
                val pixelArt = createPixelArt(scaledBitmap)
                scaledBitmap.recycle()

                // Save to collection
                collectionStore.addEntry(ExamineEntry(
                    text = result,
                    category = category,
                    rarity = rarity,
                    itemName = itemName,
                ), pixelArt)
                pixelArt.recycle()

                // Update max combo
                if (combo > progressStore.maxCombo) {
                    progressStore.maxCombo = combo
                }

                val leveledUp = progressStore.addXp(xpGained)

                // Check achievements
                val newAchievements = checkAchievements(combo)

                // Update quests
                updateQuests(category, rarity, combo)

                _uiState.value = _uiState.value.copy(
                    isInferring = false,
                    currentMessage = result,
                    playerName = progressStore.playerName,
                    level = progressStore.level,
                    levelTitle = progressStore.levelTitle,
                    totalExamined = progressStore.totalExamined,
                    currentLevelXp = progressStore.currentLevelXp,
                    xpToNextLevel = progressStore.xpToNextLevel,
                    isMaxLevel = progressStore.isMaxLevel,
                    leveledUp = leveledUp,
                    currentRarity = rarity,
                    xpGained = xpGained,
                    currentCombo = combo,
                    collectionCount = collectionStore.getTotalCount(),
                    recentEntries = collectionStore.getRecentEntries(30),
                    categoryCounts = collectionStore.getCategoryCounts(),
                    newAchievements = newAchievements,
                    currentItemName = itemName,
                    showRarityResult = true,
                    unlockedAchievementIds = getUnlockedAchievements(),
                )
            } catch (e: Exception) {
                Log.e("CameraVM", "Examine error", e)
                _uiState.value = _uiState.value.copy(isInferring = false)
            } finally {
                isAnalyzing = false
            }
        }
    }

    fun clearLevelUpFlag() {
        _uiState.value = _uiState.value.copy(leveledUp = false)
    }

    fun clearRarityResult() {
        _uiState.value = _uiState.value.copy(showRarityResult = false)
    }

    fun clearNewAchievements() {
        _uiState.value = _uiState.value.copy(newAchievements = emptyList())
    }

    fun setPlayerName(name: String) {
        progressStore.playerName = name
        _uiState.value = _uiState.value.copy(playerName = name)
    }

    fun toggleAutoExamine() {
        if (autoExamineJob?.isActive == true) {
            autoExamineJob?.cancel()
            autoExamineJob = null
            _uiState.value = _uiState.value.copy(isAutoExamine = false)
        } else {
            _uiState.value = _uiState.value.copy(isAutoExamine = true)
            autoExamineJob = viewModelScope.launch {
                delay(180_000)
                _uiState.value = _uiState.value.copy(isAutoExamine = false)
                autoExamineJob = null
            }
        }
    }

    // Screen navigation
    fun navigateTo(screen: GameScreen) {
        currentScreen = screen
        when (screen) {
            GameScreen.CAMERA -> Unit
            GameScreen.MENU -> Unit
            GameScreen.COLLECTION -> refreshCollectionData()
            GameScreen.DIARY -> refreshCollectionData()
            GameScreen.QUESTS -> refreshQuestData()
            GameScreen.ACHIEVEMENTS -> refreshAchievementData()
        }
        _uiState.value = _uiState.value.copy(currentScreen = screen)
    }

    private fun refreshCollectionData() {
        _uiState.value = _uiState.value.copy(
            recentEntries = collectionStore.getRecentEntries(50),
            categoryCounts = collectionStore.getCategoryCounts(),
        )
    }

    private fun refreshQuestData() {
        _uiState.value = _uiState.value.copy()
    }

    private fun refreshAchievementData() {
        _uiState.value = _uiState.value.copy(
            unlockedAchievementIds = getUnlockedAchievements(),
        )
    }

    private fun checkAchievements(combo: Int): List<String> {
        val unlocked = getUnlockedAchievements().toMutableSet()
        val newOnes = mutableListOf<String>()

        for (achievement in AchievementDefinitions.all) {
            if (!unlocked.contains(achievement.id) && achievement.condition(progressStore, collectionStore)) {
                unlocked.add(achievement.id)
                newOnes.add(achievement.title)
            }
        }

        AchievementDefinitions.all.forEach { a ->
            if (unlocked.contains(a.id) && !a.unlocked) {
                a.unlocked = true
                a.unlockedAt = System.currentTimeMillis()
            }
        }

        val comboAchievements = AchievementDefinitions.checkComboAchievement(combo)
        for (ca in comboAchievements) {
            if (!unlocked.contains(ca.id)) {
                unlocked.add(ca.id)
                newOnes.add(ca.title)
                ca.unlocked = true
                ca.unlockedAt = System.currentTimeMillis()
            }
        }

        saveUnlockedAchievements(unlocked)
        return newOnes
    }

    private fun updateQuests(category: Category, rarity: Rarity, combo: Int) {
        // Quest progress is tracked dynamically based on collection data
        // Actual quest checking happens in the UI layer using categoryCounts
    }

    private fun getUnlockedAchievements(): Set<String> {
        val prefs = getApplication<Application>()
            .getSharedPreferences("achievements", android.content.Context.MODE_PRIVATE)
        val json = prefs.getString("unlocked", "[]")
        val arr = org.json.JSONArray(json)
        return (0 until arr.length()).map { arr.getString(it) }.toSet()
    }

    private fun saveUnlockedAchievements(unlocked: Set<String>) {
        val prefs = getApplication<Application>()
            .getSharedPreferences("achievements", android.content.Context.MODE_PRIVATE)
        val arr = org.json.JSONArray()
        for (id in unlocked) arr.put(id)
        prefs.edit().putString("unlocked", arr.toString()).commit()
    }

    fun getQuestProgress(quest: Quest): Int {
        if (quest.targetCategory != null) {
            return collectionStore.getEntriesByCategory(quest.targetCategory).size
        }
        return when (quest.id) {
            "q_rare_sr" -> collectionStore.getEntries().count { it.rarity == Rarity.SR }
            "q_rare_ssr" -> collectionStore.getEntries().count { it.rarity == Rarity.SSR }
            "q_exam_20" -> collectionStore.getTotalCount()
            "q_combo_5" -> if (progressStore.maxCombo >= 5) 1 else 0
            else -> 0
        }
    }

    fun getActiveQuests(): List<Quest> {
        return QuestDefinitions.generateQuests().map { quest ->
            val progress = getQuestProgress(quest)
            quest.copy(progress = progress, completed = progress >= quest.targetCount)
        }
    }

    fun getEntryImage(entryId: String): android.graphics.Bitmap? = collectionStore.getEntryImage(entryId)

    private fun extractItemName(text: String): String {
        val firstLine = text.lines().firstOrNull()?.trim() ?: return "謎のアイテム"
        val name = when {
            firstLine.contains("が") -> firstLine.substringBefore("が").trim()
            firstLine.contains("を") -> firstLine.substringBefore("を").trim()
            else -> firstLine
        }
        return if (name.length > 20) name.take(20) + "…" else name
    }

    private fun createPixelArt(bitmap: Bitmap): Bitmap {
        val small = Bitmap.createScaledBitmap(bitmap, 32, 32, false)
        val result = Bitmap.createScaledBitmap(small, 96, 96, false)
        small.recycle()
        return result
    }

    private fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
        val matrix = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    override fun onCleared() {
        super.onCleared()
        vlmEngine.close()
    }
}

data class XeyeUiState(
    val playerName: String = "",
    val isInferring: Boolean = false,
    val currentMessage: String = "",
    val isModelReady: Boolean = false,
    val modelError: String? = null,
    val isAutoExamine: Boolean = false,
    val level: Int = 1,
    val levelTitle: String = "鑑定見習い",
    val totalExamined: Int = 0,
    val currentLevelXp: Int = 0,
    val xpToNextLevel: Int = 100,
    val isMaxLevel: Boolean = false,
    val leveledUp: Boolean = false,
    val currentRarity: Rarity = Rarity.N,
    val xpGained: Int = 0,
    val currentCombo: Int = 0,
    val showRarityResult: Boolean = false,
    val collectionCount: Int = 0,
    val recentEntries: List<ExamineEntry> = emptyList(),
    val categoryCounts: Map<Category, Int> = emptyMap(),
    val newAchievements: List<String> = emptyList(),
    val currentItemName: String = "",
    val unlockedAchievementIds: Set<String> = emptySet(),
    val currentScreen: GameScreen = GameScreen.CAMERA,
)
