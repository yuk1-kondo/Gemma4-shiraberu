import CoreGraphics
import Foundation

@MainActor
public final class CameraViewModel: ObservableObject {
    @Published public private(set) var currentScreen: GameScreen = .camera
    @Published public private(set) var isInferring = false
    @Published public private(set) var isModelReady = false
    @Published public private(set) var modelError: String?
    @Published public private(set) var currentMessage = ""
    @Published public private(set) var level = 1
    @Published public private(set) var totalExamined = 0
    @Published public private(set) var currentCombo = 0
    @Published public private(set) var currentRarity: Rarity = .n
    @Published public private(set) var xpGained = 0
    @Published public private(set) var entries: [ExamineEntry] = []
    @Published public private(set) var inferenceBackendLabel = "Unknown"
    @Published public private(set) var isInferenceFallback = false
    @Published public var playerName = ""
    @Published public private(set) var hasLatestFrame = false

    private var progress: ProgressState
    private let progressStore: ProgressStoring
    private let collectionStore: CollectionStoring
    private let inferenceService: InferenceServing
    public let cameraService: CameraFrameProvider
    private let comboManager = ComboManager()
    private var latestFrame: CGImage?

    public init(
        progressStore: ProgressStoring = UserDefaultsProgressStore(),
        collectionStore: CollectionStoring = JSONCollectionStore(),
        inferenceService: InferenceServing = MockInferenceService(),
        cameraService: CameraFrameProvider = AVFoundationCameraService()
    ) {
        self.progressStore = progressStore
        self.collectionStore = collectionStore
        self.inferenceService = inferenceService
        self.cameraService = cameraService

        self.progress = progressStore.load()
        self.entries = collectionStore.loadEntries()
        self.playerName = progress.playerName
        self.totalExamined = progress.totalExamined
        self.level = XPFormula.level(for: progress.totalXP)

        self.cameraService.onFrame = { [weak self] frame in
            Task { @MainActor in
                self?.latestFrame = frame
                self?.hasLatestFrame = true
            }
        }

        self.cameraService.onError = { [weak self] message in
            Task { @MainActor in
                self?.modelError = message
            }
        }
    }

    public func loadModel() {
        Task {
            await inferenceService.loadModel()
            isModelReady = inferenceService.isModelReady
            modelError = inferenceService.lastError
            inferenceBackendLabel = inferenceService.backendDisplayName
            isInferenceFallback = inferenceService.isUsingFallback
        }
    }

    public func navigate(to screen: GameScreen) {
        currentScreen = screen
    }

    public func startCamera() {
        cameraService.start()
    }

    public func stopCamera() {
        cameraService.stop()
    }

    public func submitLatestFrame() {
        guard let latestFrame else {
            modelError = "\u{30AB}\u{30E1}\u{30E9}\u{753B}\u{50CF}\u{304C}\u{307E}\u{3060}\u{53D6}\u{5F97}\u{3067}\u{304D}\u{3066}\u{3044}\u{307E}\u{305B}\u{3093}"
            return
        }
        submitFrame(latestFrame)
    }

    public func submitFrame(_ frame: CGImage) {
        guard !isInferring else { return }
        guard inferenceService.isModelReady else {
            modelError = "\u{30E2}\u{30C7}\u{30EB}\u{306E}\u{6E96}\u{5099}\u{304C}\u{3067}\u{304D}\u{3066}\u{3044}\u{307E}\u{305B}\u{3093}"
            return
        }

        isInferring = true

        Task {
            defer { isInferring = false }

            do {
                let result = try await inferenceService.examine(frame: frame)
                inferenceBackendLabel = inferenceService.backendDisplayName
                isInferenceFallback = inferenceService.isUsingFallback
                apply(result: result)
            } catch {
                modelError = "\u{63A8}\u{8AD6}\u{306B}\u{5931}\u{6557}\u{3057}\u{307E}\u{3057}\u{305F}: \(error.localizedDescription)"
            }
        }
    }

    public func savePlayerName(_ name: String) {
        playerName = name
        progress.playerName = name
        progressStore.save(progress)
    }

