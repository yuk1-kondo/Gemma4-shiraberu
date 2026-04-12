# 鑑定の書 - Gemma 4 ドラクエ風画像認識カメラアプリ

「鑑定の書」は、GoogleのGemma 4をAndroid端末上でローカル動作させ、カメラで撮影したものをAIがドラゴンクエスト風に解説してくれるアプリです。

クラウドAPIを使わず完全オフラインで動作します。

## 特徴

- **Gemma 4 ローカル推論** - LiteRT-LMで端末内で完結。通信不要、プライバシー安全
- **ドラクエ風UI** - 「調べる」ボタン・ターゲティングフレーム・メッセージボックス
- **タイプライター効果** - 1文字ずつ表示されるドラクエ風テキスト演出
- **ドラクエ風効果音** - メニュー選択音・発見音・タイプ音をプログラム生成（音声ファイル不要）
- **オート鑑定** - AUTOボタンで最大3分間自動で連続鑑定
- **レベルシステム** - 鑑定するたびに経験値が溜まり、レベルアップ（永続化対応）
- **プレイヤー名登録** - 最初の起動時またはHUDタップで名前設定
- **ピンチズーム** - カメラのピンチイン/アウトで1x〜10xズーム対応
- **ドット絵アイコン** - ピクセルアート風の宝箱アイコン

## 動作環境

| 項目 | 要件 |
|------|------|
| Android | API 26 (Android 8.0) 以上 |
| モデル | Gemma 4 E2B (`.litertlm`形式) |
| 端末メモリ | モデルファイル約1.5〜2GB |

## ビルド＆インストール

### 必要なもの

- Android Studio（またはGradle CLI）
- Android SDK API 36
- Gemma 4 E2B モデルファイル（`.litertlm`形式）

### 1. モデルの準備

HuggingFace `litert-community` から Gemma 4 E2B の `.litertlm` ファイルをダウンロードします。

モデルを端末のアプリデータディレクトリに配置：

```bash
adb push gemma4.litertlm /data/data/com.example.xeye/files/gemma4.litertlm
```

### 2. ビルド

```bash
# Android Studioからビルドする場合
# Build > Build Bundle(s) / APK(s) > Build APK(s)

# CLIからビルドする場合
./gradlew assembleDebug
```

生成されるAPK: `app/build/outputs/apk/debug/app-debug.apk`

### 3. インストール

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

### 4. アプリの操作

1. カメラのpermissionを許可
2. 名前を登録（初回起動時 or HUDタップでいつでも変更可能）
3. モデル読み込み完了まで待つ
4. ターゲティングフレーム内に対象を入れて「調べる」をタップ
5. AIがドラクエ風のセリフで解説
6. AUTOボタンで最大3分間の連続鑑定

## アプリの画面構成

```
┌─────────────────────────────────┐
│ [Lv.1 鑑定見習い]              │ ← レベルHUD（タップで名前変更）
│ [XPバー] 0/100                 │
│                                 │
│       ┌──────────┐             │
│       │  ┌────┐  │             │ ← ターゲティングフレーム
│       │  │    │  │             │    （調べ中はゴールド点滅）
│       │  └────┘  │             │
│       └──────────┘             │
│                                 │
│         [ 調べる ]              │ ← 鑑定ボタン（脈動アニメ）
│                                 │
│ ┌─────────────────────────┐     │
│ │ 〇〇がおかれている！      │     │ ← ドラクエ風メッセージボックス
│ │ なんと！すごい発見だ…！  │     │
│ └─────────────────────────┘     │
│                          [AUTO] │ ← オート鑑定トグル
└─────────────────────────────────┘
```

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
| SharedPreferences | - | レベル・名前の永続化 |

## プロジェクト構成

```
app/src/main/java/com/example/xeye/
├── MainActivity.kt                  # エントリポイント。カメラバインド・Compose UI構成
├── inference/
│   └── VlmInferenceEngine.kt        # Gemma 4 モデルのロード・画像解析エンジン
├── viewmodel/
│   └── CameraViewModel.kt           # UI状態管理。モデル呼び出し・オート鑑定・レベル管理
├── progress/
│   └── ProgressStore.kt             # レベル・経験値・名前の永続化（SharedPreferences）
├── ui/
│   ├── Theme.kt                     # ドラクエ風カラースキーマ・タイポグラフィ
│   ├── CameraPreview.kt             # CameraX プレビュー表示＋ピンチズーム
│   └── ExamineOverlay.kt            # 調べるボタン・ターゲティングフレーム・メッセージボックス・名前入力
└── sound/
    └── SoundManager.kt              # プログラム生成による効果音再生
```

## 各ファイルの解説

### VlmInferenceEngine.kt - AI推論エンジン

アプリのコア。GoogleのLiteRT-LM SDKを使ってGemma 4モデルをローカルで動かします。

- `Backend.CPU()` で推論を実行。`visionBackend = Backend.CPU()` で画像認識
- `maxNumTokens = 512` でドラクエ風の3〜4行テキストを生成
- モデルファイルは `context.filesDir/gemma4.litertlm` に配置
- 毎回新しい `Conversation` を作成してコンテキスト汚染を防止
- `Content.ImageBytes` で画像をBase64なしで直接渡す
- システムプロンプトで「〇〇が おかれている！」形式 + ドラクエ風セリフを指定
- 画像は512x512に縮小・JPEG品質50%で推論前に最適化
- `ReentrantLock` で並行実行を防止

