import CoreML
import Foundation

/// Decodes token-id outputs into user-readable text using a bundled vocabulary.
/// Expected vocab format: JSON dictionary where key=token string, value=token id.
public final class GemmaTokenDecoder {
    private let idToToken: [Int: String]
    private let specialTokenIDs: Set<Int>

    public init(vocabURL: URL, specialTokenIDs: Set<Int> = [0, 1, 2]) throws {
        let data = try Data(contentsOf: vocabURL)
        let raw = try JSONDecoder().decode([String: Int].self, from: data)

        var inverse: [Int: String] = [:]
        inverse.reserveCapacity(raw.count)
        for (token, id) in raw {
            inverse[id] = token
        }

        self.idToToken = inverse
        self.specialTokenIDs = specialTokenIDs
    }

    public func decode(array: MLMultiArray, maxTokens: Int = 192) -> String? {
        guard array.count > 0 else { return nil }

        let limit = min(array.count, maxTokens)
        var pieces: [String] = []
        pieces.reserveCapacity(limit)

        for i in 0..<limit {
            let value = array[i].doubleValue
            let rounded = Int(value.rounded())

            // Ignore non-integer-like values from logits tensors.
            if abs(value - Double(rounded)) > 0.0001 {
                continue
            }

            guard !specialTokenIDs.contains(rounded) else {
                continue
            }

            guard let token = idToToken[rounded] else {
                continue
            }

            if token == "<eos>" || token == "</s>" {
                break
            }

            pieces.append(token)
        }

        let text = mergeSentencePieceTokens(pieces)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text.isEmpty ? nil : text
    }

    private func mergeSentencePieceTokens(_ pieces: [String]) -> String {
        var result = ""
        result.reserveCapacity(pieces.reduce(0) { $0 + $1.count })

        for piece in pieces {
            if piece.hasPrefix("?") {
                let clean = piece.replacingOccurrences(of: "?", with: "")
                if !result.isEmpty {
                    result.append(" ")
                }
                result.append(clean)
            } else {
                result.append(piece)
            }
        }

        return result
    }
}
