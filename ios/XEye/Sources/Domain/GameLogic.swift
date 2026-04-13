import Foundation

public enum RarityRoller {
    public static func roll(random: Double = Double.random(in: 0..<1)) -> Rarity {
        switch random {
        case ..<0.03: return .ssr
        case ..<0.15: return .sr
        case ..<0.40: return .r
        default: return .n
        }
    }
}

public final class ComboManager {
    private var lastExamineAt: Date?
    private(set) public var currentCombo: Int = 0

    public init() {}

    @discardableResult
    public func recordExamine(now: Date = Date()) -> Int {
        if let lastExamineAt, now.timeIntervalSince(lastExamineAt) < 30 {
            currentCombo += 1
        } else {
            currentCombo = 1
        }
        self.lastExamineAt = now
        return currentCombo
    }

    public var comboMultiplier: Double {
        switch currentCombo {
        case 10...: return 3.0
        case 5...: return 2.0
        case 3...: return 1.5
        default: return 1.0
        }
    }

    public func reset() {
        currentCombo = 0
        lastExamineAt = nil
    }
}

public enum CategoryInferencer {
    private static let keywords: [Category: [String]] = [
        .food: ["food", "eat", "dish", "meal", "drink", "coffee", "fruit", "rice", "bread"],
        .nature: ["tree", "flower", "grass", "mountain", "river", "sky", "sea", "nature"],
        .animal: ["dog", "cat", "bird", "fish", "animal", "pet"],
        .person: ["person", "man", "woman", "child", "people", "face"],
        .building: ["building", "house", "tower", "bridge", "school", "office"],
        .vehicle: ["car", "bus", "train", "bike", "vehicle", "truck"],
        .item: ["item", "tool", "device", "phone", "book", "bag"]
    ]

    public static func infer(from text: String) -> Category {
        let lowercased = text.lowercased()
        var best: (category: Category, score: Int)?

        for (category, words) in keywords {
            let score = words.reduce(0) { partial, word in
                partial + (lowercased.contains(word) ? 1 : 0)
            }
            if score > 0, (best == nil || score > best!.score) {
                best = (category, score)
            }
        }

        return best?.category ?? .other
    }
}

public enum XPFormula {
    public static let maxLevel = 99
    public static let baseXPPerExamine = 15

    public static func xpForLevel(_ level: Int) -> Int64 {
        if level <= 1 { return 0 }
        let n = Int64(level)
        return 100 * n * n * n
    }

    public static func level(for totalXP: Int64) -> Int {
        var lv = maxLevel
        while lv > 1 && totalXP < xpForLevel(lv) {
            lv -= 1
        }
        return lv
    }
}

public enum QuestDefinitions {
    public static func all() -> [Quest] {
        [
            Quest(id: "q_food_3", title: "Food Starter", description: "Examine 3 food entries", targetCategory: .food, targetCount: 3, rewardXP: 100),
            Quest(id: "q_nature_5", title: "Nature Walker", description: "Examine 5 nature entries", targetCategory: .nature, targetCount: 5, rewardXP: 150),
            Quest(id: "q_rare_sr", title: "Rare Hunter", description: "Get one SR", targetCategory: nil, targetCount: 1, rewardXP: 300),
            Quest(id: "q_rare_ssr", title: "SSR Hunter", description: "Get one SSR", targetCategory: nil, targetCount: 1, rewardXP: 1000),
            Quest(id: "q_exam_20", title: "Daily Survey", description: "Examine 20 entries", targetCategory: nil, targetCount: 20, rewardXP: 200)
        ]
    }
}

public enum AchievementDefinitions {
    public static let all: [Achievement] = [
        Achievement(id: "first_exam", title: "First Examine", description: "Complete your first examine"),
        Achievement(id: "exam_10", title: "Ten Examines", description: "Complete 10 examines"),
        Achievement(id: "exam_50", title: "Fifty Examines", description: "Complete 50 examines"),
        Achievement(id: "rare_sr", title: "SR Found", description: "Obtain one SR"),
        Achievement(id: "rare_ssr", title: "SSR Found", description: "Obtain one SSR"),
        Achievement(id: "combo_3", title: "Combo 3", description: "Reach 3 combo"),
        Achievement(id: "combo_5", title: "Combo 5", description: "Reach 5 combo"),
        Achievement(id: "all_cat", title: "All Categories", description: "Collect one from every category")
    ]
}
