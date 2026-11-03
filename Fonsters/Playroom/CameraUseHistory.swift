import Foundation

/// Device-local review/use times only. No frames, biometric data or shared IDs.
@MainActor final class CameraUseHistory {
    private let defaults: UserDefaults
    private let prefix = "fonsters.camera.v1."
    static let interval: TimeInterval = 30 * 24 * 60 * 60
    init(defaults: UserDefaults? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        if let defaults { self.defaults = defaults }
        else if let i = arguments.firstIndex(of: "--camera-history-suite"), arguments.indices.contains(i + 1),
                let isolated = UserDefaults(suiteName: arguments[i + 1]) { self.defaults = isolated }
        else { self.defaults = .standard }
    }
    func needsEducation(at date: Date = Date()) -> Bool {
        let latest = max(defaults.double(forKey: prefix + "review"), defaults.double(forKey: prefix + "use"))
        let age = date.timeIntervalSince1970 - latest
        return latest <= 0 || age < 0 || age >= Self.interval
    }
    func reviewed(at date: Date = Date()) {
        defaults.set(date.timeIntervalSince1970, forKey: prefix + "review")
        if defaults.double(forKey: prefix + "use") > date.timeIntervalSince1970 {
            defaults.set(0, forKey: prefix + "use")
        }
    }
    func used(at date: Date = Date()) {
        // Avoid a disk/defaults write on every processed frame.
        if date.timeIntervalSince1970 - defaults.double(forKey: prefix + "use") >= 60 {
            defaults.set(date.timeIntervalSince1970, forKey: prefix + "use")
        }
    }
}
