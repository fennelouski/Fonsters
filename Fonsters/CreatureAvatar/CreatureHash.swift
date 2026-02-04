//
//  CreatureHash.swift
//  Fonsters
//
//  Hash the seed ONCE to produce 256 bits. Each segment uses a different COMBINATION
//  of those bits (keyed by segmentId). The string is never used directly—only its
//  hash. Any change to the string changes the entire hash, so all segments change.
//

import Foundation

private let DJB2_INIT: UInt32 = 5381

private func mix32(_ h: UInt32, _ byte: UInt8) -> UInt32 {
    ((h << 5) &+ h) ^ UInt32(byte)
}

/// MurmurHash3-style finalizer: avalanches bits so similar inputs produce very different outputs.
private func fmix32(_ h: UInt32) -> UInt32 {
    var k = h
    k ^= k >> 16
    k = k &* 0x85ebca6b
    k ^= k >> 13
    k = k &* 0xc2b2ae35
    k ^= k >> 16
    return k
}

/// Hash the seed string ONCE. Returns 8×32-bit lanes.
/// Each character updates ALL lanes (with position-dependent mixing) so that adding,
/// removing, or changing any character changes the entire hash. Length is not used.
private func seedHash256(_ seed: String) -> (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32) {
    var lanes: [UInt32] = [
        DJB2_INIT, DJB2_INIT + 1, DJB2_INIT + 2, DJB2_INIT + 3,
        DJB2_INIT + 4, DJB2_INIT + 5, DJB2_INIT + 6, DJB2_INIT + 7
    ]
    let utf16 = Array(seed.utf16)
    for (i, codeUnit) in utf16.enumerated() {
        let low = UInt8(codeUnit & 0xFF)
        let high = UInt8((codeUnit >> 8) & 0xFF)
        for lane in 0..<8 {
            let k = UInt32(i) &* 31 &+ UInt32(lane) &* 17
            lanes[lane] = mix32(lanes[lane], low ^ UInt8((k >> 0) & 0xFF))
            lanes[lane] = mix32(lanes[lane], high ^ UInt8((k >> 8) & 0xFF))
        }
    }
    return (
        fmix32(lanes[0]), fmix32(lanes[1]), fmix32(lanes[2]), fmix32(lanes[3]),
        fmix32(lanes[4]), fmix32(lanes[5]), fmix32(lanes[6]), fmix32(lanes[7])
    )
}

/// 53-bit mixer from segmentId. Used to pick which combination of seed-hash bits we use.
private func segmentMixer53(_ segmentId: String) -> UInt64 {
    var lo: UInt32 = 5381
    var hi: UInt32 = 5381
    for (j, byte) in segmentId.utf8.enumerated() {
        let b = UInt32(byte)
        if j % 2 == 0 {
            lo = ((lo << 5) &+ lo) ^ b
        } else {
            hi = ((hi << 5) &+ hi) ^ b
        }
    }
    return (UInt64(fmix32(hi)) << 21) | UInt64(fmix32(lo) >> 11)
}

/// Returns a value in [0, 1) for the given seed and segment id.
/// Uses the seed hash ONCE; segmentId's 53-bit mixer picks how we combine those 256 bits.
/// No string properties—only hash-derived bits.
public func segmentHash(seed: String, segmentId: String) -> Double {
    let (l0, l1, l2, l3, l4, l5, l6, l7) = seedHash256(seed)
    let m53 = segmentMixer53(segmentId)
    // Extract 8 values (6 bits each) from the 53-bit mixer; use as per-lane XOR masks.
    let m0 = UInt32((m53 >> 0) & 0x3F), m1 = UInt32((m53 >> 6) & 0x3F)
    let m2 = UInt32((m53 >> 12) & 0x3F), m3 = UInt32((m53 >> 18) & 0x3F)
    let m4 = UInt32((m53 >> 24) & 0x3F), m5 = UInt32((m53 >> 30) & 0x3F)
    let m6 = UInt32((m53 >> 36) & 0x3F), m7 = UInt32((m53 >> 42) & 0x3F)
    let l0m = l0 ^ (m0 &* 0x01010101), l1m = l1 ^ (m1 &* 0x01010101)
    let l2m = l2 ^ (m2 &* 0x01010101), l3m = l3 ^ (m3 &* 0x01010101)
    let l4m = l4 ^ (m4 &* 0x01010101), l5m = l5 ^ (m5 &* 0x01010101)
    let l6m = l6 ^ (m6 &* 0x01010101), l7m = l7 ^ (m7 &* 0x01010101)
    let low = l0m ^ l2m ^ l4m ^ l6m
    let high = l1m ^ l3m ^ l5m ^ l7m
    var top53 = (UInt64(high) << 21) | (UInt64(low) >> 11)
    // Uniformity finalizer: ensures segmentHash is uniformly distributed in [0, 1)
    // so segmentRoll triggers as intended (mouth, nose, body, eyebrows, etc.).
    top53 = (top53 &* 0x9E3779B97F4A7C15) >> 11
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
