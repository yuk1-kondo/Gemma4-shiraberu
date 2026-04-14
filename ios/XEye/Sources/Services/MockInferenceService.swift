import CoreGraphics
import Foundation

public final class MockInferenceService: InferenceServing {
    public private(set) var isModelReady: Bool = false
    public private(set) var lastError: String?
    public let backendDisplayName: String = "Mock"
    public let isUsingFallback: Bool = true

    public init() {}

    public func loadModel() async {
        try? await Task.sleep(nanoseconds: 400_000_000)
        isModelReady = true
    }

    public func examine(frame: CGImage) async throws -> InferenceResult {
        guard isModelReady else { throw InferenceError.modelNotReady }
        try await Task.sleep(nanoseconds: 600_000_000)

        let prompts = [
            "\u{9ED2}\u{3044}\u{307E}\u{306A}\u{3056}\u{3057}\u{306E}\u{5148}\u{306B}\u{3001}\u{56DB}\u{89D2}\u{3044}\u{9053}\u{5177}\u{304C} \u{304A}\u{304B}\u{308C}\u{3066}\u{3044}\u{308B}\u{FF01}\n\u{306A}\u{3093}\u{3068}\u{2026}\u{FF01} \u{624B}\u{306B}\u{306A}\u{3058}\u{3080}\u{5C0F}\u{3055}\u{306A}\u{6A5F}\u{68B0}\u{306E}\u{3088}\u{3046}\u{3060}\u{3002}\n\u{8A18}\u{9332}: \u{63A2}\u{7D22}\u{306E}\u{65C5}\u{306B}\u{5F79}\u{7ACB}\u{3061}\u{305D}\u{3046}\u{306A}\u{767A}\u{898B}\u{3060}\u{3002}",
            "\u{8584}\u{660E}\u{304B}\u{308A}\u{306E}\u{90E8}\u{5C4B}\u{306B}\u{3001}\u{3044}\u{304F}\u{3064}\u{3082}\u{306E}\u{5BB6}\u{5177}\u{304C} \u{304A}\u{304B}\u{308C}\u{3066}\u{3044}\u{308B}\u{FF01}\n\u{304A}\u{3084}\u{2026}\u{FF1F} \u{4EBA}\u{306E}\u{6C17}\u{914D}\u{306F}\u{306A}\u{3044}\u{304C}\u{3001}\u{751F}\u{6D3B}\u{306E}\u{8DE1}\u{304C}\u{6FC3}\u{3044}\u{3002}\n\u{8A18}\u{9332}: \u{3072}\u{3068}\u{3084}\u{3059}\u{307F}\u{306B}\u{4F3C}\u{305F}\u{7A7A}\u{9593}\u{3068}\u{898B}\u{305F}\u{3002}",
            "\u{7DD1}\u{306E}\u{606F}\u{5439}\u{3092}\u{307E}\u{3068}\u{3044}\u{3057}\u{3082}\u{306E}\u{304C}\u{3001}\u{305D}\u{3053}\u{306B} \u{304A}\u{304B}\u{308C}\u{3066}\u{3044}\u{308B}\u{FF01}\n\u{307E}\u{3055}\u{304B}\u{2026} \u{690D}\u{7269}\u{304B}\u{3001}\u{3042}\u{308B}\u{3044}\u{306F}\u{81EA}\u{7136}\u{306E}\u{65AD}\u{7247}\u{304B}\u{3082}\u{3057}\u{308C}\u{306A}\u{3044}\u{3002}\n\u{8A18}\u{9332}: \u{547D}\u{306E}\u{533F}\u{3044}\u{3092}\u{611F}\u{3058}\u{308B}\u{767A}\u{898B}\u{3060}\u{3002}"
        ]
        return InferenceResult(text: prompts.randomElement()!)
    }
}
