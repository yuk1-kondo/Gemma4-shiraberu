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
            "A hand-held object with rectangular shape, likely a phone or small device.",
            "An indoor scene with furniture and soft light, likely a living space.",
            "Natural texture and green tones detected, likely a plant or outdoor element."
        ]
        return InferenceResult(text: prompts.randomElement()!)
    }
}
