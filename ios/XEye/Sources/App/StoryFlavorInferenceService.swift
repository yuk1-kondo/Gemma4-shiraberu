import CoreGraphics
import Foundation
import FoundationModels

public final class StoryFlavorInferenceService: InferenceServing {
    public var isModelReady: Bool {
        base.isModelReady
    }

    public var lastError: String? {
        if let narrativeError {
            if let baseError = base.lastError {
                return baseError + " | " + narrativeError
            }
            return narrativeError
        }
        return base.lastError
    }

    public var backendDisplayName: String {
        if usedAppleIntelligence {
            return base.backendDisplayName + " + Apple Intelligence"
        }
        if appleIntelligenceAvailable == false {
            return base.backendDisplayName + " + Story Formatter"
        }
        return base.backendDisplayName
    }

    public var isUsingFallback: Bool {
        base.isUsingFallback
    }

    private let base: InferenceServing
    private var appleIntelligenceAvailable: Bool?
    private var usedAppleIntelligence = false
    private var narrativeError: String?

    public init(base: InferenceServing) {
        self.base = base
    }

    public func loadModel() async {
        await base.loadModel()
        appleIntelligenceAvailable = await Self.isAppleIntelligenceAvailable()
        if appleIntelligenceAvailable == false {
            narrativeError = "Apple Intelligence unavailable. Using local story formatter."
        } else {
            narrativeError = nil
        }
    }

    public func examine(frame: CGImage) async throws -> InferenceResult {
        let baseResult = try await base.examine(frame: frame)
        let flavoredText = await transformToAdventureNarration(baseResult.text)
        return InferenceResult(text: flavoredText)
    }

    private func transformToAdventureNarration(_ sourceText: String) async -> String {
        if #available(iOS 26.0, *), await Self.isAppleIntelligenceAvailable() {
            do {
                let generated = try await Self.generateNarrationWithAppleIntelligence(for: sourceText)
                let cleaned = generated.trimmingCharacters(in: .whitespacesAndNewlines)
                if let normalized = Self.normalizeNarration(cleaned, sourceText: sourceText) {
                    usedAppleIntelligence = true
                    narrativeError = nil
                    return normalized
                }
                narrativeError = "Apple Intelligence output did not match the required format. Using strict local formatter."
            } catch {
                narrativeError = "Apple Intelligence generation failed: \(error.localizedDescription)"
            }
        }

        usedAppleIntelligence = false
        return Self.makeFallbackNarration(from: sourceText)
    }

    @available(iOS 26.0, *)
    private static func makeLanguageModelSession() -> LanguageModelSession {
        let model = SystemLanguageModel(
            useCase: .general,
            guardrails: .default
        )
        return LanguageModelSession(
            model: model,
            instructions: [
                "You are a strict Japanese fantasy game narrator.",
                "Rewrite the observation into Dragon Quest style Japanese.",
                "Output exactly 3 lines.",
                "Line 1 must start with: \u{767A}\u{898B}:",
                "Line 2 must start with: \u{6B63}\u{4F53}:",
                "Line 3 must start with: \u{8A18}\u{9332}:",
                "Do not output anything except those 3 lines.",
                "No markdown, no bullets, no emojis, no extra commentary.",
                "Keep each line short and concrete."
            ].joined(separator: " ")
        )
    }

    @available(iOS 26.0, *)
    private static func generateNarrationWithAppleIntelligence(for sourceText: String) async throws -> String {
        let response = try await makeLanguageModelSession().respond(
            to: prompt(for: sourceText),
            options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 80)
        )
        return response.content
    }

    private static func isAppleIntelligenceAvailable() async -> Bool {
        guard #available(iOS 26.0, *) else {
            return false
        }
        return SystemLanguageModel.default.isAvailable
    }

    private static func prompt(for sourceText: String) -> String {
        let sanitized = sanitizeSourceText(sourceText)
        return [
            "Observation:",
            sanitized,
            "",
            "Rewrite it in Japanese fantasy adventure style.",
            "Use exactly this format:",
            "\u{767A}\u{898B}: <what the player noticed>",
            "\u{6B63}\u{4F53}: <what it seems to be>",
            "\u{8A18}\u{9332}: <short game-like summary>"
        ].joined(separator: "\n")
    }

    private static func makeFallbackNarration(from sourceText: String) -> String {
        let clue = sanitizeSourceText(sourceText)
        let category = localizedCategory(for: sourceText)

        return [
            "\u{767A}\u{898B}: \u{3042}\u{305F}\u{308A}\u{3092}\u{8ABF}\u{3079}\u{308B}\u{3068}\u{3001}\(category)\u{306E}\u{6C17}\u{914D}\u{3092}\u{898B}\u{3064}\u{3051}\u{305F}\u{3002}",
            "\u{6B63}\u{4F53}: \(clue)\u{3089}\u{3057}\u{304D}\u{3082}\u{306E}\u{304C} \u{305D}\u{3053}\u{306B}\u{3042}\u{308B}\u{3002}",
            "\u{8A18}\u{9332}: \u{56F3}\u{9451}\u{306B}\u{8A18}\u{3059}\u{4FA1}\u{5024}\u{306E}\u{3042}\u{308B}\u{767A}\u{898B}\u{3060}\u{3002}"
        ].joined(separator: "\n")
    }

    private static func normalizeNarration(_ text: String, sourceText: String) -> String? {
        let rawLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard rawLines.count == 3 else {
            return nil
        }

        let expectedPrefixes = ["\u{767A}\u{898B}:", "\u{6B63}\u{4F53}:", "\u{8A18}\u{9332}:"]
        guard zip(rawLines, expectedPrefixes).allSatisfy({ line, prefix in
            line.hasPrefix(prefix) && line.count > prefix.count
        }) else {
            return nil
        }

        let normalizedLines = zip(rawLines, expectedPrefixes).map { line, prefix in
            let body = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedBody = body.replacingOccurrences(of: "\u{3002}\u{3002}", with: "\u{3002}")
            return prefix + " " + cleanedBody.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces)) + "\u{3002}"
        }

        return normalizedLines.joined(separator: "\n")
    }

    private static func sanitizeSourceText(_ sourceText: String) -> String {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "unknown object"
        }

        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        return String(firstLine.prefix(48))
    }

    private static func localizedCategory(for sourceText: String) -> String {
        switch CategoryInferencer.infer(from: sourceText) {
        case .food: return "\u{98DF}\u{3079}\u{7269}"
        case .nature: return "\u{81EA}\u{7136}"
        case .animal: return "\u{751F}\u{304D}\u{7269}"
        case .person: return "\u{4EBA}\u{7269}"
        case .building: return "\u{5EFA}\u{7269}"
        case .vehicle: return "\u{4E57}\u{308A}\u{7269}"
        case .item: return "\u{9053}\u{5177}"
        case .other: return "\u{672A}\u{77E5}\u{306E}\u{4F55}\u{304B}"
        }
    }
}
