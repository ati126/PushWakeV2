import SwiftUI
import AVFoundation
import Vision

final class CameraTracker: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published var count = 0
    @Published var message = "Kamera wird vorbereitet …"
    @Published var authorized = false
    @Published var ready = false

    private let captureQueue = DispatchQueue(label: "pushwake.camera", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private var counter = PushupCounter()
    private var running = false

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
            guard let self else { return }
            DispatchQueue.main.async {
                self.authorized = allowed
                if !allowed { self.message = "Kamerazugriff in Einstellungen erlauben" }
            }
            guard allowed else { return }
            self.captureQueue.async { self.configureAndRun() }
        }
    }

    private func configureAndRun() {
        if !ready {
            session.beginConfiguration()
            session.sessionPreset = .medium
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.message = "Keine Frontkamera verfügbar" }
                return
            }
            session.addInput(input)
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: captureQueue)
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            DispatchQueue.main.async { self.ready = true }
        }
        if !session.isRunning { session.startRunning() }
        running = true
    }

    func stop() {
        captureQueue.async {
            self.running = false
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func reset() {
        captureQueue.async {
            self.counter.reset()
            DispatchQueue.main.async { self.count = 0; self.message = "Startposition einnehmen" }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard running, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectHumanBodyPoseRequest()
        do {
            try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .leftMirrored).perform([request])
            guard let pose = request.results?.first else {
                DispatchQueue.main.async { self.message = "Kein Körper erkannt – weiter weg stellen" }
                return
            }
            let result = counter.ingest(pose, now: ProcessInfo.processInfo.systemUptime)
            DispatchQueue.main.async {
                self.count = result.0
                self.message = result.1
            }
        } catch {
            DispatchQueue.main.async { self.message = "Erkennung fehlgeschlagen" }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoLayer.session = session
        view.videoLayer.videoGravity = .resizeAspect
        if let connection = view.videoLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
