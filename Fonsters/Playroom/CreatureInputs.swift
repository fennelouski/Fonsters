#if os(macOS) || os(iOS)
import Foundation
import AVFoundation
import Speech
import Vision
import Observation
import simd

/// Explicit opt-in only. Speech must support on-device recognition; no cloud
/// fallback or asset installation. Audio, frames and transcripts are transient.
@MainActor @Observable
final class CreatureInputs {
    private(set) var microphoneEnabled = false
    private(set) var cameraEnabled = false
    private(set) var level: Float = 0
    private(set) var status = "Camera and microphone are off."
    private(set) var lastAction: CreatureSpokenAction?
    @ObservationIgnored var onVoiceActivity: (() -> Void)?
    @ObservationIgnored var onFace: ((SIMD2<Float>) -> Void)?
    @ObservationIgnored var onMirror: ((CreatureMirrorSample) -> Void)?
    @ObservationIgnored var onCommand: ((CreatureSpokenAction) -> Void)?
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognition: SFSpeechRecognitionTask?
    @ObservationIgnored private var restart: Task<Void, Never>?
    @ObservationIgnored private var camera: FaceCaptureWorker?
    @ObservationIgnored private var suspended = false
    @ObservationIgnored private var microphoneAllowed = false
    @ObservationIgnored private var cameraAllowed = false
    @ObservationIgnored private var microphoneGeneration = 0
    @ObservationIgnored private var cameraGeneration = 0
    @ObservationIgnored private var microphoneConsentGeneration = 0
    @ObservationIgnored private var cameraConsentGeneration = 0
    @ObservationIgnored private var utterance: Task<Void, Never>?
    @ObservationIgnored private var spokenCandidate: CreatureSpokenAction?
    @ObservationIgnored private var delivered = false
    @ObservationIgnored private var lastVoice = Date.distantPast
    @ObservationIgnored private var lastMeter = Date.distantPast
    @ObservationIgnored private var interruption: NSObjectProtocol?
    private var synthetic: Bool { ProcessInfo.processInfo.arguments.contains("--verify-live-inputs") }

