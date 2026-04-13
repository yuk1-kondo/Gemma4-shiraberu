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
                    continuation.resume(returning: InferenceResult(text: "No classification result available."))
                    return
                }

                let top3 = observations.prefix(3).map {
                    "\($0.identifier) (\(Int($0.confidence * 100))%)"
                }
                let text = "Apple Vision inference: \(top.identifier) (\(Int(top.confidence * 100))%)\nCandidates: \(top3.joined(separator: ", "))"
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
