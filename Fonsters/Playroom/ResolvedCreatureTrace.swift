// Version 1 trace of legacy creature geometry. Deliberately duplicates the frozen
// drawing decisions; every supported result is checked against generateCreatureGrid.
// Do not "fix" quirks here without bumping the descriptor version and fixtures.
import Foundation

final class ResolvedRasterTrace {
    var pixels: Grid = Array(repeating: Array(repeating: -1, count: 32), count: 32)
    var roles = Array(repeating: Array(repeating: "background", count: 32), count: 32)
    var beforeClipping: [[String]] = []
    var currentRole = "head"
    var headPixels: Set<Int> = []
    func set(x: Int, y: Int, index: Int8, role: String? = nil) {
        pixels[y][x] = index
        roles[y][x] = index == -1 ? "background" : (role ?? currentRole)
    }
    func mirror(x: Int, y: Int, sourceX: Int, sourceY: Int) {
        let source = roles[sourceY][sourceX]
        pixels[y][x] = pixels[sourceY][sourceX]
        roles[y][x] = source.replacingOccurrences(of: "L", with: "R")
    }
}

func traceResolvedCreature(seed: String) -> ResolvedRasterTrace {
    let trace = ResolvedRasterTrace()
    resolvedDrawCreature(seed: seed, config: resolveConfig(seed: seed), grid: trace)
    return trace
}

private func resolvedInCircle(x: Double, y: Double, cx: Double, cy: Double, r: Double) -> Bool {
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r
}

private func resolvedInEllipse(x: Double, y: Double, cx: Double, cy: Double, rx: Double, ry: Double) -> Bool {
    return ((x - cx) * (x - cx)) / (rx * rx) + ((y - cy) * (y - cy)) / (ry * ry) <= 1
}

