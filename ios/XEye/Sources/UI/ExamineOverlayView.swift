import SwiftUI

private enum DQPalette {
    static let panel = Color(red: 0.05, green: 0.05, blue: 0.17)
    static let panelOverlay = Color(red: 0.05, green: 0.05, blue: 0.17).opacity(0.86)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let red = Color(red: 1.0, green: 0.27, blue: 0.27)
    static let blue = Color(red: 0.1, green: 0.1, blue: 0.34)
    static let whiteMuted = Color.white.opacity(0.6)
}

struct CameraScreen: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var isMenuOpen = false
    @State private var isNameDialogOpen = false
    @State private var editingName = ""

    var body: some View {
        ZStack {
            CameraPreviewView(cameraService: viewModel.cameraService)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.2), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if viewModel.isModelReady {
                TargetingFrame(isExamining: viewModel.isInferring)
                    .frame(width: 220, height: 220)
                    .padding(.top, 40)
            }

            if viewModel.currentCombo >= 3 && !viewModel.isInferring {
                Text("\(viewModel.currentCombo) COMBO! x\(comboMultiplierText)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(DQPalette.red)
                    .padding(.top, 52)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            VStack {
                HStack(alignment: .top) {
                    Button {
                        editingName = viewModel.playerName
                        isNameDialogOpen = true
                    } label: {
                        LevelHUD(viewModel: viewModel)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    HStack(spacing: 8) {
                        NameButtonView {
                            editingName = viewModel.playerName
                            isNameDialogOpen = true
                        }

                        MenuButtonView {
                            isMenuOpen = true
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 48)

                Spacer()

                if viewModel.isInferring {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(DQPalette.gold)
                            .scaleEffect(1.2)
                        Text("\u{8ABF}\u{3079}\u{3066}\u{3044}\u{307E}\u{3059}...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(DQPalette.whiteMuted)
                    }
                    .padding(.bottom, 24)
                } else if viewModel.isModelReady {
                    ExamineButtonView {
                        viewModel.submitLatestFrame()
                    }
                    .padding(.bottom, 24)
                }

                if let modelError = viewModel.modelError {
                    StatusBanner(text: localizedStatusText(modelError), isWarning: true)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }

                if viewModel.isModelReady {
                    StatusBanner(text: "\u{63A8}\u{8AD6}: \(localizedBackendLabel)", isWarning: false)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                DQMessageBoxView(text: displayMessage)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
            }

            if isMenuOpen {
                MenuOverlay(
                    collectionCount: viewModel.entries.count,
                    onClose: { isMenuOpen = false },
                    onNavigate: { screen in
                        isMenuOpen = false
                        viewModel.navigate(to: screen)
                    }
                )
            }
        }
        .background(Color.black)
        .onAppear {
            viewModel.startCamera()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
        .sheet(isPresented: $isNameDialogOpen) {
            NameEditSheet(
                name: $editingName,
                onSave: {
                    let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                    viewModel.savePlayerName(trimmed)
                    isNameDialogOpen = false
                },
                onCancel: {
                    isNameDialogOpen = false
                }
            )
        }
    }

    private var comboMultiplierText: String {
        switch viewModel.currentCombo {
        case 10...: return "3"
        case 5...: return "2"
        default: return "1.5"
        }
    }

    private var displayMessage: String {
        if viewModel.isInferring {
            return "\u{8ABF}\u{3079}\u{3066}\u{3044}\u{307E}\u{3059}..."
        }
        if !viewModel.isModelReady {
            return localizedStatusText(viewModel.modelError ?? "\u{30E2}\u{30C7}\u{30EB}\u{8AAD}\u{307F}\u{8FBC}\u{307F}\u{4E2D}...")
        }
        if viewModel.currentMessage.isEmpty {
            return "\u{30AB}\u{30E1}\u{30E9}\u{3092}\u{5411}\u{3051}\u{3066}\u{300C}\u{8ABF}\u{3079}\u{308B}\u{300D}\u{3092}\u{62BC}\u{3057}\u{3066}\u{304F}\u{3060}\u{3055}\u{3044}"
        }
        return viewModel.currentMessage
    }
}

private struct TargetingFrame: View {
    let isExamining: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke((isExamining ? DQPalette.gold : Color.white.opacity(0.5)), lineWidth: 2)

            VStack {
                HStack {
                    CornerShape(color: isExamining ? DQPalette.gold : DQPalette.whiteMuted)
                    Spacer()
                    CornerShape(rotation: .degrees(90), color: isExamining ? DQPalette.gold : DQPalette.whiteMuted)
                }
                Spacer()
                HStack {
                    CornerShape(rotation: .degrees(-90), color: isExamining ? DQPalette.gold : DQPalette.whiteMuted)
                    Spacer()
                    CornerShape(rotation: .degrees(180), color: isExamining ? DQPalette.gold : DQPalette.whiteMuted)
                }
            }
            .padding(8)

            if !isExamining {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 3, height: 3)
            }
        }
        .opacity(isExamining ? 0.85 : 1)
    }
}

private struct CornerShape: View {
    var rotation: Angle = .zero
    var color: Color = DQPalette.gold

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color)
                .frame(width: 26, height: 3)
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 26)
        }
        .rotationEffect(rotation)
    }
}

