# 鑑定の書 - Gemma 4 画像認識カメラアプリ

「鑑定の書」は、GoogleのGemma 4をAndroid端末上でローカル動作させ、カメラで撮影したものをAIがドラゴンクエスト風に解説してくれるアプリです。

クラウドAPIを使わず完全オフラインで動作します。

## 特徴

- **Gemma 4 ローカル推論** - LiteRT-LMで端末内で完結。通信不要、プライバシー安全
- **ドラクエ風UI** - 「調べる」ボタンで対象を鑑定。結果はタイプライター効果で表示
- **ドラクエ風効果音** - メニュー選択音・発見音・タイプ音をプログラム生成
- **ピンチズーム** - カメラのピンチイン/アウトで1x〜10xズーム対応
- **ビジョン推論** - 画像を直接AIに読み込ませ、何が写っているかを認識

## スクリーンショット

| カメラプレビュー | 鑑定結果 |
|:---:|:---:|
| カメラ映像に「調べる」ボタンが重畳表示 | AIがドラクエ風に解説テキストを表示 |

## 動作環境

| 項目 | 要件 |
|------|------|
| Android | API 26 (Android 8.0) 以上 |
| モデル | Gemma 4 E2B (`.litertlm`形式) |
| メモリ | モデルファイル約1.5〜2GB |

## 使い方

### 1. モデルの準備

HuggingFace `litert-community` から Gemma 4 E2B の `.litertlm` ファイルをダウンロードし、端末に配置します。

```bash
# モデルを端末のアプリデータディレクトリに配置
adb push gemma4.litertlm /data/data/com.example.xeye/files/gemma4.litertlm
```

### 2. ビルド＆インストール

```bash
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

### 3. アプリの操作

1. カメラの permission を許可
2. モデル読み込みが完了するまで待つ
3. カメラを対象に向けて「調べる」ボタンをタップ
4. AIがドラクエ風のセリフで解説を表示

## 技術スタック

| 技術 | バージョン | 用途 |
|------|-----------|------|
| Kotlin | 2.1.0 | 言語 |
| AGP | 8.13.2 | Android Gradle Plugin |
| Jetpack Compose | BOM 2024.12.01 | UIフレームワーク |
| Material 3 | BOM経由 | UIコンポーネント |
| CameraX | 1.4.1 | カメラ制御 |
| LiteRT-LM | 0.10.0 | Gemma 4 推論エンジン |
| Coroutines | 1.9.0 | 非同期処理 |

## プロジェクト構成

```
app/src/main/java/com/example/xeye/
├── MainActivity.kt              # エントリポイント。カメラバインド・Compose UI構成
├── inference/
│   └── VlmInferenceEngine.kt    # Gemma 4 モデルのロード・画像解析エンジン
├── viewmodel/
│   └── CameraViewModel.kt       # UI状態管理。モデル呼び出しを仲介
├── ui/
│   ├── Theme.kt                 # ドラクエ風カラースキーマ・タイポグラフィ
│   ├── CameraPreview.kt         # CameraX プレビュー表示＋ピンチズーム
│   └── ExamineOverlay.kt        # 「調べる」ボタン・メッセージボックス・タイプライター
└── sound/
    └── SoundManager.kt          # プログラム生成による効果音再生
```

## コード説明

### VlmInferenceEngine.kt - AI推論エンジン

アプリのコア。GoogleのLiteRT-LM SDKを使ってGemma 4モデルをローカルで動かします。

**モデルのロード**

```kotlin
val engineConfig = EngineConfig(
    modelPath = modelFile.absolutePath,
    backend = Backend.CPU(),
    visionBackend = Backend.CPU(),  // 画像認識用バックエンド
    maxNumTokens = 512,             // 生成トークン上限（3〜4行のレスポンス用）
    cacheDir = context.cacheDir?.absolutePath ?: "",
)
engine = Engine(engineConfig)
engine!!.initialize()
```

- `Backend.CPU()` - CPUで推論を実行
- `maxNumTokens = 512` - ドラクエ風の3〜4行テキストを生成するのに十分な量
- モデルファイルは `context.filesDir/gemma4.litertlm` に配置

**画像解析（examine）**

```kotlin
val conversationConfig = ConversationConfig(
    systemInstruction = Contents.of(
        "あなたはドラゴンクエストの世界の案内人です。..."  // ドラクエ風のシステムプロンプト
    ),
    samplerConfig = SamplerConfig(topK = 40, topP = 0.95, temperature = 0.8),
)
conversation = currentEngine.createConversation(conversationConfig)