    public var levelTitle: String {
        switch level {
        case 1...4:
            return "\u{307F}\u{306A}\u{3089}\u{3044}\u{8ABF}\u{67FB}\u{54E1}"
        case 5...9:
            return "\u{99C6}\u{3051}\u{51FA}\u{3057}\u{898B}\u{805E}\u{9304}"
        case 10...19:
            return "\u{8857}\u{306E}\u{89B3}\u{5BDF}\u{8005}"
        case 20...39:
            return "\u{63A2}\u{7A76}\u{306E}\u{65C5}\u{4EBA}"
        case 40...59:
            return "\u{7269}\u{8B58}\u{306E}\u{8CE2}\u{8005}"
        case 60...79:
            return "\u{4F1D}\u{627F}\u{306E}\u{8A18}\u{9332}\u{8005}"
        default:
            return "\u{771F}\u{7406}\u{3092}\u{8996}\u{308B}\u{8005}"
        }
    }

    public var currentLevelXP: Int {
        let currentLevelBaseXP = XPFormula.xpForLevel(level)
        return max(0, Int(progress.totalXP - currentLevelBaseXP))
    }

    public var xpToNextLevel: Int {
        guard !isMaxLevel else { return 0 }
        let currentLevelBaseXP = XPFormula.xpForLevel(level)
        let nextLevelBaseXP = XPFormula.xpForLevel(level + 1)
        return max(1, Int(nextLevelBaseXP - currentLevelBaseXP))
    }

    public var isMaxLevel: Bool {
        level >= XPFormula.maxLevel
    }

    public var categoryCounts: [Category: Int] {
        entries.reduce(into: [:]) { counts, entry in
            counts[entry.category, default: 0] += 1
        }
    }

    public var activeQuests: [Quest] {
        QuestDefinitions.all().map { quest in
            var resolved = quest
            resolved.progress = progressValue(for: quest)
            resolved.completed = resolved.progress >= resolved.targetCount
            return resolved
        }
    }

    public var unlockedAchievementIDs: Set<String> {
        var unlocked = Set<String>()

        if totalExamined >= 1 { unlocked.insert("first_exam") }
        if totalExamined >= 10 { unlocked.insert("exam_10") }
        if totalExamined >= 50 { unlocked.insert("exam_50") }
        if entries.contains(where: { $0.rarity == .sr }) { unlocked.insert("rare_sr") }
        if entries.contains(where: { $0.rarity == .ssr }) { unlocked.insert("rare_ssr") }
        if progress.maxCombo >= 3 { unlocked.insert("combo_3") }
        if progress.maxCombo >= 5 { unlocked.insert("combo_5") }
        if Set(entries.map(\ .category)).isSuperset(of: Set(Category.allCases)) { unlocked.insert("all_cat") }

        return unlocked
    }

    private func apply(result: InferenceResult) {
        let rarity = RarityRoller.roll()
        let category = CategoryInferencer.infer(from: result.text)
        let combo = comboManager.recordExamine()

        let gained = Int(Double(XPFormula.baseXPPerExamine) * rarity.xpMultiplier * comboManager.comboMultiplier)

        progress.totalExamined += 1
        progress.totalXP += Int64(gained)
        progress.maxCombo = max(progress.maxCombo, combo)
        progressStore.save(progress)

        let entry = ExamineEntry(text: result.text, category: category, rarity: rarity, itemName: extractItemName(from: result.text))
        entries.insert(entry, at: 0)
        collectionStore.saveEntries(entries)

        currentMessage = result.text
        totalExamined = progress.totalExamined
        level = XPFormula.level(for: progress.totalXP)
        currentCombo = combo
        currentRarity = rarity
        xpGained = gained
    }

    private func extractItemName(from text: String) -> String {
        let firstLine = text.split(separator: "\n").first.map(String.init) ?? "Unknown"
        return String(firstLine.prefix(24))
    }

    private func progressValue(for quest: Quest) -> Int {
        switch quest.id {
        case "q_food_3", "q_nature_5":
            guard let targetCategory = quest.targetCategory else { return 0 }
            return entries.filter { $0.category == targetCategory }.count
        case "q_rare_sr":
            return entries.contains(where: { $0.rarity == .sr || $0.rarity == .ssr }) ? 1 : 0
        case "q_rare_ssr":
            return entries.contains(where: { $0.rarity == .ssr }) ? 1 : 0
        case "q_exam_20":
            return totalExamined
        default:
            return 0
        }
    }
}
