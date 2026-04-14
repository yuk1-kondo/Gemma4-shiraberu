import CoreGraphics
import Foundation
import Vision

/// On-device fallback using Apple's built-in Vision image classification.
public final class AppleVisionInferenceService: InferenceServing {
    public private(set) var isModelReady: Bool = false
    public private(set) var lastError: String?
    public let backendDisplayName: String = "Apple Vision"
    public let isUsingFallback: Bool = true

    public init() {}

    public func loadModel() async {
        isModelReady = true
        lastError = nil
    }

    public func examine(frame: CGImage) async throws -> InferenceResult {
        guard isModelReady else { throw InferenceError.modelNotReady }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: InferenceError.runtimeFailure(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation],
                      let top = observations.first else {
                                        continuation.resume(returning: InferenceResult(text: "\u{3042}\u{305F}\u{308A}\u{3092}\u{8ABF}\u{3079}\u{305F}\u{304C}\u{3001}\u{6B63}\u{4F53}\u{306F}\u{307E}\u{3060}\u{898B}\u{3048}\u{306A}\u{3044}\u{2026}\u{3002}"))
                    return
                }

                let top3 = observations.prefix(3).map {
                    "\($0.identifier) (\(Int($0.confidence * 100))%)"
                }
                let text = "\(top.identifier)\u{3089}\u{3057}\u{3044}\u{3082}\u{306E}\u{304C} \u{304A}\u{304B}\u{308C}\u{3066}\u{3044}\u{308B}\u{FF01}\n\u{306A}\u{3093}\u{3068}\u{2026}\u{FF01} \u{898B}\u{8FBC}\u{307F}\u{78BA}\u{7387}: \(Int(top.confidence * 100))%\n\u{5019}\u{88DC}: \(top3.joined(separator: ", "))"
                continuation.resume(returning: InferenceResult(text: text))
            }

            let handler = VNImageRequestHandler(cgImage: frame, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: InferenceError.runtimeFailure(error.localizedDescription))
            }
        }
    }
}
