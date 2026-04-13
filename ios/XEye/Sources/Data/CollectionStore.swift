import Foundation

public protocol CollectionStoring {
    func loadEntries() -> [ExamineEntry]
    func saveEntries(_ entries: [ExamineEntry])
}

public final class JSONCollectionStore: CollectionStoring {
    private let fileURL: URL

    public init(baseURL: URL? = nil) {
        let root = baseURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = root.appendingPathComponent("xeye_collection.json")
    }

    public func loadEntries() -> [ExamineEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ExamineEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    public func saveEntries(_ entries: [ExamineEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
