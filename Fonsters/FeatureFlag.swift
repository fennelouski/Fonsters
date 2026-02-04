//
//  FeatureFlag.swift
//  Fonsters
//
//  Type-safe, local-first feature flags with optional remote override.
//  Resolution order: remote override > local override (UserDefaults) > bundled default.
//  Use App Group UserDefaults to share overrides across app and extensions.
//

import Foundation
import SwiftUI
import Combine

// MARK: - App Group

/// App Group identifier for sharing feature-flag overrides across main app and extensions.
/// Set this in the Apple Developer portal and add the capability to each target's entitlements.
/// If nil or suite unavailable, falls back to UserDefaults.standard per target.
private let featureFlagAppGroupID = "group.com.nathanfennel.Fonsters"

// MARK: - Flag definition

/// A single feature flag. Add cases here; each has a string key (for persistence/remote) and a default value.
enum FeatureFlag: String, CaseIterable {
    case showBirthdayOverlay = "show_birthday_overlay"
    case creatureGlowEffect = "creature_glow_effect"

    /// Default value when no override is set.
    var defaultValue: Bool {
        switch self {
        case .showBirthdayOverlay: return true
        case .creatureGlowEffect: return true
        }
    }

    var key: String { rawValue }
}

// MARK: - Remote provider protocol

/// Optional remote source for flag overrides. Implement to fetch from Firebase Remote Config, your API, etc.
protocol FeatureFlagRemoteProviding: Sendable {
    func fetchOverrides() async -> [String: Bool]
}

/// No-op implementation; use when no remote is configured (e.g. in extensions).
struct NoOpFeatureFlagRemoteProvider: FeatureFlagRemoteProviding {
    func fetchOverrides() async -> [String: Bool] { [:] }
}

/// Fetches flag overrides via GET from a URL. Expects JSON object with string keys and boolean values.
struct HTTPFeatureFlagRemoteProvider: FeatureFlagRemoteProviding {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func fetchOverrides() async -> [String: Bool] {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return [:]
            }
            return Self.parseFlags(data)
        } catch {
            #if DEBUG
            NSLog("Fonsters: Feature flag fetch failed: \(error)")
            #endif
            return [:]
        }
    }

    private static func parseFlags(_ data: Data) -> [String: Bool] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var result: [String: Bool] = [:]
        for (key, value) in json {
            if let b = value as? Bool {
                result[key] = b
            } else if let n = value as? Int, (n == 0 || n == 1) {
                result[key] = (n == 1)
            }
        }
        return result
    }
}

/// Reads the feature-flag backend URL from Info.plist (key: FeatureFlagBackendURL).
/// Returns nil if missing or invalid so the app can fall back to NoOpFeatureFlagRemoteProvider.
enum FeatureFlagBackendConfiguration {
    static func backendURL() -> URL? {
        guard let raw = Bundle.main.infoDictionary?["FeatureFlagBackendURL"] as? String,
              !raw.isEmpty,
              let url = URL(string: raw) else {
            return nil
        }
        return url
    }
}

// MARK: - Store

/// Thread-safe store for feature flags. Reads resolve remote > local > default.
/// Lock-on-read: the first time a flag is read in a session, that value is cached and returned
/// for all subsequent reads until the next app launch. Locks are in-memory only.
/// Writes (local override, apply remote) are applied on main and trigger SwiftUI updates.
final class FeatureFlagStore: ObservableObject {
    private let defaults: UserDefaults
    private let remoteProvider: (any FeatureFlagRemoteProviding)?
    private let queue = DispatchQueue(label: "com.fonsters.featureflags", qos: .userInitiated)
    private var _remoteOverrides: [String: Bool] = [:]
    private var _lockedValues: [String: Bool] = [:]
    private var remoteOverrides: [String: Bool] {
        queue.sync { _remoteOverrides }
    }

