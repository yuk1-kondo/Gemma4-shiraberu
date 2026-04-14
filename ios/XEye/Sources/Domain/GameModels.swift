import Foundation

public enum GameScreen: String, Codable, CaseIterable, Sendable {
    case camera
    case collection
    case diary
    case quests
    case achievements
    case menu
}

public enum Rarity: String, Codable, CaseIterable, Sendable {
    case n
    case r
    case sr
    case ssr

    public var xpMultiplier: Double {
        switch self {
        case .n: return 1.0
        case .r: return 1.5
        case .sr: return 3.0
        case .ssr: return 5.0
        }
    }

    public var label: String {
        switch self {
        case .n: return "N"
        case .r: return "R"
        case .sr: return "SR"
        case .ssr: return "SSR"
        }
    }
}

public enum Category: String, Codable, CaseIterable, Sendable {
    case food
    case nature
    case animal
    case person
    case building
    case vehicle
    case item
    case other
}

public struct ExamineEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let category: Category
    public let rarity: Rarity
    public let timestamp: Date
    public let itemName: String

    public init(
        id: UUID = UUID(),
        text: String,
        category: Category,
        rarity: Rarity,
        timestamp: Date = Date(),
        itemName: String = ""
    ) {
        self.id = id
        self.text = text
        self.category = category
        self.rarity = rarity
        self.timestamp = timestamp
        self.itemName = itemName
    }
}

public struct Quest: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let targetCategory: Category?
    public let targetCount: Int
    public let rewardXP: Int
    public var progress: Int
    public var completed: Bool

    public init(
        id: String,
        title: String,
        description: String,
        targetCategory: Category?,
        targetCount: Int,
        rewardXP: Int,
        progress: Int = 0,
        completed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetCategory = targetCategory
        self.targetCount = targetCount
        self.rewardXP = rewardXP
        self.progress = progress
        self.completed = completed
    }
}

public struct Achievement: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let description: String
}
