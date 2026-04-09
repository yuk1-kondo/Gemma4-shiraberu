package com.example.xeye.viewmodel

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.xeye.inference.VlmInferenceEngine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class CameraViewModel(application: Application) : AndroidViewModel(application) {

    private val vlmEngine = VlmInferenceEngine(application)

    private val _uiState = MutableStateFlow(XeyeUiState())
    val uiState: StateFlow<XeyeUiState> = _uiState.asStateFlow()

    private var isAnalyzing = false

    val isModelLoaded: Boolean get() = vlmEngine.isModelLoaded
    val modelError: String? get() = vlmEngine.errorMessage

    init {
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
                _uiState.value = _uiState.value.copy(isInferring = true)
                val result = vlmEngine.examine(rotatedBitmap)
                _uiState.value = _uiState.value.copy(
                    isInferring = false,
                    currentMessage = result,
                )
            } catch (e: Exception) {
                Log.e("CameraVM", "Examine error", e)
                _uiState.value = _uiState.value.copy(isInferring = false)
            } finally {
                isAnalyzing = false
            }
        }
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
    val isInferring: Boolean = false,
    val currentMessage: String = "",
    val isModelReady: Boolean = false,
    val modelError: String? = null,
)