    /// - Parameter defaults: If provided (e.g. in tests), used for local overrides; otherwise App Group suite or standard.
    init(remoteProvider: (any FeatureFlagRemoteProviding)? = nil, defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: featureFlagAppGroupID) ?? .standard
        self.remoteProvider = remoteProvider
    }

    // MARK: Read (thread-safe, lock-on-read)

    /// Effective value for a boolean flag. First read in a session locks the value until next launch.
    /// Safe to call from any thread.
    func isEnabled(_ flag: FeatureFlag) -> Bool {
        queue.sync {
            if let locked = _lockedValues[flag.key] { return locked }
            let value: Bool
            if let remote = _remoteOverrides[flag.key] {
                value = remote
            } else if defaults.object(forKey: localOverrideKey(flag.key)) != nil {
                value = defaults.bool(forKey: localOverrideKey(flag.key))
            } else {
                value = flag.defaultValue
            }
            _lockedValues[flag.key] = value
            return value
        }
    }

    // MARK: Local override (persisted; call on main for SwiftUI)

    /// Persist a local override for the given flag key. Use for debug UI or per-device overrides.
    func setLocalOverride(_ value: Bool?, for flag: FeatureFlag) {
        let key = localOverrideKey(flag.key)
        if let value = value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        objectWillChange.send()
    }

    /// Remove local override so the flag falls back to remote or default.
    func clearLocalOverride(for flag: FeatureFlag) {
        setLocalOverride(nil, for: flag)
    }

    /// Whether a local override is set for this flag (used by debug UI).
    func hasLocalOverride(for flag: FeatureFlag) -> Bool {
        defaults.object(forKey: localOverrideKey(flag.key)) != nil
    }

    /// Current local override value if any; nil means use remote or default.
    func localOverrideValue(for flag: FeatureFlag) -> Bool? {
        guard hasLocalOverride(for: flag) else { return nil }
        return defaults.bool(forKey: localOverrideKey(flag.key))
    }

    // MARK: Remote overrides (in-memory; call on main for SwiftUI)

    /// Apply overrides from a remote provider. Call after fetching (e.g. on launch).
    func applyRemoteOverrides(_ overrides: [String: Bool]) {
        queue.sync { _remoteOverrides = overrides }
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    /// Trigger a fetch from the configured remote provider and apply results. Call from main app only.
    func refreshFromRemote() {
        guard let provider = remoteProvider else { return }
        Task {
            let overrides = await provider.fetchOverrides()
            await MainActor.run {
                applyRemoteOverrides(overrides)
            }
        }
    }

    // MARK: Helpers

    private func localOverrideKey(_ flagKey: String) -> String {
        "Fonsters.FeatureFlag.override.\(flagKey)"
    }
}

// MARK: - Debug UI (DEBUG only)

#if DEBUG
/// Debug-only sheet to view and toggle local overrides for all feature flags.
struct FeatureFlagDebugSheet: View {
    @ObservedObject var store: FeatureFlagStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(FeatureFlag.allCases), id: \.key) { flag in
                    FeatureFlagDebugRow(flag: flag, store: store)
                }
            }
            .navigationTitle("Feature Flags")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct FeatureFlagDebugRow: View {
    let flag: FeatureFlag
    @ObservedObject var store: FeatureFlagStore

    /// 0 = Default, 1 = On, 2 = Off
    private var overrideSegment: Int {
        guard let value = store.localOverrideValue(for: flag) else { return 0 }
        return value ? 1 : 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(flag.key)
                .font(.subheadline.weight(.medium))
            Text("Effective: \(store.isEnabled(flag) ? "On" : "Off") · Default: \(flag.defaultValue ? "On" : "Off")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Override", selection: Binding(
                get: { overrideSegment },
                set: { newValue in
                    switch newValue {
                    case 0: store.clearLocalOverride(for: flag)
                    case 1: store.setLocalOverride(true, for: flag)
                    case 2: store.setLocalOverride(false, for: flag)
                    default: break
                    }
                }
            )) {
                Text("Default").tag(0)
                Text("On").tag(1)
                Text("Off").tag(2)
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}
#endif
