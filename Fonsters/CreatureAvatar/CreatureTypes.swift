//
//  CreatureTypes.swift
//  Fonsters
//
//  Types for the deterministic creature avatar generator. Matches the web
//  implementation (nathanfennel.com creature-avatar) so the same seed
//  produces the same 32×32 image. Grid cells are color index 0–5 or -1 (transparent).
//

import Foundation

/// Grid width and height; creature is always 32×32.
public let GRID_SIZE = 32

/// Cell value: -1 = transparent, 0–5 = index into palette.
public typealias CellColorIndex = Int8

public typealias Grid = [[CellColorIndex]]

/// 1–5; derived from seed hash (content-sensitive). Drives which features (eyes, mouth, appendages, etc.) are allowed.
public typealias ComplexityTier = Int

/// Body/head mask shape.
public enum CoreShape: String, CaseIterable {
    case circle
    case ellipse
    case triangle
    case pentagon
    case hexagon
    case septagon
    case octagon
}

public enum EyeShape: String, CaseIterable {
    case square
    case circle
    case ellipse
    case triangle
    case pentagon
    case hexagon
    case septagon
    case octagon
}

public enum AvatarMode: String, CaseIterable {
    case creature
    case cloud
    case flower
    case repeating
    case space
}

public enum SymmetryAxis: String, CaseIterable {
    case vertical
    case horizontal
}

/// Resolved config for one generation; all decisions come from segment hash of the seed.
public struct CreatureConfig {
    public var avatarMode: AvatarMode
    public var symmetryAxis: SymmetryAxis
    public var complexityTier: ComplexityTier
    public var palette: [String]
    public var hasOpaqueBackground: Bool
    public var creatureType: String
    public var symmetricVertical: Bool
    public var symmetricDiagonal: Bool
    public var upsideDown: Bool
    public var shapeMask: ShapeMask
    public var ellipseAspect: (Double, Double)
    public var eyeShape: EyeShape
    public var hasEyes: Bool
    public var hasMouth: Bool
    public var mouthStyle: String
    public var hasNose: Bool
    public var noseParams: (Int, Int, Int, Int)
    public var hasBody: Bool
    public var hasHair: Bool
    public var hasEyebrows: Bool
    public var hasBeard: Bool
    public var hasEars: Bool
    public var hasHorn: Bool
    public var hasAntlers: Bool
    public var hasAppendages: Bool
    public var appendageCount: Int
    public var appendageStyle: String
    public var appendageRadial: Bool
}

public enum ShapeMask {
    case rect
    case shape(CoreShape)
}