private func resolvedInPolygon(px: Double, py: Double, cx: Double, cy: Double, r: Double, nSides: Int) -> Bool {
    var vertices: [(x: Double, y: Double)] = []
    for i in 0..<nSides {
        let angle = (2 * Double.pi * Double(i)) / Double(nSides) - Double.pi / 2
        vertices.append((cx + r * cos(angle), cy + r * sin(angle)))
    }
    var inside = false
    var j = nSides - 1
    for i in 0..<nSides {
        let xi = vertices[i].x, yi = vertices[i].y
        let xj = vertices[j].x, yj = vertices[j].y
        if (yi > py) != (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi {
            inside.toggle()
        }
        j = i
    }
    return inside
}

private func resolvedInCoreShape(x: Double, y: Double, cx: Double, cy: Double, r: Double, shape: ShapeMask, ellipseAspect: (Double, Double)) -> Bool {
    switch shape {
    case .rect: return true
    case .shape(.circle): return resolvedInCircle(x: x, y: y, cx: cx, cy: cy, r: r)
    case .shape(.ellipse): return resolvedInEllipse(x: x, y: y, cx: cx, cy: cy, rx: r * ellipseAspect.0, ry: r * ellipseAspect.1)
    case .shape(let s):
        if let n = POLYGON_SIDES[s.rawValue] {
            return resolvedInPolygon(px: x, py: y, cx: cx, cy: cy, r: r, nSides: n)
        }
        return false
    }
}

private func resolvedInEyeShape(px: Double, py: Double, eyeCx: Double, eyeCy: Double, shape: EyeShape, size: Double) -> Bool {
    switch shape {
    case .square: return abs(px - eyeCx) <= size && abs(py - eyeCy) <= size
    case .circle: return resolvedInCircle(x: px, y: py, cx: eyeCx, cy: eyeCy, r: size)
    case .ellipse: return resolvedInEllipse(x: px, y: py, cx: eyeCx, cy: eyeCy, rx: size * 1.2, ry: size * 0.8)
    default:
        if let n = POLYGON_SIDES[shape.rawValue] {
            return resolvedInPolygon(px: px, py: py, cx: eyeCx, cy: eyeCy, r: size, nSides: n)
        }
        return false
    }
}

private func resolvedSetPixel(grid: ResolvedRasterTrace, x: Double, y: Double, idx: CellColorIndex) {
    let ix = Int(round(x)), iy = Int(round(y))
    if ix >= 0 && ix < GRID_SIZE && iy >= 0 && iy < GRID_SIZE {
        grid.set(x: ix, y: iy, index: idx)
    }
}

private func resolvedDrawThickLine(grid: ResolvedRasterTrace, x0: Double, y0: Double, angleDeg: Double, length: Double, thicknessStart: Double, idx: CellColorIndex, taperEnd: Double = 1) {
    let rad = angleDeg * .pi / 180
    let dx = cos(rad), dy = sin(rad)
    let steps = max(2, Int(ceil(length)))
    for s in 0...steps {
        let t = Double(s) / Double(steps)
        let thickness = taperEnd >= 1 ? thicknessStart : thicknessStart * (1 - t * (1 - taperEnd))
        let x = x0 + dx * length * t
        let y = y0 + dy * length * t
        let th = Int(round(thickness))
        if th <= 1 {
            resolvedSetPixel(grid: grid, x: x, y: y, idx: idx)
        } else {
            let r = Double(max(1, th))
            for oy in Int(-r)...Int(r) {
                for ox in Int(-r)...Int(r) {
                    if Double(ox * ox + oy * oy) <= r * r + 0.5 {
                        resolvedSetPixel(grid: grid, x: x + Double(ox), y: y + Double(oy), idx: idx)
                    }
                }
            }
        }
    }
}

private func resolvedDrawAppendages(seed: String, config: CreatureConfig, grid: ResolvedRasterTrace, midX: Double, headRadius: Double, headCyLogical: Double, fillColorIndex: CellColorIndex) {
    if !config.hasAppendages { return }
    let n = config.appendageCount
    let baseThickness: Double = config.appendageStyle == "tentacle" ? 1 : 2
    let baseLength = 6 + segmentHash(seed: seed, segmentId: "append_len") * 6
    let countLeft = n / 2
    let startR = headRadius + 1.5
    let headCyDisplay = config.upsideDown ? Double(GRID_SIZE - 1) - headCyLogical : headCyLogical
    let cx = midX - 0.5, cy = headCyDisplay - 0.5
    let taperEnd = segmentRoll(seed: seed, segmentId: "append_taper", p: 0.4) ? 0.4 : 1.0

    var leftAngles: [Double] = []
    if config.appendageRadial {
        for i in 0..<countLeft {
            leftAngles.append(90 + (180 * Double(i + 1)) / Double(countLeft + 1))
        }
    } else {
        for i in 0..<countLeft {
            leftAngles.append(120 + (120 * Double(i)) / Double(max(1, countLeft - 1)))
        }
    }

    for (i, baseAngle) in leftAngles.enumerated() {
        grid.currentRole = "limbL\(i)"
        var angle = baseAngle + (segmentHash(seed: seed, segmentId: "leg_angle_\(i)") - 0.5) * 36
        if config.upsideDown { angle = 360 - angle }
        let len = baseLength + segmentHash(seed: seed, segmentId: "append_\(i)") * 4
        let thickness = Double(max(1, Int(baseThickness) + segmentPick(seed: seed, segmentId: "leg_thick_\(i)", n: 3) - 1))
        let rad = angle * .pi / 180
        let x0 = cx + startR * cos(rad)
        let y0 = cy + startR * sin(rad)
        resolvedDrawThickLine(grid: grid, x0: x0, y0: y0, angleDeg: angle, length: len, thicknessStart: thickness, idx: fillColorIndex, taperEnd: taperEnd)
    }
}

private func resolvedApplyShapeMask(grid: ResolvedRasterTrace, config: CreatureConfig) {
    let cx = Double(GRID_SIZE - 1) / 2, cy = Double(GRID_SIZE - 1) / 2
    let r = Double(min(GRID_SIZE, GRID_SIZE)) / 2 - 0.5
    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            let inside = resolvedInCoreShape(x: Double(x), y: Double(y), cx: cx, cy: cy, r: r, shape: config.shapeMask, ellipseAspect: config.ellipseAspect)
            if !inside { grid.set(x: x, y: y, index: -1) }
        }
    }
}

// MARK: - Draw modes

