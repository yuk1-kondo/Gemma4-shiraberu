import CoreGraphics
import CoreML
import Foundation
import Vision

/// Core ML backed inference service for on-device Gemma4 image inference.
/// It expects a compiled model named `Gemma4Vision.mlmodelc` in the app bundle.
public final class GemmaCoreMLInferenceService: InferenceServing {
    public private(set) var isModelReady: Bool = false
    public private(set) var lastError: String?
    public let backendDisplayName: String = "Gemma4 Core ML"
    public let isUsingFallback: Bool = false

    private let modelName: String
    private let bundle: Bundle
    private let vocabResourceName: String
    private let vocabExtension: String
    private let fileManager = FileManager.default
    private var tokenDecoder: GemmaTokenDecoder?
    private var visionModel: VNCoreMLModel?

    public init(
        modelName: String = "Gemma4Vision",
        bundle: Bundle = .main,
        vocabResourceName: String = "gemma_vocab",
        vocabExtension: String = "json"
    ) {
        self.modelName = modelName
        self.bundle = bundle
        self.vocabResourceName = vocabResourceName
        self.vocabExtension = vocabExtension
        self.tokenDecoder = nil
    }

    public func loadModel() async {
        do {
            let url = try resolveModelURL()
            tokenDecoder = makeTokenDecoder()

            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all

            let coreMLModel = try MLModel(contentsOf: url, configuration: configuration)
            visionModel = try VNCoreMLModel(for: coreMLModel)
            isModelReady = true
            lastError = nil
        } catch {
            isModelReady = false
            if let inferenceError = error as? InferenceError {
                lastError = description(for: inferenceError)
            } else {
                lastError = "Gemma4 model load failed: \(error.localizedDescription)"
            }
        }
    }

