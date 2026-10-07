import Foundation
import ImageIO
import UniformTypeIdentifiers

struct CapturedFrame: Decodable {
    let file: String
    let time: Double
    let segment: String
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let sourceLabel = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "sampled screenshots of the real native app"
let frames = try JSONDecoder().decode([CapturedFrame].self, from: Data(contentsOf: directory.appendingPathComponent("frames.json")))
guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { fatalError("Cannot create GIF") }
CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (i, frame) in frames.enumerated() {
    let source = CGImageSourceCreateWithURL(directory.appendingPathComponent(frame.file) as CFURL, nil)!
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1280]
    let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)!
    let delay = i + 1 < frames.count ? min(2, max(0.1, (frames[i + 1].time - frame.time) / 1000)) : 0.8
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: delay, kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
}
precondition(CGImageDestinationFinalize(destination))
let decoded = CGImageSourceCreateWithURL(output as CFURL, nil)!
precondition(CGImageSourceGetCount(decoded) == frames.count)
print("PASS: saved and decoded \(frames.count) \(sourceLabel) as a GIF. No audio or camera frames recorded.")