### CameraViewModel.kt - UI状態管理

MVVMパターンのViewModel。モデル推論とUIの仲介を行います。

- `examineFrame(bitmap)` - Bitmapを90度回転→512x512縮小→推論エンジンに渡す
- `toggleAutoExamine()` - 3分間の自動連続鑑定（コルーチンで管理）
- `setPlayerName()` / `clearLevelUpFlag()` - プレイヤー名・レベルアップ状態管理
- `ProgressStore` からレベル情報を読み取り、`XeyeUiState` に反映

### ProgressStore.kt - レベル・進捗の永続化

`SharedPreferences` でプレイヤーデータを永続化します。

- **経験値計算**: `Lv^3 × 100`（累積）。Lv.99到達には約177年（1日100回鑑定）
- **99段階の称号**: 鑑定見習い → 駆け出し鑑定士 → ... → 全知全能の鑑定神
- 1回の鑑定で15XP獲得
- `commit()` で同期的に書き込み（データ消失防止）

### MainActivity.kt - エントリポイント

カメラの初期化・パーミッション管理・Compose UIの構成を担当します。

- `ImageAnalysis` でフレームを継続取得し、`latestBitmap` に最新フレームを保持
- 「調べる」ボタン押下時に `latestBitmap` をViewModelに渡す（オンデマンド方式）
- `cameraControl` をCameraPreviewに渡してピンチズームを有効化
- YUV_420_888 → NV21 → JPEG → Bitmap変換でフレームを取得

### ExamineOverlay.kt - ドラクエ風UI

Composeで作られたオーバーレイUIです。

- **ターゲティングフレーム** - 四隅コーナーフレーム + 十字マーク。調べ中はゴールド点滅
- **「調べる」ボタン** - 脈動アニメ（scale 1.0 ↔ 1.03）、ゴールドテキスト
- **タイプライター効果** - 1文字40ms間隔で表示 + タイプ音同期。完了後8秒待機してオート鑑定再トリガー
- **メッセージボックス（DqMessageBox）** - 深い紺背景（`#0D0D2B`）に白い太枠線
- **名前入力ダイアログ** - 初回起動時自動表示。ドラクエ風カラースキーム
- **レベルアップポップアップ** - 3秒間ゴールドバッジで表示
- **AUTOトグル** - 右下に配置、ON時ゴールド点滅
- **レベルHUD** - 左上にレベル・称号・XPバー・累計鑑定数を表示（タップで名前変更）

### CameraPreview.kt - カメラプレビュー＆ズーム

`detectTransformGestures` でピンチジェスチャーを検出し、`CameraControl.setZoomRatio()` で1x〜10xズーム。

### SoundManager.kt - 効果音生成

外部音声ファイルを使わず、`AudioTrack` でプログラム的にサイン波を生成。減衰エンベロープ付き。

| 効果音 | 周波数 | タイミング |
|--------|--------|-----------|
| `playMenuSelect()` | 880Hz → 1320Hz | 「調べる」ボタン押下時 |
| `playDiscovery()` | 523→659→784→1047Hz | AI応答表示時（ファンファーレ） |
| `playTypeChar()` | 1200Hz / 15ms | 1文字表示時（8msレート制限） |
| `playTypeEnd()` | 800Hz / 50ms | 全文字表示完了時 |

### Theme.kt - ドラクエ風テーマ

`FontFamily.Monospace` で全テキストを等幅フォントに統一。ゴールド/ロイヤルブルー/深紺のカラーパレット。

## レベルシステム

| Lv | 称号 | 必要XP(累積) |
|----|------|-------------|
| 1 | 鑑定見習い | 0 |
| 2 | 駆け出し鑑定士 | 800 |
| 5 | 特級鑑定士 | 12,500 |
| 10 | 大鑑定師 | 100,000 |
| 20 | 鑑定の覇王 | 800,000 |
| 30 | 鑑定の権威 | 2,700,000 |
| 50 | 宇宙の鑑定師 | 12,500,000 |
| 70 | 無限の鑑定士 | 34,300,000 |
| 99 | 全知全能の鑑定神 | 97,029,900 |

計算式: `Lv^3 × 100`（累積XP）

## 注意事項

### Kotlinメタデータ互換性

LiteRT-LM 0.10.0はKotlin 2.3.0のメタデータでコンパイルされていますが、本プロジェクトではKotlin 2.1.0を使用しています。このバイナリ互換性問題は以下のコンパイラフラグで回避しています。

```kotlin
// app/build.gradle.kts
kotlinOptions {
    jvmTarget = "11"
    freeCompilerArgs += listOf("-Xskip-metadata-version-check")
}
```

### ビジョン推論の安定性

`visionBackend = Backend.CPU()` はKotlin 2.1.0 + skip-metadataの組み合わせでSIGSEGVが発生する可能性があります。問題が起きた場合は `visionBackend` の設定を外してください。

### モデルの配置先

モデルはアプリのfilesDirに配置する必要があります。adbで配置する場合：

```bash
adb push gemma4.litertlm /data/data/com.example.xeye/files/gemma4.litertlm
```

## ライセンス

MIT License
