import CoreGraphics
import Foundation

/// LiteRT-LM integration scaffold for iOS.
///
/// Current behavior:
/// - Attempts LiteRT runtime initialization.
/// - If unavailable, falls back to the provided inference service.
///
/// Next step for full LiteRT support:
/// - Add Objective-C++ bridge to LiteRT-LM C++ API.
/// - Implement initializeLiteRTRuntimeIfAvailable() and examineWithLiteRT(frame:).
public final class LiteRTInferenceService: InferenceServing {
    public private(set) var isModelReady: Bool = false
    public private(set) var lastError: String?

    public var backendDisplayName: String {
        if litertReady {
            return "LiteRT-LM (iOS)"
        }
        return fallback.backendDisplayName + " (LiteRT fallback)"
    }

    public var isUsingFallback: Bool {
        !litertReady || fallback.isUsingFallback
    }

    private let fallback: InferenceServing
    private var litertReady = false
    private var fallbackLoaded = false
    private let bridge = LiteRTBridge()
    private let fileManager = FileManager.default
    private var activeModelPath: String?
    private let systemPrompt = "You are a Dragon Quest style narrator. Start with '<item> is placed here!' and add 2-3 short lines in Japanese."

    public init(fallback: InferenceServing = MockInferenceService()) {
        self.fallback = fallback
    }

    public func loadModel() async {
        do {
            try initializeLiteRTRuntimeIfAvailable()
            litertReady = true
            isModelReady = true
            lastError = nil
        } catch {
            litertReady = false
            lastError = "LiteRT unavailable: \(error.localizedDescription). Using fallback."

            await fallback.loadModel()
            fallbackLoaded = true
            isModelReady = fallback.isModelReady

            if let fallbackError = fallback.lastError {
                lastError = (lastError ?? "") + " Fallback error: \(fallbackError)"
            }
        }
    }

    public func examine(frame: CGImage) async throws -> InferenceResult {
        guard isModelReady else {
            throw InferenceError.modelNotReady
        }

        if litertReady {
            do {
                return try await examineWithLiteRT(frame: frame)
            } catch {
                lastError = "LiteRT inference failed: \(error.localizedDescription). Falling back."
                await ensureFallbackLoaded()
                if fallback.isModelReady {
                    return try await fallback.examine(frame: frame)
                }
                throw error
            }
        }

        await ensureFallbackLoaded()
        return try await fallback.examine(frame: frame)
    }

    private func initializeLiteRTRuntimeIfAvailable() throws {
        let candidates = modelPathCandidates()
        var errors: [String] = []

        for modelPath in candidates {
            do {
                _ = try bridge.initialize(modelPath: modelPath.path)
                activeModelPath = modelPath.path
                return
            } catch {
                errors.append("\(modelPath.path): \(error.localizedDescription)")
            }
        }

        let searched = candidates.map(\.path).joined(separator: ", ")
        let details = errors.joined(separator: " | ")
        throw InferenceError.runtimeFailure("LiteRT model file not available. Searched: \(searched). Errors: \(details)")
    }

    private func examineWithLiteRT(frame: CGImage) async throws -> InferenceResult {
        let rgba = try makeRGBAFrameBuffer(from: frame)

        let response = try rgba.data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> String? in
            guard bytes.baseAddress != nil else { return nil }
            let payload = Data(bytes)
            return try bridge.examine(
                imageData: payload,
                prompt: systemPrompt,
                width: Int64(rgba.width),
                height: Int64(rgba.height),
                bytesPerRow: Int64(rgba.bytesPerRow)
            )
        }

        if let response,
           !response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            return InferenceResult(text: response)
        }

        throw InferenceError.runtimeFailure("LiteRT returned an empty response")
    }

    private func ensureFallbackLoaded() async {
        guard !fallbackLoaded else { return }
        await fallback.loadModel()
        fallbackLoaded = true
        if !litertReady {
            isModelReady = fallback.isModelReady
        }
    }

    private func modelPathCandidates() -> [URL] {
        var candidates: [URL] = []

        if let bundleURL = Bundle.main.resourceURL {
            candidates.append(bundleURL.appendingPathComponent("gemma4.litertlm"))
            candidates.append(bundleURL.appendingPathComponent("Models/gemma4.litertlm"))
            candidates.append(bundleURL.appendingPathComponent("gemma4e2b.litertlm"))
            candidates.append(bundleURL.appendingPathComponent("Models/gemma4e2b.litertlm"))
        }

        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            candidates.append(documents.appendingPathComponent("gemma4.litertlm"))
            candidates.append(documents.appendingPathComponent("Models/gemma4.litertlm"))
            candidates.append(documents.appendingPathComponent("gemma4e2b.litertlm"))
            candidates.append(documents.appendingPathComponent("Models/gemma4e2b.litertlm"))
        }

        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            candidates.append(appSupport.appendingPathComponent("gemma4.litertlm"))
            candidates.append(appSupport.appendingPathComponent("Models/gemma4.litertlm"))
            candidates.append(appSupport.appendingPathComponent("gemma4e2b.litertlm"))
            candidates.append(appSupport.appendingPathComponent("Models/gemma4e2b.litertlm"))
        }

        var seen = Set<String>()
        return candidates.filter { candidate in
            let inserted = seen.insert(candidate.path).inserted
            return inserted && fileManager.fileExists(atPath: candidate.path)
        }
    }

    private func makeRGBAFrameBuffer(from image: CGImage) throws -> (data: Data, width: Int, height: Int, bytesPerRow: Int) {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = Data(count: bytesPerRow * height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        let drawSucceeded = data.withUnsafeMutableBytes { bytes -> Bool in
            guard let baseAddress = bytes.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard drawSucceeded else {
            throw InferenceError.runtimeFailure("Failed to build RGBA frame for LiteRT")
        }

        return (data: data, width: width, height: height, bytesPerRow: bytesPerRow)
    }

}
