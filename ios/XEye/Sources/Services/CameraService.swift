import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import VideoToolbox

public protocol CameraFrameProvider: AnyObject {
    var onFrame: ((CGImage) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var previewLayer: AVCaptureVideoPreviewLayer { get }
    func start()
    func stop()
}

public final class AVFoundationCameraService: NSObject, CameraFrameProvider {
    public var onFrame: ((CGImage) -> Void)?
    public var onError: ((String) -> Void)?

    public let previewLayer: AVCaptureVideoPreviewLayer

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let frameQueue = DispatchQueue(label: "xeye.camera.frame")
    private let ciContext = CIContext()
    private var configured = false

    override public init() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init()
        self.previewLayer.videoGravity = .resizeAspectFill
    }

    public func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            configureSessionIfNeededAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureSessionIfNeededAndStart()
                } else {
                    self.onError?("Camera permission denied")
                }
            }
        default:
            onError?("Camera permission denied or restricted")
        }
    }

    public func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureSessionIfNeededAndStart() {
        if !configured {
            configureSession()
        }
        if !session.isRunning {
            session.startRunning()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            onError?("Back camera not available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            onError?("Camera input setup failed: \(error.localizedDescription)")
            return
        }

        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: frameQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        configured = true
    }
}

extension AVFoundationCameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        if let cgImage = cgImage(from: buffer) {
            onFrame?(cgImage)
        }
    }

    private func cgImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}
