package com.example.xeye.ui

import androidx.camera.core.CameraControl
import androidx.camera.core.Preview
import androidx.camera.view.PreviewView
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.LifecycleOwner

@Composable
fun CameraPreview(
    preview: Preview,
    lifecycleOwner: LifecycleOwner,
    modifier: Modifier = Modifier,
    cameraControl: CameraControl? = null,
) {
    var zoomRatio by remember { mutableFloatStateOf(1f) }

    AndroidView(
        factory = { context ->
            PreviewView(context).also { previewView ->
                preview.surfaceProvider = previewView.surfaceProvider
            }
        },
        modifier = modifier.pointerInput(cameraControl) {
            detectTransformGestures { _, _, zoom, _ ->
                if (cameraControl == null) return@detectTransformGestures
                zoomRatio = (zoomRatio * zoom).coerceIn(1f, 10f)
                cameraControl.setZoomRatio(zoomRatio)
            }
        }
    )
}
