package com.example.xeye

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.graphics.YuvImage
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.xeye.sound.SoundManager
import com.example.xeye.ui.CameraPreview
import com.example.xeye.ui.ExamineOverlay
import com.example.xeye.ui.XeyeTheme
import com.example.xeye.viewmodel.CameraViewModel
import java.io.ByteArrayOutputStream

class MainActivity : ComponentActivity() {

    private lateinit var viewModel: CameraViewModel
    private lateinit var soundManager: SoundManager
    private var cameraProvider: ProcessCameraProvider? = null
    private var latestBitmap: android.graphics.Bitmap? = null
    private var cameraControl: CameraControl? = null

    private val cameraPermissionRequest = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) requestStorageAndStartCamera()
    }

    private val storagePermissionRequest = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { _ ->
        startCamera()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel = CameraViewModel(application)
        soundManager = SoundManager(this)
        soundManager.init(this)

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            requestStorageAndStartCamera()
        } else {
            cameraPermissionRequest.launch(Manifest.permission.CAMERA)
        }
    }

    private fun requestStorageAndStartCamera() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (Environment.isExternalStorageManager()) {
                startCamera()
            } else {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    storagePermissionRequest.launch(
                        arrayOf(
                            Manifest.permission.READ_MEDIA_IMAGES,
                            Manifest.permission.READ_EXTERNAL_STORAGE
                        )
                    )
                    startCamera()
                } catch (_: Exception) {
                    startCamera()
                }
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)
                == PackageManager.PERMISSION_GRANTED
            ) {
                startCamera()
            } else {
                storagePermissionRequest.launch(
                    arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
                )
            }
        }
    }

    private fun startCamera() {
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            cameraProvider = future.get()
            setContentAfterCameraReady()
        }, mainExecutor)
    }

    private var setContentAfterCameraReady = false

    private fun setContentAfterCameraReady() {
        if (setContentAfterCameraReady) return
        setContentAfterCameraReady = true
        setContent {
            XeyeTheme {
                val uiState by viewModel.uiState.collectAsStateWithLifecycle()
                val lifecycleOwner = LocalLifecycleOwner.current
                val preview = remember { Preview.Builder().build() }

                LaunchedEffect(Unit) {
                    bindCamera(lifecycleOwner, preview)
                }

                Box(modifier = Modifier.fillMaxSize()) {
                    cameraProvider?.let { provider ->
                        CameraPreview(
                            preview = preview,
                            lifecycleOwner = lifecycleOwner,
                            cameraControl = cameraControl,
                            modifier = Modifier.fillMaxSize()
                        )
                    }

                    ExamineOverlay(
                        currentMessage = uiState.currentMessage,
                        isInferring = uiState.isInferring,
                        isModelReady = uiState.isModelReady,
                        modelError = uiState.modelError,
                        onExamine = { onExamine() },
                        onTypeChar = { soundManager.playTypeChar() },
                        onTypeEnd = { soundManager.playTypeEnd() },
                        onDiscovery = { soundManager.playDiscovery() },
                        modifier = Modifier.fillMaxSize()
                    )
                }
            }
        }
    }

    private fun bindCamera(
        owner: androidx.lifecycle.LifecycleOwner,
        preview: Preview
    ) {
        val provider = cameraProvider ?: return
        val imageAnalyzer = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()

        imageAnalyzer.setAnalyzer(mainExecutor) { imageProxy ->
            val bitmap = imageProxyToBitmap(imageProxy)
            imageProxy.close()
            latestBitmap = bitmap
        }

        try {
            provider.unbindAll()
            val camera = provider.bindToLifecycle(owner, CameraSelector.DEFAULT_BACK_CAMERA, preview, imageAnalyzer)
            cameraControl = camera.cameraControl
            Log.i("MainActivity", "Camera bound successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Camera bind error", e)
        }
    }

    private fun onExamine() {
        soundManager.playMenuSelect()
        val bitmap = latestBitmap
        if (bitmap == null) {
            Log.w("MainActivity", "No frame captured yet")
            return
        }
        viewModel.examineFrame(bitmap)
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraProvider?.unbindAll()
        cameraProvider = null
        cameraControl = null
        setContentAfterCameraReady = false
        soundManager.release()
    }

    private fun imageProxyToBitmap(imageProxy: ImageProxy): android.graphics.Bitmap {
        val yBuffer = imageProxy.planes[0].buffer
        val uBuffer = imageProxy.planes[1].buffer
        val vBuffer = imageProxy.planes[2].buffer

        val ySize = yBuffer.remaining()
        val uSize = uBuffer.remaining()
        val vSize = vBuffer.remaining()

        val nv21 = ByteArray(ySize + uSize + vSize)
        yBuffer.get(nv21, 0, ySize)
        vBuffer.get(nv21, ySize, vSize)
        uBuffer.get(nv21, ySize + vSize, uSize)

        val yuvImage = YuvImage(nv21, android.graphics.ImageFormat.NV21, imageProxy.width, imageProxy.height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(android.graphics.Rect(0, 0, imageProxy.width, imageProxy.height), 50, out)
        return BitmapFactory.decodeByteArray(out.toByteArray(), 0, out.size())
    }
}
