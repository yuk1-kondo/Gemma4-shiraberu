import CoreGraphics
import Foundation

public struct InferenceResult: Equatable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

@MainActor
public protocol InferenceServing {
    var isModelReady: Bool { get }
    var lastError: String? { get }
    var backendDisplayName: String { get }
    var isUsingFallback: Bool { get }
    func loadModel() async
    func examine(frame: CGImage) async throws -> InferenceResult
}

public enum InferenceError: Error {
    case modelNotReady
    case runtimeFailure(String)
}
