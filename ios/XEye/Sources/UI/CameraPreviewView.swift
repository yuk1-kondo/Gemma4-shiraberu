import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraFrameProvider

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.backgroundColor = .black
        view.attachPreviewLayer(cameraService.previewLayer)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        uiView.attachPreviewLayer(cameraService.previewLayer)
    }
}

final class CameraPreviewContainerView: UIView {
    private weak var attachedLayer: CALayer?

    func attachPreviewLayer(_ layer: CALayer) {
        if attachedLayer !== layer {
            attachedLayer?.removeFromSuperlayer()
            self.layer.addSublayer(layer)
            attachedLayer = layer
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachedLayer?.frame = bounds
    }
}
