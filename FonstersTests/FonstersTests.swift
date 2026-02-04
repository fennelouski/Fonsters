//
//  FonstersTests.swift
//  FonstersTests
//
//  Created by Nathan Fennel on 2/3/26.
//

import Foundation
import Testing
@testable import Fonsters

struct FonstersTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func similarNamesProduceDifferentHashes() async throws {
        // Jonathan Lora vs Jonathan Lord differ only in last character ('a' vs 'd').
        let seedA = "Jonathan Lora"
        let seedB = "Jonathan Lord"
        let segmentIds = ["complexity_tier", "avatar_mode", "palette", "symmetry_axis", "eyes", "mouth"]
        var anyDifferent = false
        for seg in segmentIds {
            let hA = segmentHash(seed: seedA, segmentId: seg)
            let hB = segmentHash(seed: seedB, segmentId: seg)
            if hA != hB { anyDifferent = true; break }
        }
        #expect(anyDifferent, "Similar names should produce different segment hashes")
    }

    @Test func segmentHashDistributionIsUniform() async throws {
        // Ensure segmentHash produces values uniformly in [0, 1) so segmentRoll
        // triggers as intended (mouth, nose, body, eyebrows, etc.).
        var buckets = [Int](repeating: 0, count: 10)
        let segmentIds = ["a", "b", "mouth", "nose", "body", "eyes", "palette", "tier", "x", "y"]
        for i in 0..<2000 {
            let seed = "seed-\(i)-\(i * 31)"
            for seg in segmentIds {
                let u = segmentHash(seed: seed, segmentId: seg)
                #expect(u >= 0 && u < 1, "segmentHash must be in [0, 1), got \(u)")
                let bin = min(Int(u * 10), 9)
                buckets[bin] += 1
            }
        }
        let total = buckets.reduce(0, +)
        let expectedPerBin = Double(total) / 10
        for (i, count) in buckets.enumerated() {
            let ratio = Double(count) / expectedPerBin
            #expect(ratio >= 0.5 && ratio <= 1.5, "Bucket \(i) has \(count) (expected ~\(Int(expectedPerBin))); ratio \(ratio)")
        }
    }

    // MARK: - Feature flags

    @Test func featureFlagUsesDefaultWhenNoOverrides() async throws {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = FeatureFlagStore(remoteProvider: NoOpFeatureFlagRemoteProvider(), defaults: suite)
        #expect(store.isEnabled(.showBirthdayOverlay) == true, "showBirthdayOverlay default is true")
    }

    @Test func featureFlagLocalOverrideWinsOverDefault() async throws {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = FeatureFlagStore(remoteProvider: NoOpFeatureFlagRemoteProvider(), defaults: suite)
        store.setLocalOverride(false, for: .showBirthdayOverlay)
        #expect(store.isEnabled(.showBirthdayOverlay) == false)
        store.setLocalOverride(true, for: .showBirthdayOverlay)
        #expect(store.isEnabled(.showBirthdayOverlay) == true)
    }

    @Test func featureFlagRemoteOverrideWinsOverLocal() async throws {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = FeatureFlagStore(remoteProvider: NoOpFeatureFlagRemoteProvider(), defaults: suite)
        store.setLocalOverride(true, for: .showBirthdayOverlay)
        store.applyRemoteOverrides([FeatureFlag.showBirthdayOverlay.key: false])
        #expect(store.isEnabled(.showBirthdayOverlay) == false, "Remote override should win over local")
    }

    @Test func featureFlagLockOnRead_unchangedByLaterRemoteOverride() async throws {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = FeatureFlagStore(remoteProvider: NoOpFeatureFlagRemoteProvider(), defaults: suite)
        let first = store.isEnabled(.showBirthdayOverlay)
        #expect(first == true, "default is true")
        store.applyRemoteOverrides([FeatureFlag.showBirthdayOverlay.key: false])
        let second = store.isEnabled(.showBirthdayOverlay)
        #expect(second == true, "locked value should not change after later remote override")
    }

    @Test func featureFlagLockOnRead_unreadFlagGetsNewRemoteValue() async throws {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = FeatureFlagStore(remoteProvider: NoOpFeatureFlagRemoteProvider(), defaults: suite)
        _ = store.isEnabled(.showBirthdayOverlay)
        store.applyRemoteOverrides([FeatureFlag.creatureGlowEffect.key: false])
        #expect(store.isEnabled(.creatureGlowEffect) == false, "first read of unread flag uses latest remote")
    }

}
