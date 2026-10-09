import AppKit
import CoreGraphics
import ScreenCaptureKit
import AVFoundation

/// Records only this checkout's preview window. No desktop, microphone,
/// camera, permission request, or other application is included.
final class WindowRecorder: NSObject, SCStreamOutput, @unchecked Sendable {
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    var started = false
    var lastTime = CMTime.zero
    init(url: URL, width: Int, height: Int) throws {
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
        input.expectsMediaDataInRealTime = true
        super.init(); writer.add(input)
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sample.isValid, let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]], let value = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: value) == .complete else { return }
        let timestamp = sample.presentationTimeStamp
        if !started { started = writer.startWriting(); writer.startSession(atSourceTime: timestamp) }
        if started && input.isReadyForMoreMediaData { _ = input.append(sample); lastTime = timestamp }
    }
}
@main struct RecordFonstersWindow {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        guard CommandLine.arguments.count == 4, CGPreflightScreenCaptureAccess(), let seconds = Double(CommandLine.arguments[3]), (1...30).contains(seconds) else { throw CocoaError(.featureUnsupported) }
        let appURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
        guard appURL.lastPathComponent == "Fonsters.app", appURL.path.contains("/.prototype-build/"), let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.standardizedFileURL == appURL }) else { throw CocoaError(.fileNoSuchFile) }
        let available = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = available.windows.filter({ $0.owningApplication?.processID == app.processIdentifier && $0.frame.width >= 320 && $0.frame.height >= 300 }).max(by: { $0.frame.width < $1.frame.width }) else { throw CocoaError(.featureUnsupported) }
        let config = SCStreamConfiguration(); config.width = Int(window.frame.width); config.height = Int(window.frame.height)
        config.showsCursor = false; config.capturesAudio = false; config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        let recorder = try WindowRecorder(url: URL(fileURLWithPath: CommandLine.arguments[2]), width: config.width, height: config.height)
        let queue = DispatchQueue(label: "Fonsters.WindowEvidence")
        let stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: window), configuration: config, delegate: nil)
        try stream.addStreamOutput(recorder, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        try await Task.sleep(for: .seconds(seconds))
        try await stream.stopCapture()
        queue.sync { recorder.input.markAsFinished() }
        await recorder.writer.finishWriting()
        guard recorder.writer.status == .completed else { throw recorder.writer.error ?? CocoaError(.fileWriteUnknown) }
        print("Recorded \(seconds)s of this actual Fonsters window, without audio.")
    }
}
