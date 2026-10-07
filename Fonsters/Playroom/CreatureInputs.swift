#if os(macOS)
import Foundation
import AVFoundation
import Vision
import Observation
import simd

/// Permission is requested only by an explicit button press. No frames or audio are stored.
@MainActor @Observable
final class CreatureInputs {
    private(set) var microphoneEnabled = false
    private(set) var cameraEnabled = false
    private(set) var level: Float = 0
    private(set) var status = "Inputs stay on this Mac."
    @ObservationIgnored var onVoiceActivity: (() -> Void)?
    @ObservationIgnored var onFace: ((SIMD2<Float>) -> Void)?
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var camera: FaceCaptureWorker?
    @ObservationIgnored private var suspended = false
    @ObservationIgnored private var microphoneAllowed = false
    @ObservationIgnored private var cameraAllowed = false
    @ObservationIgnored private var lastVoice = Date.distantPast
    @ObservationIgnored private var lastMeter = Date.distantPast
    @ObservationIgnored private var cameraGeneration = 0

    func toggleMicrophone() {
        if microphoneEnabled { microphoneEnabled = false; stopMicrophone(); status = "Microphone off."; return }
        microphoneEnabled = true
        Task { @MainActor in
            microphoneAllowed = await AVCaptureDevice.requestAccess(for: .audio)
            guard microphoneEnabled else { return }
            guard microphoneAllowed else { microphoneEnabled = false; status = "Microphone access wasn’t granted."; return }
            if !suspended { startMicrophone() }
        }
    }
    func toggleCamera() {
        if cameraEnabled { cameraEnabled = false; stopCamera(); status = "Camera off."; return }
        cameraEnabled = true
        Task { @MainActor in
            cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
            guard cameraEnabled else { return }
            guard cameraAllowed else { cameraEnabled = false; status = "Camera access wasn’t granted."; return }
            if !suspended { startCamera() }
        }
    }
    func setSuspended(_ value: Bool) {
        guard suspended != value else { return }
        suspended = value
        if value { stopMicrophone(); stopCamera(); status = "Inputs paused with the Playroom." }
        else {
            if microphoneEnabled && microphoneAllowed { startMicrophone() }
            if cameraEnabled && cameraAllowed { startCamera() }
            if !microphoneEnabled && !cameraEnabled { status = "Inputs stay on this Mac." }
        }
    }
    func stopAll() {
        microphoneEnabled = false; cameraEnabled = false
        stopMicrophone(); stopCamera()
    }
    private func startMicrophone() {
        guard engine == nil else { return }
        let audio = AVAudioEngine()
        let input = audio.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            microphoneEnabled = false; status = "No microphone is available."; return
        }
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let samples = buffer.floatChannelData?[0] else { return }
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
            let rms = sqrt(sum / Float(max(1, buffer.frameLength)))
            Task { @MainActor [weak self] in self?.receiveMicrophoneLevel(rms) }
        }
        do { try audio.start(); engine = audio; status = "Speak or clap for a tiny hello." }
        catch { input.removeTap(onBus: 0); microphoneEnabled = false; status = "Couldn’t start the microphone." }
    }
    private func receiveMicrophoneLevel(_ rms: Float) {
        guard microphoneEnabled && !suspended else { return }
        let now = Date()
        if now.timeIntervalSince(lastMeter) > 0.12 { level = min(1, rms * 12); lastMeter = now }
        if rms > 0.035 && now.timeIntervalSince(lastVoice) > 2.6 {
            lastVoice = now; onVoiceActivity?()
        }
    }
    private func stopMicrophone() {
        engine?.inputNode.removeTap(onBus: 0); engine?.stop(); engine = nil; level = 0
    }
    private func startCamera() {
        guard camera == nil else { return }
        cameraGeneration += 1
        let generation = cameraGeneration
        let worker = FaceCaptureWorker(onFace: { [weak self] point in
            Task { @MainActor [weak self] in
                guard let self, self.cameraGeneration == generation, self.cameraEnabled && !self.suspended else { return }
                self.onFace?(point ?? .zero)
                self.status = point == nil ? "Camera on · looking for a face." : "Camera on · following your face."
            }
        }, onFailure: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.cameraGeneration == generation else { return }
                self.cameraEnabled = false; self.stopCamera()
                self.status = "Couldn’t start the camera."
            }
        })
        camera = worker; worker.start()
        status = "Camera on · looking for a face."
    }
    private func stopCamera() { cameraGeneration += 1; camera?.stop(); camera = nil; onFace?(.zero) }
}

/// AVFoundation invokes this delegate on its one serial queue. Only numeric gaze values
/// cross to the main actor; buffers, Vision requests, configuration and timing stay here.
nonisolated final class FaceCaptureWorker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "Fonsters.Playroom.LocalFaceCapture", qos: .utility)
    private let session = AVCaptureSession()
    private let onFace: @Sendable (SIMD2<Float>?) -> Void
    private let onFailure: @Sendable () -> Void
    private var configured = false
    private var lastFrame: TimeInterval = 0
    init(onFace: @escaping @Sendable (SIMD2<Float>?) -> Void, onFailure: @escaping @Sendable () -> Void) {
        self.onFace = onFace; self.onFailure = onFailure; super.init()
    }
    func start() {
        queue.async { [self] in
            if !configured {
                guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { onFailure(); return }
                session.beginConfiguration(); session.sessionPreset = .low
                guard session.canAddInput(input) else { session.commitConfiguration(); onFailure(); return }
                session.addInput(input)
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: queue)
                guard session.canAddOutput(output) else { session.commitConfiguration(); onFailure(); return }
                session.addOutput(output); session.commitConfiguration(); configured = true
            }
            session.startRunning()
            if !session.isRunning { onFailure() }
        }
    }
    func stop() { queue.async { [self] in session.stopRunning() } }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date.timeIntervalSinceReferenceDate
        guard now - lastFrame > 0.2 else { return }; lastFrame = now
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        do {
            try handler.perform([request])
            guard let face = request.results?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else { onFace(nil); return }
            let box = face.boundingBox
            onFace([Float(0.5 - box.midX) * 2, Float(box.midY - 0.5) * 2])
        } catch { onFace(nil) }
    }
}
#endif
