import Foundation
import MLXLMCommon
import Tokenizers
import HFAPI

// MARK: - TokenizerBridge

/// Bridges `Tokenizers.Tokenizer` (swift-tokenizers) to `MLXLMCommon.Tokenizer`.
struct TokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokenIds: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages, tools: tools, additionalContext: additionalContext)
        } catch let error as Tokenizers.TokenizerError where error == .chatTemplate("") || true {
            // Map any chat template error to MLXLMCommon's error type
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

// MARK: - TokenizersLoader

/// Loads a tokenizer from a local directory using swift-tokenizers' `AutoTokenizer`.
struct TokenizersLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await AutoTokenizer.from(directory: directory)
        return TokenizerBridge(upstream)
    }
}

// MARK: - HubClient + Downloader

extension HubClient: @retroactive MLXLMCommon.Downloader {
    public func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repoID = Repo.ID(rawValue: id) else {
            throw MLXDownloaderError.invalidRepositoryID(id)
        }
        let revision = revision ?? "main"

        if !useLatest {
            if let cached = resolveCachedSnapshot(
                repo: repoID, revision: revision, matching: patterns)
            {
                return cached
            }
        }

        return try await downloadSnapshot(
            of: repoID, revision: revision, matching: patterns,
            progressHandler: progressHandler)
    }
}

enum MLXDownloaderError: LocalizedError {
    case invalidRepositoryID(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepositoryID(let id):
            return "Invalid Hugging Face repository ID: '\(id)'. Expected format 'namespace/name'."
        }
    }
}
