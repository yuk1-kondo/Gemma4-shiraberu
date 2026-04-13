import Foundation

public enum InferenceServiceFactory {
    public static func makeDefault() -> InferenceServing {
        // MLX VLM generates DQ-style text via system prompt, so no StoryFlavor wrapper needed.
        // Falls back to the existing CoreML + Apple Vision pipeline with StoryFlavor.
        FallbackInferenceService(
            primary: MLXInferenceService(),
            fallback: StoryFlavorInferenceService(
                base: FallbackInferenceService(
                    primary: GemmaCoreMLInferenceService(modelName: "Gemma4Vision"),
                    fallback: FallbackInferenceService(
                        primary: AppleVisionInferenceService(),
                        fallback: MockInferenceService()
                    )
                )
            )
        )
    }
}
