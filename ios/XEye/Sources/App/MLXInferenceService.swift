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

    // Keep prompts aligned with Android's DQ-style examine instruction
    private let systemPrompt =
        "\u{3042}\u{306A}\u{305F}\u{306F}\u{30C9}\u{30E9}\u{30B4}\u{30F3}\u{30AF}\u{30A8}\u{30B9}\u{30C8}\u{306E}\u{4E16}\u{754C}\u{306E}\u{8A9E}\u{308A}\u{624B}\u{3067}\u{3059}\u{3002}" +
        "\u{753B}\u{50CF}\u{306B}\u{5199}\u{3063}\u{3066}\u{3044}\u{308B}\u{3082}\u{306E}\u{3092}\u{3001}\u{30C9}\u{30E9}\u{30B4}\u{30F3}\u{30AF}\u{30A8}\u{30B9}\u{30C8}\u{306E}\u{300C}\u{8ABF}\u{3079}\u{308B}\u{300D}\u{30B3}\u{30DE}\u{30F3}\u{30C9}\u{306E}\u{3088}\u{3046}\u{306B}\u{3001}\u{65E5}\u{672C}\u{8A9E}\u{3067}\u{63CF}\u{5199}\u{3057}\u{3066}\u{304F}\u{3060}\u{3055}\u{3044}\u{3002}" +
        "\u{5FC5}\u{305A}\u{300C}\u{25EF}\u{25EF}\u{304C} \u{304A}\u{304B}\u{308C}\u{3066}\u{3044}\u{308B}\u{FF01}\u{300D}\u{3068}\u{3044}\u{3046}\u{5F62}\u{3067}\u{59CB}\u{3081}\u{3066}\u{304F}\u{3060}\u{3055}\u{3044}\u{3002}" +
        "\u{305D}\u{306E}\u{5F8C}\u{3001}2\u{301C}3\u{884C}\u{3067}\u{77ED}\u{3044}\u{30B3}\u{30E1}\u{30F3}\u{30C8}\u{3084}\u{611F}\u{60F3}\u{3092}\u{6DFB}\u{3048}\u{3066}\u{304F}\u{3060}\u{3055}\u{3044}\u{3002}" +
        "\u{30C9}\u{30E9}\u{30B4}\u{30F3}\u{30AF}\u{30A8}\u{30B9}\u{30C8}\u{3089}\u{3057}\u{3044}\u{30BB}\u{30EA}\u{30D5}\u{3068}\u{3057}\u{3066}\u{300C}\u{306A}\u{3093}\u{3068}\u{2026}\u{FF01}\u{300D}\u{300C}\u{304A}\u{3084}\u{2026}\u{FF1F}\u{300D}\u{300C}\u{307E}\u{3055}\u{304B}\u{2026}\u{300D}\u{306A}\u{3069}\u{3092}\u{4F7F}\u{3063}\u{3066}\u{304F}\u{3060}\u{3055}\u{3044}\u{3002}" +
        "\u{5168}\u{4F53}\u{3092}3\u{301C}4\u{884C}\u{306B}\u{307E}\u{3068}\u{3081}\u{3001}\u{53E5}\u{70B9}\u{3067}\u{7D42}\u{308F}\u{308B}\u{3088}\u{3046}\u{306B}\u{3057}\u{3066}\u{304F}\u{3060}\u{3055}\u{3044}\u{3002}"

    private let userPrompt =
        "\u{3053}\u{306E}\u{753B}\u{50CF}\u{306B}\u{4F55}\u{304C}\u{5199}\u{3063}\u{3066}\u{3044}\u{307E}\u{3059}\u{304B}\u{FF1F}\u{30C9}\u{30E9}\u{30B4}\u{30F3}\u{30AF}\u{30A8}\u{30B9}\u{30C8}\u{98A8}\u{306B}\u{7B54}\u{3048}\u{3066}\u{3002}"

    public func loadModel() async {
        do {
            let loaded = try await VLMModelFactory.shared.loadContainer(
                from: HubClient.default,
                using: TokenizersLoader(),
                configuration: VLMRegistry.gemma4_E2B_it_4bit
            ) { _ in
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
