import SwiftUI

public struct RootView: View {
    @StateObject private var viewModel: CameraViewModel

    public init() {
        _viewModel = StateObject(
            wrappedValue: CameraViewModel(
                inferenceService: InferenceServiceFactory.makeDefault()
            )
        )
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.currentScreen {
            case .camera:
                CameraScreen(viewModel: viewModel)
            case .menu:
                MenuScreen(viewModel: viewModel)
            case .collection:
                CollectionScreen(viewModel: viewModel)
            case .diary:
                DiaryScreen(viewModel: viewModel)
            case .quests:
                QuestScreen(viewModel: viewModel)
            case .achievements:
                AchievementScreen(viewModel: viewModel)
            }
        }
        .task {
            viewModel.loadModel()
        }
    }
}
