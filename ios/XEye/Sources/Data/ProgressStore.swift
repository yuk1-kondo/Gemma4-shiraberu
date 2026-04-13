import Foundation

public struct ProgressState: Codable, Equatable {
    public var playerName: String
    public var totalExamined: Int
    public var totalXP: Int64
    public var maxCombo: Int

    public init(playerName: String = "", totalExamined: Int = 0, totalXP: Int64 = 0, maxCombo: Int = 0) {
        self.playerName = playerName
        self.totalExamined = totalExamined
        self.totalXP = totalXP
        self.maxCombo = maxCombo
    }
}

public protocol ProgressStoring {
    func load() -> ProgressState
    func save(_ state: ProgressState)
}

public final class UserDefaultsProgressStore: ProgressStoring {
    private let defaults: UserDefaults
    private let key = "xeye.progress"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ProgressState {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ProgressState.self, from: data) else {
            return ProgressState()
        }
        return decoded
    }

    public func save(_ state: ProgressState) {
        guard let encoded = try? JSONEncoder().encode(state) else { return }
        defaults.set(encoded, forKey: key)
    }
}
