import Foundation

public enum InferenceServiceFactory {
    @MainActor
    public static func makeDefault() -> InferenceServing {
        let simulatorModelPipeline = FallbackInferenceService(
            primary: GemmaCoreMLInferenceService(modelName: "Gemma4Vision"),
            fallback: FallbackInferenceService(
                primary: AppleVisionInferenceService(),
                fallback: MockInferenceService()
            )
        )

        let deviceFallbackPipeline = FallbackInferenceService(
            primary: AppleVisionInferenceService(),
            fallback: MockInferenceService()
        )

#if targetEnvironment(simulator)
        return simulatorModelPipeline
#else
        // LiteRT first on device, with a stable local fallback chain.
        return LiteRTInferenceService(fallback: deviceFallbackPipeline)
#endif
    }
}