private func resolvedDrawHornAndAntlers(grid: ResolvedRasterTrace, config: CreatureConfig, midX: Double, headCy: Double, headRadius: Double, fillColorIndex: CellColorIndex) {
    if !config.hasHorn && !config.hasAntlers { return }
    let headCyDisplay = config.upsideDown ? Double(GRID_SIZE - 1) - headCy : headCy
    let topHeadRow = config.upsideDown ? headCyDisplay + headRadius : headCyDisplay - headRadius
    let dir: Double = config.upsideDown ? 1 : -1
    let ix = Int(round(midX))

    if config.hasHorn {
        grid.currentRole = "horn"
        for i in 0...4 {
            let row = Int(round(topHeadRow + dir * Double(i)))
            if row >= 0 && row < GRID_SIZE {
                resolvedSetPixel(grid: grid, x: Double(ix), y: Double(row), idx: fillColorIndex)
                if ix - 1 >= 0 { resolvedSetPixel(grid: grid, x: Double(ix - 1), y: Double(row), idx: fillColorIndex) }
                if ix + 1 < GRID_SIZE { resolvedSetPixel(grid: grid, x: Double(ix + 1), y: Double(row), idx: fillColorIndex) }
            }
        }
    }

    if config.hasAntlers {
        grid.currentRole = "antler"
        let stemLen = 5
        let branchLen = 6.0
        for i in 0...stemLen {
            let row = Int(round(topHeadRow + dir * Double(i)))
            if row >= 0 && row < GRID_SIZE {
                resolvedSetPixel(grid: grid, x: midX, y: Double(row), idx: fillColorIndex)
            }
        }
        let branchStartRow = topHeadRow + dir * Double(stemLen)
        resolvedDrawThickLine(grid: grid, x0: midX, y0: branchStartRow, angleDeg: config.upsideDown ? 135 : 225, length: branchLen, thicknessStart: 1, idx: fillColorIndex)
        resolvedDrawThickLine(grid: grid, x0: midX, y0: branchStartRow, angleDeg: config.upsideDown ? 45 : 315, length: branchLen, thicknessStart: 1, idx: fillColorIndex)
    }
}

