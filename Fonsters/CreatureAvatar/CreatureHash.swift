//
//  CreatureHash.swift
//  Fonsters
//
//  Segmented hashing so the same seed + segmentId always yields the same value.
//  Uses a 256-bit internal hash (8× UInt32 lanes, djb2-style mix, UTF-16 code
//  units). No system RNG; deterministic and cross-platform. Matches the web
//  implementation for compatibility.
//

import Foundation

private let DJB2_INIT: UInt32 = 5381

private func mix32(_ h: UInt32, _ byte: UInt8) -> UInt32 {
    let next = ((h << 5) &+ h) ^ UInt32(byte)
    return next
}

/// 256-bit hash of a string. Eight 32-bit lanes, combined big-endian.
private func stringHash256(_ str: String) -> (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32) {
    var lanes: [UInt32] = [
        DJB2_INIT, DJB2_INIT + 1, DJB2_INIT + 2, DJB2_INIT + 3,
        DJB2_INIT + 4, DJB2_INIT + 5, DJB2_INIT + 6, DJB2_INIT + 7
    ]
    let utf16 = Array(str.utf16)
    for (i, codeUnit) in utf16.enumerated() {
        let lane = i % 8
        let low = UInt8(codeUnit & 0xFF)
        let high = UInt8((codeUnit >> 8) & 0xFF)
        lanes[lane] = mix32(lanes[lane], low)
        lanes[lane] = mix32(lanes[lane], high)
    }
    return (lanes[0], lanes[1], lanes[2], lanes[3], lanes[4], lanes[5], lanes[6], lanes[7])
}

/// Returns a value in [0, 1) for the given seed and segment id.
/// Top 53 bits of 256-bit hash / 2^53.
public func segmentHash(seed: String, segmentId: String) -> Double {
    let combined = seed + "\0" + segmentId
    let (l0, l1, l2, l3, l4, l5, l6, l7) = stringHash256(combined)
    // Top 53 bits: lane0 (32 bits) + top 21 bits of lane1
    let top53 = (UInt64(l0) << 21) | (UInt64(l1) >> 11)
    return Double(top53) / 9007199254740992.0  // 2^53
}

/// Pick an option index 0..(n-1) from segment hash.
public func segmentPick(seed: String, segmentId: String, n: Int) -> Int {
    guard n > 0 else { return 0 }
    let u = segmentHash(seed: seed, segmentId: segmentId)
    return Int(floor(u * Double(n))) % n
}

/// Roll: returns true with probability p (0..1).
public func segmentRoll(seed: String, segmentId: String, p: Double) -> Bool {
    return segmentHash(seed: seed, segmentId: segmentId) < p
}