private struct LevelHUD: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Lv.\(viewModel.level)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(DQPalette.gold)

                HStack(spacing: 4) {
                    Text(viewModel.playerName.isEmpty ? "\u{306A}\u{306A}\u{3057}\u{3055}\u{3093}" : viewModel.playerName)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(viewModel.playerName.isEmpty ? DQPalette.whiteMuted : .white)

                    Text("\u{7DE8}\u{96C6}")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(DQPalette.whiteMuted)
                }
            }

            Text(viewModel.levelTitle)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule().fill(DQPalette.gold)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(width: 160, height: 4)

            Text(viewModel.isMaxLevel ? "MAX" : "\(viewModel.currentLevelXP)/\(viewModel.xpToNextLevel)  \u{8ABF}\u{67FB}\u{6570}:\(viewModel.totalExamined)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DQPalette.whiteMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DQPalette.panelOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DQPalette.gold, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var progress: CGFloat {
        guard !viewModel.isMaxLevel, viewModel.xpToNextLevel > 0 else { return 1 }
        return min(1, CGFloat(viewModel.currentLevelXP) / CGFloat(viewModel.xpToNextLevel))
    }
}

private struct NameEditSheet: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("\u{30D7}\u{30EC}\u{30A4}\u{30E4}\u{30FC}\u{540D}")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))

                TextField("\u{306A}\u{306A}\u{3057}\u{3055}\u{3093}", text: $name)
                    .textFieldStyle(.roundedBorder)

                Text("\u{30EC}\u{30D9}\u{30EB}HUD\u{306E}\u{540D}\u{524D}\u{3092}\u{3044}\u{3064}\u{3067}\u{3082}\u{5909}\u{66F4}\u{3067}\u{304D}\u{307E}\u{3059}")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(16)
            .navigationTitle("\u{540D}\u{524D}\u{5909}\u{66F4}")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("\u{30AD}\u{30E3}\u{30F3}\u{30BB}\u{30EB}", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\u{4FDD}\u{5B58}", action: onSave)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct MenuButtonView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\u{30E1}\u{30CB}\u{30E5}\u{30FC}")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(DQPalette.panelOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct NameButtonView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\u{540D}\u{524D}")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(DQPalette.panelOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct ExamineButtonView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\u{8ABF}\u{3079}\u{308B}")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(DQPalette.gold)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(Color(red: 0.1, green: 0.1, blue: 0.18).opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DQMessageBoxView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 16, design: .monospaced))
            .foregroundStyle(.white)
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(DQPalette.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: 3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct StatusBanner: View {
    let text: String
    let isWarning: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(isWarning ? Color.orange : DQPalette.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DQPalette.panelOverlay)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke((isWarning ? Color.orange : DQPalette.red).opacity(0.8), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct MenuOverlay: View {
    let collectionCount: Int
    let onClose: () -> Void
    let onNavigate: (GameScreen) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 10) {
                Text("\u{30B3}\u{30DE}\u{30F3}\u{30C9}")
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(DQPalette.gold)

                MenuActionRow(title: "\u{30AB}\u{30E1}\u{30E9}") { onNavigate(.camera) }
                MenuActionRow(title: "\u{56F3}\u{9451}", subtitle: "\(collectionCount) \u{4EF6}") { onNavigate(.collection) }
                MenuActionRow(title: "\u{65E5}\u{8A18}") { onNavigate(.diary) }
                MenuActionRow(title: "\u{30AF}\u{30A8}\u{30B9}\u{30C8}") { onNavigate(.quests) }
                MenuActionRow(title: "\u{5B9F}\u{7E3E}") { onNavigate(.achievements) }

                Divider()
                    .overlay(Color.white.opacity(0.3))

                MenuActionRow(title: "\u{3084}\u{3081}\u{308B}", isDestructive: true) { onClose() }
            }
            .padding(14)
            .frame(width: 220)
            .background(DQPalette.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white, lineWidth: 3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct MenuActionRow: View {
    let title: String
    var subtitle: String = ""
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("\u{25B8} \(title)")
                    .font(.system(.body, design: .monospaced, weight: .bold))
                    .foregroundStyle(isDestructive ? Color(red: 1.0, green: 0.4, blue: 0.4) : .white)
                if !subtitle.isEmpty {
                    Spacer()
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct MenuScreen: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MenuOverlay(
                collectionCount: viewModel.entries.count,
                onClose: { viewModel.navigate(to: .camera) },
                onNavigate: { viewModel.navigate(to: $0) }
            )
        }
    }
}

struct CollectionScreen: View {
    @ObservedObject var viewModel: CameraViewModel
    @State private var selectedCategory: Category?

    var body: some View {
        ZStack {
            DQListBackground {
                VStack(spacing: 8) {
                    DQCenteredTitle(title: "\u{56F3}\u{9451}")
                    CategoryFilterRow(selectedCategory: $selectedCategory)
                    Text("\(filteredEntries.count)\u{4EF6}")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(DQPalette.whiteMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(filteredEntries) { entry in
                                CollectionEntryCard(entry: entry)
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredEntries: [ExamineEntry] {
        guard let selectedCategory else { return viewModel.entries }
        return viewModel.entries.filter { $0.category == selectedCategory }
    }
}

struct DiaryScreen: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {
        DQListBackground {
            VStack(spacing: 12) {
                DQCenteredTitle(title: "\u{65E5}\u{8A18}")
                Text("\(viewModel.entries.count)\u{4EF6}\u{306E}\u{8A18}\u{9332}")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DQPalette.whiteMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.entries) { entry in
                            DiaryEntryCard(entry: entry)
                        }
                    }
                }
            }
        }
    }
}

struct QuestScreen: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {
        DQListBackground {
            VStack(spacing: 12) {
                DQCenteredTitle(title: "\u{30AF}\u{30A8}\u{30B9}\u{30C8}")
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.activeQuests) { quest in
                            QuestCard(quest: quest)
                        }
                    }
                }
            }
        }
    }
}

struct AchievementScreen: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {
        DQListBackground {
            VStack(spacing: 12) {
                DQCenteredTitle(title: "\u{5B9F}\u{7E3E}")
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(AchievementDefinitions.all) { achievement in
                            AchievementCard(
                                achievement: achievement,
                                isUnlocked: viewModel.unlockedAchievementIDs.contains(achievement.id)
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct DQListBackground<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 0) {
                content
            }
            .padding(16)
        }
    }
}

private struct DQCenteredTitle: View {
    let title: String

    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(DQPalette.gold)
            Spacer()
        }
    }
}

