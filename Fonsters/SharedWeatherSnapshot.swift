import Foundation

/// Public weather payload only: no account, identity, raw provider data or
/// travel history. Epoch milliseconds retain Apple's procurement/expiry times.
nonisolated struct SharedWeatherSnapshot: Decodable, Sendable {
    struct Point: Codable, Sendable { let latitude: Double; let longitude: Double }
    struct Attribution: Decodable, Sendable {
        let serviceName: String
        let markURL: URL
        let darkMarkURL: URL
        let legalPageURL: URL
    }
    struct Provenance: Decodable, Sendable { let provider: String; let transformed: Bool }
    struct Condition: Decodable, Sendable { let code: String; let temperatureC: Double; let daylight: Bool }
    struct Current: Decodable, Sendable {
        let observedAt: Double; let expiresAt: Double; let providerExpiresAt: Double; let condition: Condition
    }
    struct Hour: Decodable, Sendable {
        let startAt: Double; let code: String; let temperatureC: Double; let daylight: Bool; let precipitationChance: Double
    }
    struct Hourly: Decodable, Sendable {
        let observedAt: Double; let expiresAt: Double; let providerExpiresAt: Double; let hours: [Hour]
    }
    struct Datasets: Decodable, Sendable { let current: Current; let hourly: Hourly }
    let version: Int; let location: Point; let datasets: Datasets
    let expiresAt: Double; let source: String; let stale: Bool
    let attribution: Attribution; let provenance: Provenance
    enum Failure: Error { case invalidSnapshot }

    static func decode(_ data: Data, for point: Point, now: Date) throws -> Self {
        guard data.count <= 65_536 else { throw Failure.invalidSnapshot }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.isValid(for: point, now: now) else { throw Failure.invalidSnapshot }
        return value
    }
    /// Recheck before displaying a cached value, including after foregrounding.
    func isValid(for point: Point, now: Date) -> Bool {
        let clock = now.timeIntervalSince1970 * 1000, hour = 3_600_000.0, ttl = 2 * hour
        func legal(_ url: URL) -> Bool {
            url.scheme == "https" && url.host == "weatherkit.apple.com" && url.port == nil &&
            url.user == nil && url.password == nil && url.fragment == nil
        }
        func coordinates(_ p: Point) -> Bool {
            p.latitude.isFinite && p.longitude.isFinite && abs(p.latitude) <= 90 && abs(p.longitude) <= 180
        }
        func timestamp(_ read: Double, _ expiry: Double, _ provider: Double) -> Bool {
            read.isFinite && expiry.isFinite && provider.isFinite && read <= clock && clock - read < ttl &&
            expiry > clock && expiry <= read + ttl && expiry <= provider
        }
        guard coordinates(point), coordinates(location), version == 2, !stale,
              ["apple", "cache"].contains(source), provenance.provider == "apple-weather", !provenance.transformed,
              attribution.serviceName == "Apple Weather", legal(attribution.markURL), legal(attribution.darkMarkURL), legal(attribution.legalPageURL),
              timestamp(datasets.current.observedAt, datasets.current.expiresAt, datasets.current.providerExpiresAt),
              timestamp(datasets.hourly.observedAt, datasets.hourly.expiresAt, datasets.hourly.providerExpiresAt),
              expiresAt == min(datasets.current.expiresAt, datasets.hourly.expiresAt),
              datasets.current.condition.temperatureC.isFinite, !datasets.current.condition.code.isEmpty,
              datasets.current.condition.code.count <= 64, datasets.hourly.hours.count == 24 else { return false }
        let radians = Double.pi / 180
        let dlat = (location.latitude - point.latitude) * radians
        let dlon = (location.longitude - point.longitude) * radians
        let haversine = pow(sin(dlat / 2), 2) + cos(location.latitude * radians) * cos(point.latitude * radians) * pow(sin(dlon / 2), 2)
        let kilometres = 6371 * 2 * atan2(sqrt(max(0, haversine)), sqrt(max(0, 1 - haversine)))
        guard kilometres <= 30 else { return false }
        let start = floor(clock / hour) * hour
        return datasets.hourly.hours.enumerated().allSatisfy { index, value in
            value.startAt == start + Double(index) * hour && value.temperatureC.isFinite &&
            !value.code.isEmpty && value.code.count <= 64 && value.precipitationChance.isFinite &&
            (0...1).contains(value.precipitationChance)
        }
    }
}