    init() {
        #if os(iOS)
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stopAll() }
        }
        #endif
    }
    func toggleMicrophone() {
        if microphoneEnabled { microphoneConsentGeneration += 1; microphoneEnabled = false; stopMicrophone(); status = "Microphone off."; return }
        if synthetic { microphoneEnabled = true; status = "Synthetic voice fixture · no microphone opened."; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.supportsOnDeviceRecognition else {
            status = "On-device speech isn’t available for this language. Use the action icons or type a request."; return
        }
        microphoneEnabled = true; microphoneConsentGeneration += 1; let generation = microphoneConsentGeneration
        Task { @MainActor in
            let speech = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
            }
            guard generation == microphoneConsentGeneration, microphoneEnabled else { return }
            guard speech else { microphoneEnabled = false; status = "Speech access wasn’t granted."; return }
            microphoneAllowed = await AVCaptureDevice.requestAccess(for: .audio)
            guard generation == microphoneConsentGeneration, microphoneEnabled else { return }
            guard microphoneAllowed else { microphoneEnabled = false; status = "Microphone access wasn’t granted."; return }
            if !suspended { startMicrophone() }
        }
    }
    func toggleCamera() {
        if cameraEnabled { cameraConsentGeneration += 1; cameraEnabled = false; stopCamera(); status = "Camera off."; return }
        if synthetic { cameraEnabled = true; status = "Synthetic camera fixture · no camera opened."; return }
        cameraEnabled = true; cameraConsentGeneration += 1; let generation = cameraConsentGeneration
        Task { @MainActor in
            cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
            guard generation == cameraConsentGeneration, cameraEnabled else { return }
            guard cameraAllowed else { cameraEnabled = false; status = "Camera access wasn’t granted."; return }
            if !suspended { startCamera() }
        }
    }
    func setSuspended(_ value: Bool) {
        guard suspended != value else { return }; suspended = value
        if value { stopMicrophone(); stopCamera(); status = "Inputs paused with the world." }
        else if !synthetic {
            if microphoneEnabled && microphoneAllowed { startMicrophone() }
            if cameraEnabled && cameraAllowed { startCamera() }
        }
    }
    func stopAll() {
        microphoneConsentGeneration += 1; cameraConsentGeneration += 1
        microphoneEnabled = false; cameraEnabled = false; lastAction = nil
        stopMicrophone(); stopCamera(); status = "Camera and microphone are off."
    }
    func verifyCommand(_ text: String) {
        guard synthetic, microphoneEnabled, !suspended else { return }
        delivered = false; receiveSpeech(text, final: true, generation: microphoneGeneration)
    }
    func verifyMirror(_ sample: CreatureMirrorSample) { guard synthetic, cameraEnabled, !suspended else { return }; onMirror?(sample) }

    private func startMicrophone() {
        guard engine == nil, microphoneEnabled, !suspended,
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            if engine == nil { microphoneEnabled = false; status = "Local speech is unavailable right now." }; return
        }
        #if os(iOS)
        do { try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers]); try AVAudioSession.sharedInstance().setActive(true) }
        catch { microphoneEnabled = false; status = "Microphone is unavailable right now."; return }
        #endif
        let audio = AVAudioEngine(), input = audio.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { microphoneEnabled = false; status = "No microphone is available."; return }
        microphoneGeneration += 1; let generation = microphoneGeneration
        let speech = SFSpeechAudioBufferRecognitionRequest()
        speech.requiresOnDeviceRecognition = true; speech.shouldReportPartialResults = true
        speech.contextualStrings = CreatureSpokenAction.allCases.map(\.rawValue)
        request = speech; delivered = false; spokenCandidate = nil
        recognition = recognizer.recognitionTask(with: speech) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString, final = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, generation == self.microphoneGeneration, self.microphoneEnabled, !self.suspended else { return }
                if let text { self.receiveSpeech(text, final: final, generation: generation) }
                if failed || final { self.restartMicrophone(generation: generation, failed: failed) }
            }
        }
        // The native tap appends synchronously; buffers never cross into a Task.
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self, speech] buffer, _ in
            speech.append(buffer)
            guard let samples = buffer.floatChannelData?[0] else { return }
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
            let rms = sqrt(sum / Float(max(1, buffer.frameLength)))
            Task { @MainActor [weak self] in
                guard let self, generation == self.microphoneGeneration, self.microphoneEnabled, !self.suspended else { return }
                let now = Date()
                if now.timeIntervalSince(self.lastMeter) > 0.12 { self.level = min(1, rms * 12); self.lastMeter = now }
                if self.onCommand == nil, rms > 0.035, now.timeIntervalSince(self.lastVoice) > 2.6 { self.lastVoice = now; self.onVoiceActivity?() }
            }
        }
        do { try audio.start(); engine = audio; status = "Listening locally · sleep, jump, wave, dance or stop." }
        catch { input.removeTap(onBus: 0); stopMicrophone(); microphoneEnabled = false; status = "Couldn’t start local speech." }
    }
    private func receiveSpeech(_ text: String, final: Bool, generation: Int) {
        guard !delivered else { return }
        utterance?.cancel(); utterance = nil
        spokenCandidate = CreatureSpokenAction.parse(text)
        guard let candidate = spokenCandidate else { return }
        if final { deliver(candidate); return }
        // A stable phrase gives negation/extra actions time to invalidate it.
        utterance = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(900)) } catch { return }
            guard let self, generation == self.microphoneGeneration, self.microphoneEnabled, !self.suspended,
                  self.spokenCandidate == candidate else { return }
            // Final recognition decides the complete utterance. Never execute
            // an intermediate phrase that may still acquire a negation/action.
            self.engine?.pause(); self.request?.endAudio()
        }
    }
    private func deliver(_ action: CreatureSpokenAction) { delivered = true; lastAction = action; onCommand?(action); status = "Heard " + action.rawValue + "." }
    private func restartMicrophone(generation: Int, failed: Bool) {
        guard generation == microphoneGeneration else { return }; stopMicrophone()
        if failed { microphoneEnabled = false; status = "Local speech stopped. Tap the microphone to try again."; return }
        restart = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard let self, self.microphoneEnabled, !self.suspended, !self.synthetic else { return }
            self.startMicrophone()
        }
    }
    private func stopMicrophone() {
        microphoneGeneration += 1; utterance?.cancel(); utterance = nil; restart?.cancel(); restart = nil
        engine?.inputNode.removeTap(onBus: 0); engine?.stop(); engine = nil
        request?.endAudio(); recognition?.cancel(); recognition = nil; request = nil
        level = 0; spokenCandidate = nil; delivered = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
    private func startCamera() {
        guard camera == nil, cameraEnabled, !suspended else { return }
        cameraGeneration += 1; let generation = cameraGeneration
        let worker = FaceCaptureWorker(onSample: { [weak self] sample in
            Task { @MainActor [weak self] in
                guard let self, self.cameraGeneration == generation, self.cameraEnabled, !self.suspended else { return }
                self.onFace?(sample.gaze); self.onMirror?(sample)
                self.status = sample.found ? "Camera on · mirroring eyes, head and raised hands." : "Camera on · step into view."
            }
        }, onFailure: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.cameraGeneration == generation else { return }
                self.cameraEnabled = false; self.stopCamera(); self.status = "Couldn’t start the camera."
            }
        })
        camera = worker; worker.start(); status = "Camera on · step into view."
    }
    private func stopCamera() { cameraGeneration += 1; camera?.stop(); camera = nil; onFace?(.zero); onMirror?(.init(found: false)) }
}

