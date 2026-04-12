package com.example.xeye.viewmodel

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.xeye.inference.VlmInferenceEngine
import com.example.xeye.progress.ProgressStore
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class CameraViewModel(application: Application) : AndroidViewModel(application) {

    private val vlmEngine = VlmInferenceEngine(application)
    private val progressStore = ProgressStore(application)

    private val _uiState = MutableStateFlow(XeyeUiState())
    val uiState: StateFlow<XeyeUiState> = _uiState.asStateFlow()

    private var isAnalyzing = false
    private var autoExamineJob: Job? = null

    val isModelLoaded: Boolean get() = vlmEngine.isModelLoaded
    val modelError: String? get() = vlmEngine.errorMessage

    init {
        _uiState.value = _uiState.value.copy(
            playerName = progressStore.playerName,
            level = progressStore.level,
            levelTitle = progressStore.levelTitle,
            totalExamined = progressStore.totalExamined,
            currentLevelXp = progressStore.currentLevelXp,
            xpToNextLevel = progressStore.xpToNextLevel,
            isMaxLevel = progressStore.isMaxLevel,
        )
        viewModelScope.launch {
            vlmEngine.loadModelAsync()
            Log.d("CameraVM", "Model loaded: ${vlmEngine.isModelLoaded}, error: ${vlmEngine.errorMessage}")
            _uiState.value = _uiState.value.copy(
                isModelReady = vlmEngine.isModelLoaded,
                modelError = vlmEngine.errorMessage,
            )
        }
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

                val leveledUp = progressStore.addXp(ProgressStore.XP_PER_EXAMINE)
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
                )
            } catch (e: Exception) {
                Log.e("CameraVM", "Examine error", e)
                _uiState.value = _uiState.value.copy(isInferring = false)
            } finally {
                isAnalyzing = false
            }
        }
    }

    fun setPlayerName(name: String) {
        progressStore.playerName = name
        _uiState.value = _uiState.value.copy(playerName = name)
    }

    fun clearLevelUpFlag() {
        _uiState.value = _uiState.value.copy(leveledUp = false)
    }

    private fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
        val matrix = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
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
)
