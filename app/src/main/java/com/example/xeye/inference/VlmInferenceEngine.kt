package com.example.xeye.inference

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.LogSeverity
import com.google.ai.edge.litertlm.SamplerConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

class VlmInferenceEngine(private val context: Context) {

    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var error: String? = null
    private val lock = ReentrantLock()
    private var examinedCount = 0
    @Volatile private var loaded = false

    init {
        Engine.setNativeMinLogSeverity(LogSeverity.WARNING)
    }

    suspend fun loadModelAsync() = withContext(Dispatchers.IO) {
        if (loaded) return@withContext
        loadModel()
    }

    private fun loadModel() {
        try {
            val modelFile = java.io.File(context.filesDir, "gemma4.litertlm")
            Log.d(TAG, "Loading model from: ${modelFile.absolutePath}, size: ${modelFile.length() / 1024 / 1024}MB")

            if (!modelFile.exists()) {
                error = "モデルファイルが見つかりません: ${modelFile.absolutePath}"
                Log.e(TAG, error!!)
                return
            }

            val engineConfig = EngineConfig(
                modelPath = modelFile.absolutePath,
                backend = Backend.CPU(),
                visionBackend = Backend.CPU(),
                maxNumTokens = 512,
                cacheDir = context.cacheDir?.absolutePath ?: "",
            )

            engine = Engine(engineConfig)
            Log.d(TAG, "Initializing engine...")
            engine!!.initialize()
            Log.d(TAG, "Engine initialized")
            loaded = true
            Log.d(TAG, "Model loaded successfully")
        } catch (e: Exception) {
            error = "モデル読み込みエラー: ${e.message}"
            Log.e(TAG, "Failed to load model", e)
        }
    }

    val isModelLoaded: Boolean get() = loaded && engine != null
    val errorMessage: String? get() = error

    suspend fun examine(bitmap: Bitmap): String = withContext(Dispatchers.IO) {
        lock.withLock {
            val currentEngine = engine ?: return@withContext error ?: "モデル未読み込み"

            return@withContext try {
                // Create a fresh conversation for each examine to avoid context pollution
                conversation?.close()

                val conversationConfig = ConversationConfig(
                    systemInstruction = Contents.of(
                        "あなたはドラゴンクエストの世界の案内人です。" +
                        "画像に写っているものを、ドラゴンクエストの「調べる」コマンドのように、" +
                        "日本語で描写してください。" +
                        "必ず「〇〇が おかれている！」という形式で始めてください。" +
                        "その後、2〜3行で面白いコメントや感想を添えてください。" +
                        "ドラクエスタイルのセリフとして「なんと…！」「おや？」「まさか…」などを使ってください。ただし「フフフ」は多用しないでください。" +
                        "合計3〜4行で、句点で終わること。"
                    ),
                    samplerConfig = SamplerConfig(
                        topK = 40,
                        topP = 0.95,
                        temperature = 0.8,
                    ),
                )

                conversation = currentEngine.createConversation(conversationConfig)

                examinedCount++
                val imageBytes = bitmapToJpegBytes(bitmap)
                Log.i(TAG, "Examining frame #$examinedCount, image size: ${imageBytes.size} bytes")

                val response = conversation!!.sendMessage(
                    Contents.of(
                        Content.ImageBytes(imageBytes),
                        Content.Text("この画像に何が写っていますか？ドラゴンクエスト風に答えて。"),
                    )
                )
                val text = response.toString().ifBlank { "何も見つからなかった..." }
                Log.i(TAG, "Response: $text")
                text
            } catch (e: Exception) {
                Log.e(TAG, "Examine error", e)
                "調べることができなかった..."
            }
        }
    }

    private fun bitmapToJpegBytes(bitmap: Bitmap): ByteArray {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 50, stream)
        return stream.toByteArray()
    }

    fun close() {
        lock.withLock {
            try { conversation?.close() } catch (_: Exception) {}
            try { engine?.close() } catch (_: Exception) {}
            conversation = null
            engine = null
            loaded = false
        }
    }

    companion object {
        private const val TAG = "VlmInference"
    }
}