val response = conversation!!.sendMessage(
    Contents.of(
        Content.ImageBytes(imageBytes),   // JPEG画像を直接送信
        Content.Text("この画像に何が写っていますか？"),
    )
)
```

- 毎回新しい `Conversation` を作成 - コンテキスト汚染を防ぐため
- `Content.ImageBytes` で画像をBase64なしで直接渡す
- システムプロンプトで「〇〇が おかれている！」形式とドラクエ風セリフを指定
- `temperature = 0.8` で適度なランダム性を付与
- `ReentrantLock` で並行実行を防止

### CameraViewModel.kt - UI状態管理

MVVMパターンのViewModel。モデル推論とUIの仲介を行います。

```kotlin
data class XeyeUiState(
    val isInferring: Boolean = false,    // 推論中フラグ
    val currentMessage: String = "",     // AI応答テキスト
    val isModelReady: Boolean = false,   // モデル読み込み完了フラグ
    val modelError: String? = null,      // エラーメッセージ
)
```

- `examineFrame(bitmap)` - 「調べる」ボタン押下時に呼ばれ、Bitmapを90度回転して推論エンジンに渡す
- `StateFlow<XeyeUiState>` でCompose UIにリアクティブに状態を通知
- `isAnalyzing` フラグで連続タップ防止

### MainActivity.kt - アプリのエントリポイント

カメラの初期化・パーミッション管理・Compose UIの構成を担当します。

**カメラのバインド**

```kotlin
val camera = provider.bindToLifecycle(owner, CameraSelector.DEFAULT_BACK_CAMERA, preview, imageAnalyzer)
cameraControl = camera.cameraControl
```

- `ImageAnalysis` でフレームを継続取得し、`latestBitmap` に最新フレームを保持
- 「調べる」ボタン押下時に `latestBitmap` をViewModelに渡す（オンデマンド方式）
- `cameraControl` をCameraPreviewに渡してピンチズームを有効化
- YUV_420_888 → NV21 → JPEG → Bitmap変換でフレームを取得

### ExamineOverlay.kt - ドラクエ風UI

Composeで作られたドラクエ風のオーバーレイUIです。

**「調べる」ボタン**
- 画面中央に配置された白枠・深紺背景のボタン
- `infiniteRepeatable` アニメーションで脈動効果（scale 1.0 ↔ 1.03）
- ゴールド色の「調べる」テキスト

**タイプライター効果**
```kotlin
LaunchedEffect(currentMessage) {
    currentMessage.forEachIndexed { index, _ ->
        delay(40)  // 1文字40msで表示
        displayedText.value = currentMessage.substring(0, index + 1)
        onTypeChar()  // タイプ音再生
    }
    onTypeEnd()  // 終了音再生
}
```

- `lastMessage` で前回のメッセージと比較し、変更時のみ再トリガー
- 1文字ずつ40ms間隔で表示 + タイプ音同期

**メッセージボックス（DqMessageBox）**
- 深い紺背景（`#0D0D2B`）に白い太枠線のドラクエ風テキストボックス
- Monospaceフォントでレトロな印象

### CameraPreview.kt - カメラプレビュー＆ズーム

CameraXの `PreviewView` をComposeに埋め込み、ピンチズームを処理します。

```kotlin
modifier.pointerInput(cameraControl) {
    detectTransformGestures { _, _, zoom, _ ->
        zoomRatio = (zoomRatio * zoom).coerceIn(1f, 10f)
        cameraControl.setZoomRatio(zoomRatio)
    }
}
```

- `detectTransformGestures` でピンチジェスチャーを検出
- `CameraControl.setZoomRatio()` で光学/デジタルズームを制御
- 1x〜10xの範囲でズーム可能

### SoundManager.kt - 効果音生成

外部音声ファイルを使わず、`AudioTrack` でプログラム的に効果音を生成します。

```kotlin
private fun playTone(frequency: Float, durationMs: Int, delaySec: Float) {
    val sampleRate = 44100
    val numSamples = (durationMs * sampleRate / 1000).toInt()
    val buffer = ShortArray(numSamples)
    for (i in 0 until numSamples) {
        val t = i.toDouble() / sampleRate
        val envelope = 1.0 - (i.toDouble() / numSamples)  // 減衰エンベロープ
        buffer[i] = (Math.sin(2.0 * Math.PI * frequency * t) * 16000 * envelope).toInt().toShort()
    }
    // AudioTrackで再生
}
```

| 効果音 | 周波数 | 説明 |
|--------|--------|------|
| `playMenuSelect()` | 880Hz → 1320Hz | 「調べる」ボタン押下時の上昇音 |
| `playDiscovery()` | 523→659→784→1047Hz | AI応答表示時のファンファーレ（C-E-G-Cアルペジオ） |
| `playTypeChar()` | 1200Hz / 15ms | 1文字表示時の短い打鍵音（8msレート制限付き） |
| `playTypeEnd()` | 800Hz / 50ms | 全文字表示完了時の終了音 |

### Theme.kt - ドラクエ風テーマ

```kotlin
private val DqColorScheme = darkColorScheme(
    primary = Color(0xFFFFD700),        // ゴールド
    secondary = Color(0xFF4169E1),      // ロイヤルブルー
    surface = Color(0xFF0D0D2B),        // 深い紺
    surfaceVariant = Color(0xFF1A1A2E), // 暗い紺
)
```

- `FontFamily.Monospace` で全テキストをレトロな等幅フォントに統一
- ドラクエのカラーパレットをMaterial 3のカラースキーマにマッピング

## Kotlinメタデータ互換性について

LiteRT-LM 0.10.0はKotlin 2.3.0のメタデータでコンパイルされていますが、本プロジェクトではKotlin 2.1.0を使用しています。このバイナリ互換性問題は以下のコンパイラフラグで回避しています。

```kotlin
// app/build.gradle.kts
kotlinOptions {
    jvmTarget = "11"
    freeCompilerArgs += listOf("-Xskip-metadata-version-check")
}
```

## ライセンス

MIT License