/// Safety invariant: all capture and calibration state belongs to this serial
/// delegate queue. Only Sendable numeric values leave it, never buffers/requests.
nonisolated final class FaceCaptureWorker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "Fonsters.LocalMirror", qos: .utility)
    private let session = AVCaptureSession()
    private let onSample: @Sendable (CreatureMirrorSample) -> Void
    private let onFailure: @Sendable () -> Void
    private var lastFrame: TimeInterval = 0
    private var previousCenter: SIMD2<Float>?
    private var openEyeBaseline: Float = 0.20
    init(onSample: @escaping @Sendable (CreatureMirrorSample) -> Void, onFailure: @escaping @Sendable () -> Void) {
        self.onSample = onSample; self.onFailure = onFailure; super.init()
    }
    func start() {
        queue.async { [self] in
            #if os(iOS)
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            #else
            let device = AVCaptureDevice.default(for: .video)
            #endif
            guard let device, let input = try? AVCaptureDeviceInput(device: device) else { onFailure(); return }
            session.beginConfiguration(); session.sessionPreset = .medium
            guard session.canAddInput(input) else { session.commitConfiguration(); onFailure(); return }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput(); output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else { session.commitConfiguration(); onFailure(); return }
            session.addOutput(output)
            #if os(iOS)
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            #endif
            session.commitConfiguration(); session.startRunning()
            if !session.isRunning { onFailure() }
        }
    }
    func stop() { queue.async { [self] in session.stopRunning() } }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date.timeIntervalSinceReferenceDate
        guard now - lastFrame > 0.18 else { return }; lastFrame = now
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let faceRequest = VNDetectFaceLandmarksRequest(), bodyRequest = VNDetectHumanBodyPoseRequest()
        do {
            try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up).perform([faceRequest, bodyRequest])
            guard let face = faceRequest.results?.filter({ $0.confidence >= 0.6 }).max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
                previousCenter = nil; onSample(.init(found: false)); return
            }
            let box = face.boundingBox, center = SIMD2(Float(box.midX), Float(box.midY))
            var sample = CreatureMirrorSample(gaze: [(0.5 - center.x) * 2, (center.y - 0.5) * 2])
            sample.motion = previousCenter.map { min(1, simd_length(center - $0) * 18) } ?? 0; previousCenter = center
            sample.tilt = min(0.22, max(-0.22, -(face.roll?.floatValue ?? 0)))
            if let left = face.landmarks?.leftEye, let right = face.landmarks?.rightEye {
                func ratio(_ eye: VNFaceLandmarkRegion2D) -> Float {
                    let points = eye.normalizedPoints
                    guard points.count >= 4 else { return 0.2 }
                    let xs = points.map { Float($0.x) * Float(box.width) }, ys = points.map { Float($0.y) * Float(box.height) }
                    return (ys.max()! - ys.min()!) / max(0.001, xs.max()! - xs.min()!)
                }
                let value = (ratio(left) + ratio(right)) * 0.5
                openEyeBaseline = max(openEyeBaseline * 0.998, min(0.4, value))
                sample.eyeOpenness = min(1, max(0.06, value / max(0.17, openEyeBaseline)))
            }
            if let body = bodyRequest.results?.first, let points = try? body.recognizedPoints(.all) {
                if let neck = points[.neck], neck.confidence > 0.3, abs(Float(neck.location.x) - center.x) < max(0.15, Float(box.width)) {
                    for (wristKey, shoulderKey) in [(VNHumanBodyPoseObservation.JointName.leftWrist, VNHumanBodyPoseObservation.JointName.leftShoulder), (.rightWrist, .rightShoulder)] {
                        if let wrist = points[wristKey], let shoulder = points[shoulderKey], wrist.confidence > 0.4, shoulder.confidence > 0.4 {
                            let height = min(1, max(0, Float(wrist.location.y - shoulder.location.y) * 5 + 0.35))
                            if height > sample.raisedHand { sample.raisedHand = height; sample.handX = Float(wrist.location.x) }
                        }
                    }
                }
            }
            onSample(sample)
        } catch { onSample(.init(found: false)) }
    }
}
#endif
