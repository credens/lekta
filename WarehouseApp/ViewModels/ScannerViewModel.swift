import AVFoundation
import Combine
import AudioToolbox

class ScannerViewModel: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var isRunning = false

    let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    // Dedicated serial queue for all session operations — avoids race conditions
    private let sessionQueue = DispatchQueue(label: "com.warehouseapp.scanner.session")

    override init() {
        super.init()
        requestPermissionAndConfigure()
    }

    private func requestPermissionAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { [weak self] in self?.configureSession() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                self?.sessionQueue.async { self?.configureSession() }
            }
        default:
            break
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.ean13, .qr]
        }
        session.commitConfiguration()
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    func resumeScanning() {
        DispatchQueue.main.async { [weak self] in self?.scannedCode = nil }
        startSession()
    }
}

extension ScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue, !value.isEmpty else { return }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        stopSession()
        // Debounce: only publish if different from last code to avoid double-fires
        if scannedCode != value { scannedCode = value }
    }
}
