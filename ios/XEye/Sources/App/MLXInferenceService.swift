import CoreGraphics
import CoreImage
import Foundation
import HFAPI
import MLXLMCommon
import MLXVLM

public final class MLXInferenceService: InferenceServing {

    public private(set) var isModelReady = false
    public private(set) var lastError: String?
    public let backendDisplayName = "Gemma4 VLM (MLX)"
    public let isUsingFallback = false

    private var container: ModelContainer?

    // Matching Android's VlmInferenceEngine system prompt and user prompt exactly
    private let systemPrompt =
        "あなたはドラゴンクエストの世界の案内人です。"
        + "画像に写っているものを、ドラゴンクエストの「調べる」コマンドのように、"
        + "日本語で描写してください。"
        + "必ず「〇〇が おかれている！」という形式で始めてください。"
        + "その後、2?3行で面白いコメントや感想を添えてください。"
        + "ドラクエスタイルのセリフとして「なんと…！」「おや？」「まさか…」などを使ってください。ただし「フフフ」は多用しないでください。"
        + "合計3?4行で、句点で終わること。"

    private let userPrompt = "この画像に何が写っていますか？ドラゴンクエスト風に答えて。"

    public func loadModel() async {
        do {
            let loaded = try await VLMModelFactory.shared.loadContainer(
                from: HubClient.default,
                using: TokenizersLoader(),
                configuration: VLMRegistry.gemma4_E2B_it_4bit
            ) { progress in
                // Model download progress
            }
            container = loaded
            isModelReady = true
            lastError = nil
        } catch {
            isModelReady = false
            lastError = error.localizedDescription
        }
    }

    public func examine(frame: CGImage) async throws -> InferenceResult {
        guard let container else {
            throw InferenceError.modelNotReady
        }

        let ciImage = CIImage(cgImage: frame)

        // Fresh conversation per call to avoid context pollution (matching Android behavior)
        let userInput = UserInput(
            chat: [
                .system(systemPrompt),
                .user(userPrompt, images: [.ciImage(ciImage)]),
            ]
        )

        let lmInput = try await container.prepare(input: userInput)

        // Matching Android's SamplerConfig: topK=40, topP=0.95, temperature=0.8, maxNumTokens=512
        let params = GenerateParameters(
            maxTokens: 512,
            temperature: 0.8,
            topP: 0.95,
            topK: 40
        )

        let stream = try await container.generate(input: lmInput, parameters: params)

        var result = ""
        for await event in stream {
            if case .chunk(let text) = event {
                result += text
            }
        }

        guard !result.isEmpty else {
            throw InferenceError.runtimeFailure("MLX VLM produced empty output")
        }

        return InferenceResult(text: result)
    }
}