    public func examine(frame: CGImage) async throws -> InferenceResult {
        guard isModelReady, let model = visionModel else {
            throw InferenceError.modelNotReady
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error {
                    continuation.resume(throwing: InferenceError.runtimeFailure(error.localizedDescription))
                    return
                }

                if let classifications = request.results as? [VNClassificationObservation],
                   let top = classifications.first {
                    continuation.resume(returning: InferenceResult(text: "\(top.identifier) (\(Int(top.confidence * 100))%)"))
                    return
                }

                if let features = request.results as? [VNCoreMLFeatureValueObservation] {
                    if let text = Self.decodeText(from: features) {
                        continuation.resume(returning: InferenceResult(text: text))
                        return
                    }

                    if let summary = self.decodeNumericSummary(from: features) {
                        continuation.resume(returning: InferenceResult(text: summary))
                        return
                    }
                }

                continuation.resume(throwing: InferenceError.runtimeFailure("Unexpected model output format"))
            }

            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: frame, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: InferenceError.runtimeFailure(error.localizedDescription))
            }
        }
    }

    private static func decodeText(from features: [VNCoreMLFeatureValueObservation]) -> String? {
        for feature in features {
            if feature.featureValue.type == .string {
                let text = feature.featureValue.stringValue
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return text
                }
            }
        }
        return nil
    }

    private func decodeNumericSummary(from features: [VNCoreMLFeatureValueObservation]) -> String? {
        return Self.decodeNumericSummary(from: features, tokenDecoder: tokenDecoder)
    }

    private static func decodeNumericSummary(
        from features: [VNCoreMLFeatureValueObservation],
        tokenDecoder: GemmaTokenDecoder?
    ) -> String? {
        for feature in features {
            if feature.featureValue.type == .multiArray,
               let array = feature.featureValue.multiArrayValue {
                if let decoded = tokenDecoder?.decode(array: array) {
                    return decoded
                }

                let count = min(array.count, 8)
                guard count > 0 else { continue }

                var values: [String] = []
                values.reserveCapacity(count)

                for i in 0..<count {
                    values.append(String(format: "%.3f", array[i].doubleValue))
                }

                return "Model logits preview: [\(values.joined(separator: ", "))]"
            }
        }

        return nil
    }

    private func description(for error: InferenceError) -> String {
        switch error {
        case .modelNotReady:
            return "Model not ready"
        case .runtimeFailure(let message):
            return message
        }
    }

    private func resolveModelURL() throws -> URL {
        let candidates = modelCandidateURLs()

        if let compiledURL = candidates.first(where: { fileManager.fileExists(atPath: $0.path) && $0.pathExtension == "mlmodelc" }) {
            return compiledURL
        }

        if let rawModelURL = candidates.first(where: {
            fileManager.fileExists(atPath: $0.path) && ($0.pathExtension == "mlmodel" || $0.pathExtension == "mlpackage")
        }) {
            return try compileModel(at: rawModelURL)
        }

        let searchedPaths = candidates.map(\.path).joined(separator: ", ")
        throw InferenceError.runtimeFailure("Gemma4 model not found. Place \(modelName).mlmodelc, \(modelName).mlpackage, or \(modelName).mlmodel in the app bundle, Files/XEyeApp, or Files/XEyeApp/Models. Searched: \(searchedPaths)")
    }

    private func modelCandidateURLs() -> [URL] {
        var urls: [URL] = []

        if let bundleResourceURL = bundle.resourceURL {
            urls.append(bundleResourceURL.appendingPathComponent("\(modelName).mlmodelc", isDirectory: true))
            urls.append(bundleResourceURL.appendingPathComponent("\(modelName).mlpackage", isDirectory: true))
            urls.append(bundleResourceURL.appendingPathComponent("\(modelName).mlmodel"))
        }

        for directory in externalSearchDirectories() {
            urls.append(directory.appendingPathComponent("\(modelName).mlmodelc", isDirectory: true))
            urls.append(directory.appendingPathComponent("\(modelName).mlpackage", isDirectory: true))
            urls.append(directory.appendingPathComponent("\(modelName).mlmodel"))
        }

        return deduplicated(urls)
    }

    private func externalSearchDirectories() -> [URL] {
        var directories: [URL] = []

        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            directories.append(documentsURL)
            directories.append(documentsURL.appendingPathComponent("Models", isDirectory: true))
        }

        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            directories.append(appSupportURL)
            directories.append(appSupportURL.appendingPathComponent("Models", isDirectory: true))
        }

        return deduplicated(directories)
    }

    private func compileModel(at sourceURL: URL) throws -> URL {
        let compiledCacheRoot = try compiledModelCacheRoot()
        let destinationURL = compiledCacheRoot.appendingPathComponent("\(modelName).mlmodelc", isDirectory: true)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        let compiledURL = try MLModel.compileModel(at: sourceURL)
        try fileManager.copyItem(at: compiledURL, to: destinationURL)
        return destinationURL
    }

    private func compiledModelCacheRoot() throws -> URL {
        let root = try fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            .unwrap(or: InferenceError.runtimeFailure("Application Support directory is unavailable"))
            .appendingPathComponent("CompiledModels", isDirectory: true)

        if !fileManager.fileExists(atPath: root.path) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }

        return root
    }

    private func makeTokenDecoder() -> GemmaTokenDecoder? {
        let candidates = vocabCandidateURLs()
        guard let vocabURL = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return nil
        }

        return try? GemmaTokenDecoder(vocabURL: vocabURL)
    }

    private func vocabCandidateURLs() -> [URL] {
        var urls: [URL] = []

        if let bundleResourceURL = bundle.resourceURL {
            urls.append(bundleResourceURL.appendingPathComponent("\(vocabResourceName).\(vocabExtension)"))
        }

        for directory in externalSearchDirectories() {
            urls.append(directory.appendingPathComponent("\(vocabResourceName).\(vocabExtension)"))
        }

        return deduplicated(urls)
    }

    private func deduplicated(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.path).inserted }
    }
}

public final class FallbackInferenceService: InferenceServing {
    private var usedFallbackForLastInference = false

    public var backendDisplayName: String {
        if primary.isModelReady && !usedFallbackForLastInference {
            return primary.backendDisplayName
        }
        return fallback.backendDisplayName
    }

    public var isUsingFallback: Bool {
        !primary.isModelReady || usedFallbackForLastInference
    }

    public var isModelReady: Bool {
        primary.isModelReady || fallback.isModelReady
    }

    public var lastError: String? {
        if let primaryError = primary.lastError {
            return "Gemma4 unavailable. Using \(fallback.backendDisplayName). \(primaryError)"
        }

        return fallback.lastError
    }

    private let primary: InferenceServing
    private let fallback: InferenceServing

    public init(primary: InferenceServing, fallback: InferenceServing) {
        self.primary = primary
        self.fallback = fallback
    }

    public func loadModel() async {
        await primary.loadModel()
        usedFallbackForLastInference = !primary.isModelReady
        if primary.isModelReady {
            return
        }

        await fallback.loadModel()
    }

    public func examine(frame: CGImage) async throws -> InferenceResult {
        if primary.isModelReady {
            do {
                usedFallbackForLastInference = false
                return try await primary.examine(frame: frame)
            } catch {
                usedFallbackForLastInference = true
                return try await fallback.examine(frame: frame)
            }
        }

        usedFallbackForLastInference = true
        return try await fallback.examine(frame: frame)
    }
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> Error) throws -> Wrapped {
        guard let value = self else {
            throw error()
        }
        return value
    }
}