private struct CategoryFilterRow: View {
    @Binding var selectedCategory: Category?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                CategoryPill(title: "\u{3059}\u{3079}\u{3066}", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(Array(Category.allCases.prefix(5)), id: \.self) { category in
                    CategoryPill(title: category.displayLabel, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
}

private struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isSelected ? DQPalette.blue : Color.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(isSelected ? DQPalette.gold : Color(red: 0.1, green: 0.1, blue: 0.18))
        .overlay(
            Capsule().stroke(isSelected ? DQPalette.gold : Color.white.opacity(0.4), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

private struct CollectionEntryCard: View {
    let entry: ExamineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Text(entry.itemName.isEmpty ? "\u{4E0D}\u{660E}\u{306A}\u{30A2}\u{30A4}\u{30C6}\u{30E0}" : entry.itemName)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(entry.rarity.color)
                Text("[\(entry.rarity.label)]")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(entry.rarity.color)
                Text("[\(entry.category.displayLabel)]")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text(entry.timestamp.dqDateString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            Text(entry.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DQPalette.panelOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(entry.rarity.color.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct DiaryEntryCard: View {
    let entry: ExamineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.timestamp.dqDateString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                Text("[\(entry.rarity.label)]")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(entry.rarity.color)
                Text(entry.category.displayLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            if !entry.itemName.isEmpty {
                Text(entry.itemName)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(entry.rarity.color)
            }
            Text(entry.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DQPalette.panelOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct QuestCard: View {
    let quest: Quest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(quest.title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(quest.completed ? DQPalette.gold : .white)
            Text(quest.description)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DQPalette.whiteMuted)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule().fill(quest.completed ? DQPalette.gold : Color(red: 0.25, green: 0.41, blue: 0.88))
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)

            HStack {
                Text("\(quest.progress)/\(quest.targetCount)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text("+\(quest.rewardXP) XP")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DQPalette.gold.opacity(quest.completed ? 1 : 0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DQPalette.panelOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(quest.completed ? DQPalette.gold : Color.white.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var progress: CGFloat {
        guard quest.targetCount > 0 else { return 0 }
        return min(1, CGFloat(quest.progress) / CGFloat(quest.targetCount))
    }
}

private struct AchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(achievement.title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(isUnlocked ? DQPalette.gold : .white)
            Text(achievement.description)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DQPalette.whiteMuted)
            Text(isUnlocked ? "UNLOCKED" : "LOCKED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isUnlocked ? DQPalette.gold : Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(DQPalette.panelOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isUnlocked ? DQPalette.gold : Color.white.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private extension Category {
    var displayLabel: String {
        switch self {
        case .food: return "\u{98DF}\u{3079}\u{7269}"
        case .nature: return "\u{81EA}\u{7136}"
        case .animal: return "\u{751F}\u{304D}\u{7269}"
        case .person: return "\u{4EBA}\u{7269}"
        case .building: return "\u{5EFA}\u{7269}"
        case .vehicle: return "\u{4E57}\u{308A}\u{7269}"
        case .item: return "\u{9053}\u{5177}"
        case .other: return "\u{305D}\u{306E}\u{4ED6}"
        }
    }
}

private extension Rarity {
    var color: Color {
        switch self {
        case .n: return Color.white.opacity(0.85)
        case .r: return Color(red: 0.3, green: 0.8, blue: 1.0)
        case .sr: return Color(red: 1.0, green: 0.55, blue: 0.2)
        case .ssr: return DQPalette.gold
        }
    }
}

private extension Date {
    var dqDateString: String {
        DateFormatter.dqList.string(from: self)
    }
}

private extension DateFormatter {
    static let dqList: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()
}

private func localizedStatusText(_ text: String) -> String {
    if text.contains("Gemma4 unavailable") {
        return "Gemma4\u{304C}\u{672A}\u{914D}\u{7F6E}\u{306E}\u{305F}\u{3081}\u{3001}\u{4EE3}\u{66FF}\u{63A8}\u{8AD6}\u{3092}\u{4F7F}\u{7528}\u{4E2D}\u{3067}\u{3059}"
    }
    return text
}

private extension CameraScreen {
    var localizedBackendLabel: String {
        if viewModel.inferenceBackendLabel.contains("Gemma4") && viewModel.inferenceBackendLabel.contains("Apple Intelligence") {
            return "Gemma4 \u{30ED}\u{30FC}\u{30AB}\u{30EB} + Apple Intelligence"
        }
        if viewModel.inferenceBackendLabel.contains("Apple Vision") && viewModel.inferenceBackendLabel.contains("Apple Intelligence") {
            return "Apple Vision + Apple Intelligence"
        }
        if viewModel.inferenceBackendLabel.contains("Gemma4") {
            return "Gemma4 \u{30ED}\u{30FC}\u{30AB}\u{30EB}"
        }
        if viewModel.inferenceBackendLabel.contains("Apple Vision") {
            return "Apple Vision"
        }
        if viewModel.isInferenceFallback {
            return "\u{30E2}\u{30C3}\u{30AF} (\u{30D5}\u{30A9}\u{30FC}\u{30EB}\u{30D0}\u{30C3}\u{30AF})"
        }
        return viewModel.inferenceBackendLabel
    }
}