private func resolvedDrawCreature(seed: String, config: CreatureConfig, grid: ResolvedRasterTrace) {
    let tier = config.complexityTier
    let midX = Double(GRID_SIZE) / 2
    let midY = Double(GRID_SIZE) / 2

    let bgColorIndex: CellColorIndex = config.hasOpaqueBackground ? 0 : -1
    let fillColorIndex: CellColorIndex = config.hasOpaqueBackground ? 1 : 0
    let accent1: CellColorIndex = 2
    let accent2: CellColorIndex = 3

    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            grid.set(x: x, y: y, index: config.hasOpaqueBackground && !config.palette.isEmpty ? 0 : -1, role: "background")
        }
    }

    if tier == 1 {
        let r = 10.0
        let cx = midX - 0.5, cy = midY - 0.5
        for y in 0..<GRID_SIZE {
            for x in 0..<GRID_SIZE {
                if resolvedInCircle(x: Double(x), y: Double(y), cx: cx, cy: cy, r: r) { grid.set(x: x, y: y, index: fillColorIndex, role: "head") }
            }
        }
        return
    }

    if tier == 2 {
        let r = 9 + segmentHash(seed: seed, segmentId: "size") * 4
        let cx = midX - 0.5, cy = midY - 0.5
        for y in 0..<GRID_SIZE {
            for x in 0..<GRID_SIZE {
                if resolvedInCircle(x: Double(x), y: Double(y), cx: cx, cy: cy, r: r) { grid.set(x: x, y: y, index: fillColorIndex, role: "head") }
            }
        }
        return
    }

    let mirrorX: (Double) -> Double = { x in x >= midX ? 2 * midX - 1 - x : x }
    let mirrorY: (Double) -> Double = { y in y >= midY ? 2 * midY - 1 - y : y }
    let headRadius = 11 + (config.creatureType == "alien" ? 2 : 0)
    let headCy = config.hasBody ? midY - 4 : midY

    for y in 0..<GRID_SIZE {
        for x in 0..<GRID_SIZE {
            let logicalY = config.upsideDown ? Double(GRID_SIZE - 1 - y) : Double(y)
            let mx = config.symmetryAxis == .vertical && config.symmetricVertical ? mirrorX(Double(x)) : Double(x)
            let my = config.symmetryAxis == .horizontal && config.symmetricVertical ? mirrorY(logicalY) : logicalY

            let inHead: Bool
            switch config.shapeMask {
            case .rect:
                inHead = resolvedInCircle(x: mx, y: my, cx: midX - 0.5, cy: headCy - 0.5, r: Double(headRadius))
            case .shape:
                inHead = resolvedInCoreShape(x: mx, y: my, cx: midX - 0.5, cy: headCy - 0.5, r: Double(headRadius), shape: config.shapeMask, ellipseAspect: config.ellipseAspect)
            }

            var idx: CellColorIndex = bgColorIndex
            var role = "background"
            if inHead {
                grid.headPixels.insert(y * 32 + x)
                idx = fillColorIndex
                role = "head"
                if config.hasEyes && tier >= 4 {
                    let eyeY = headCy - 3
                    let eyeDx = 4.0
                    let eyeSize = 1.4
                    if resolvedInEyeShape(px: mx, py: my, eyeCx: midX - eyeDx, eyeCy: eyeY, shape: config.eyeShape, size: eyeSize) { idx = accent1; role = "eyeL" }
                    if resolvedInEyeShape(px: mx, py: my, eyeCx: midX + eyeDx, eyeCy: eyeY, shape: config.eyeShape, size: eyeSize) { idx = accent1; role = "eyeR" }
                }
                if config.hasMouth && tier >= 4 && my >= headCy + 2 && my <= headCy + 5 && abs(mx - midX) <= 3 {
                    idx = config.palette.count > 2 ? accent2 : accent1
                    role = "mouth"
                }
                if config.hasNose && tier >= 4 {
                    let noseY = headCy
                    if my >= noseY - 1 && my <= noseY + 2 && abs(mx - midX) <= 2 { idx = accent1; role = "nose" }
                }
                if config.hasEyebrows && tier >= 4 && my >= headCy - 6 && my <= headCy - 4 {
                    if (mx >= midX - 5 && mx <= midX - 2) || (mx >= midX + 2 && mx <= midX + 5) {
                        idx = config.palette.count > 2 ? accent2 : accent1
                        role = "brow"
                    }
                }
                if config.hasBeard && tier >= 4 && my >= headCy + 5 && my <= headCy + 10 && abs(mx - midX) <= 5 {
                    idx = config.palette.count > 2 ? accent2 : accent1
                    role = "beard"
                }
            }
            if config.hasEars && tier >= 4 {
                let earCy = headCy - 2
                let earCx = midX - Double(headRadius) - 1.5
                if resolvedInCircle(x: mx, y: my, cx: earCx, cy: earCy, r: 2.5) { idx = fillColorIndex; role = "earL" }
            }
            if config.hasBody && tier >= 4 && my > midY + 6 {
                if abs(mx - midX) <= 8 { idx = fillColorIndex; role = "body" }
            }
            if config.hasHair && tier >= 4 && my < headCy - Double(headRadius) + 2 {
                if abs(mx - midX) <= 6 { idx = config.palette.count > 2 ? accent2 : accent1; role = "hair" }
            }
            if idx != -1 && config.palette.count <= Int(idx) { idx = fillColorIndex }
            let outY = config.upsideDown ? GRID_SIZE - 1 - y : y
            grid.set(x: x, y: outY, index: idx, role: role)
        }
    }

    resolvedDrawHornAndAntlers(grid: grid, config: config, midX: midX, headCy: headCy, headRadius: Double(headRadius), fillColorIndex: fillColorIndex)
    resolvedDrawAppendages(seed: seed, config: config, grid: grid, midX: midX, headRadius: Double(headRadius), headCyLogical: headCy, fillColorIndex: fillColorIndex)

    if config.symmetricVertical {
        if config.symmetryAxis == .vertical {
            for y in 0..<GRID_SIZE {
                for x in Int(ceil(midX))..<GRID_SIZE {
                    let srcX = Int(floor(2 * midX - 1 - Double(x)))
                    if srcX >= 0 { grid.mirror(x: x, y: y, sourceX: srcX, sourceY: y) }
                }
            }
        } else {
            for x in 0..<GRID_SIZE {
                for y in Int(ceil(midY))..<GRID_SIZE {
                    let srcY = Int(floor(2 * midY - 1 - Double(y)))
                    if srcY >= 0 { grid.mirror(x: x, y: y, sourceX: x, sourceY: srcY) }
                }
            }
        }
    }

    if config.symmetricVertical && segmentRoll(seed: seed, segmentId: "asym_enable", p: 0.25) {
        let nAsym = segmentPick(seed: seed, segmentId: "asym_count", n: 5)
        let rightStart = Int(ceil(midX))
        let rightWidth = GRID_SIZE - rightStart
        for i in 0..<nAsym {
            let ax = rightStart + segmentPick(seed: seed, segmentId: "asym_x_\(i)", n: max(1, rightWidth))
            let ay = segmentPick(seed: seed, segmentId: "asym_y_\(i)", n: GRID_SIZE)
            let ac = segmentPick(seed: seed, segmentId: "asym_c_\(i)", n: config.palette.count)
            if ay >= 0 && ay < GRID_SIZE && ax >= 0 && ax < GRID_SIZE {
                grid.set(x: ax, y: ay, index: Int8(min(ac, 5)), role: "marking")
            }
        }
    }

    grid.beforeClipping = grid.roles
    resolvedApplyShapeMask(grid: grid, config: config)
}

