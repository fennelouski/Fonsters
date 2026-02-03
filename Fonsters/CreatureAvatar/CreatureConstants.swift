//
//  CreatureConstants.swift
//  Fonsters
//
//  Probability constants (CreaturePROB) and palettes (PALETTES) used by the
//  generator. Values match the web app so outputs are identical for the same seed.
//

import Foundation

/// Probabilities for avatar mode, features (eyes, mouth, etc.); all in [0, 1].
public struct CreaturePROB {
    public static let avatarModeCloud: Double = 0.01
    public static let avatarModeFlower: Double = 0.01
    public static let avatarModeRepeating: Double = 0.01
    public static let avatarModeSpace: Double = 0.01
    public static let symmetryAxisHorizontal: Double = 0.04
    public static let creatureTypeAnimal: Double = 0.7
    public static let creatureTypeAlien: Double = 0.2
    public static let symmetricVertical: Double = 0.98
    public static let symmetricDiagonal: Double = 0.09
    public static let upsideDown: Double = 0.06
    public static let shapeCircleOrEllipse: Double = 0.35
    public static let shapePolygon: Double = 0.5
    public static let hasEyes: Double = 0.95
    public static let hasMouth: Double = 0.55
    public static let mouthNeutral: Double = 0.4
    public static let mouthOpen: Double = 0.2
    public static let mouthSmiling: Double = 0.4
    public static let hasNose: Double = 0.23
    public static let hasBody: Double = 0.17
    public static let hasHair: Double = 0.04
    public static let hasEyebrows: Double = 0.38
    public static let hasBeard: Double = 0.26
    public static let hasEars: Double = 0.07
    public static let hasHorn: Double = 0.18
    public static let hasAntlers: Double = 0.12
    public static let opaqueBackground: Double = 0.11
}

public let POLYGON_SIDES: [String: Int] = [
    "triangle": 3,
    "pentagon": 5,
    "hexagon": 6,
    "septagon": 7,
    "octagon": 8
]

public let PALETTES: [[String]] = [
    ["#1a1a2e", "#e94560", "#0f3460", "#16213e", "#533483", "#0d7377"],
    ["#2d132c", "#ee4540", "#c72c41", "#801336", "#ffc947", "#14ffec"],
    ["#0d0221", "#0f084b", "#c2e9fb", "#a0e7e5", "#e94560", "#4e9f3d"],
    ["#1b262c", "#0f4c75", "#3282b8", "#bbe1fa", "#1e5128", "#ff6b6b"],
    ["#2c003e", "#4a0e4e", "#fe346e", "#ffc947", "#0d7377", "#a0e7e5"],
    ["#0c0c0c", "#1e5128", "#4e9f3d", "#d8e9a8", "#801336", "#c2e9fb"],
    ["#212121", "#323232", "#0d7377", "#14ffec", "#e94560", "#d8e9a8"],
    ["#1a1a2e", "#16213e", "#e94560", "#0f3460", "#4e9f3d", "#ffab91"],
    ["#2d132c", "#801336", "#c72c41", "#ee4540", "#0f4c75", "#14ffec"],
    ["#0f0f23", "#1a1a3e", "#ff6b6b", "#4ecdc4", "#533483", "#1e5128"],
    ["#1b1b2f", "#162447", "#e43f5a", "#1f4068", "#0d7377", "#ffc947"],
    ["#0c1445", "#1a237e", "#ffab91", "#80deea", "#4e9f3d", "#c72c41"],
]

public let TRANSPARENT = "transparent"
