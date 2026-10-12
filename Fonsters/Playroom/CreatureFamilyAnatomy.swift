import Foundation

extension CreatureAppearanceDescriptor {
    /// Resolved render anatomy. Original portraits/parts remain authoritative for
    /// legacy exports; this additive layout gives abstract families a living face.
    struct FamilyAnatomy: Codable, Equatable {
        struct Face: Codable, Equatable {
            let x: Double, y: Double, radius: Double
            let mouthX: Double, mouthY: Double, mouthWidth: Double
            let skin: Int8
            let addedSupport: Bool
            var mouthSkin: Int8? = nil
        }
        /// Public synthetic fixtures only, used by the explicit memory-only gallery.
        static let previewSeeds: [(name: String, seed: String)] = [
            ("Pip","little-fonster-3"),("Topsy","little-fonster-1"),("Twins","little-fonster-6"),
            ("Quirk","little-fonster-43"),("Nimbus","little-fonster-167"),("Petal","little-fonster-46"),
            ("Patch","little-fonster-2"),("Moon","little-fonster-180"),("Starlight","little-fonster-158"),
            ("Nebbie","little-fonster-193"),("Galaxy","little-fonster-341")]
        let version: Int
        let variant: String
        let face: Face
        let eyes: [Part]
        let appendages: [Part]
        let satellites: [Part]
        let bodyPixels: [Pixel]

        static func components(_ pixels: [Pixel]) -> [[Pixel]] {
            var remaining = Set(pixels), groups: [[Pixel]] = []
            while let first = remaining.min(by: { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }) {
                remaining.remove(first)
                var group = [first], index = 0
                while index < group.count {
                    let p = group[index]; index += 1
                    for n in [Pixel(x:p.x-1,y:p.y),Pixel(x:p.x+1,y:p.y),Pixel(x:p.x,y:p.y-1),Pixel(x:p.x,y:p.y+1)] {
                        if remaining.remove(n) != nil { group.append(n) }
                    }
                }
                groups.append(group.sorted { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y })
            }
            return groups.sorted { $0.count == $1.count ? ($0[0].y*32+$0[0].x < $1[0].y*32+$1[0].x) : $0.count > $1.count }
        }

        static func resolve(_ a: CreatureAppearanceDescriptor, semantic: Bool, variant: Int) -> Self {
            let pixels = a.volume?.pixels ?? a.silhouette
            let family = a.volume?.family ?? "creature"
            let groups = components(pixels), main = groups.first ?? []
            let mainSet = Set(main)
            // Largest inscribed patch keeps eyes on an actual surface, away from
            // holes and clipped edges. Deterministic tie-breaking avoids drift.
            var clearances: [Pixel:Int] = [:]
            func clearance(_ p: Pixel) -> Int {
                if let value = clearances[p] { return value }
                for r in 1...9 {
                    if (-r...r).contains(where: { dy in (-r...r).contains { dx in !mainSet.contains(Pixel(x:p.x+dx,y:p.y+dy)) } }) { clearances[p]=r-1; return r-1 }
                }
                clearances[p]=9; return 9
            }
            let center = main.max { p,q in
                let cp=clearance(p), cq=clearance(q)
                if cp != cq { return cp < cq }
                let dp=(p.x-16)*(p.x-16)+(p.y-15)*(p.y-15), dq=(q.x-16)*(q.x-16)+(q.y-15)*(q.y-15)
                return dp == dq ? p.y*32+p.x > q.y*32+q.x : dp > dq
            } ?? Pixel(x:16,y:16)
            let support = clearance(center) < 3
            let radius = Double(support ? 5 : min(8,max(4,clearance(center))))
            let colors = Dictionary(grouping: main, by: { a.raster[$0.y*32+$0.x] })
            let skin = colors.keys.sorted().max { l,r in (colors[l]?.count ?? 0) < (colors[r]?.count ?? 0) } ?? 0
            func part(_ id: String, _ kind: String, _ cells: [Pixel], style: String = "circle") -> Part {
                .init(id:id,kind:kind,style:style,pixels:cells,clippedPixels:[],paletteIndices:cells.map { a.raster[$0.y*32+$0.x] })
            }
            var eyes: [Part] = []
            if semantic {
                for eye in a.parts.filter({ $0.kind == "eye" }) {
                    for (i,cells) in components(eye.pixels).enumerated() where cells.count >= 2 {
                        eyes.append(part(eye.id+"-"+String(i),"eye",cells,style:eye.style))
                    }
                }
            }
            // Abstract families have no legacy eye semantics. Explicitly resolved
            // render eyes are separate from identity and never enter 2D exports.
            if eyes.isEmpty {
                for side in [-1,1] {
                    let x=Int((Double(center.x)+Double(side)*radius*0.48).rounded())
                    let y=Int((Double(center.y)-radius*0.30).rounded())
                    let cells=(0..<3).flatMap { dy in (0..<3).map { dx in Pixel(x:min(31,max(0,x+dx-1)),y:min(31,max(0,y+dy-1))) } }
                    eyes.append(.init(id:side < 0 ? "family-eyeL" : "family-eyeR",kind:"eye",style:"circle",pixels:cells,clippedPixels:[],paletteIndices:Array(repeating:2,count:cells.count)))
                }
            }
            let legacyMouth = semantic ? a.parts.first(where: { $0.kind == "mouth" }) : nil
            let mouthX = legacyMouth?.centerX ?? Double(center.x)
            // Upside-down creatures keep the face in its actual legacy location;
            // a friendly render smile is always oriented toward the viewer.
            let mouthY = legacyMouth?.centerY ?? Double(center.y)+radius*0.48
            var face = Face(x:Double(center.x),y:Double(center.y),radius:radius,
                mouthX:mouthX,mouthY:mouthY,mouthWidth:min(11,max(5,radius*1.20)),skin:skin,addedSupport:support)
            let mouthCell = pixels.min { a,b in
                hypot(Double(a.x)-mouthX,Double(a.y)-mouthY) < hypot(Double(b.x)-mouthX,Double(b.y)-mouthY)
            }
            face.mouthSkin = semantic || support ? skin : mouthCell.map { a.raster[$0.y*32+$0.x] }
            let appendages = semantic ? a.parts.filter { $0.kind == "appendage" && $0.pixels.count > 1 } : []
            var satellites: [Part] = []
            if family == "space" && groups.count > 1 {
                satellites = groups.dropFirst().prefix(16).enumerated().map { part("satellite-\($0.offset)","satellite",$0.element) }
            } else if family == "flower" {
                let outer = pixels.filter { hypot(Double($0.x)-face.x,Double($0.y)-face.y) > radius*1.10 }
                let sectors = Dictionary(grouping:outer) { p in Int((atan2(Double(p.y)-face.y,Double(p.x)-face.x)+Double.pi)/(Double.pi*2)*6)%6 }
                satellites = sectors.keys.sorted().compactMap { key in
                    let cells=sectors[key] ?? []; return cells.count > 4 ? part("petal-\(key)","petal",cells) : nil
                }
            } else if family == "cloud" || (family == "space" && variant == 2) {
                satellites = groups.dropFirst().prefix(6).enumerated().map { part("wisp-\($0.offset)","wisp",$0.element) }
            }
            let excluded=Set((appendages+satellites).flatMap(\.pixels))
            return .init(version:1,variant:family == "space" ? ["moon","constellation","nebula","galaxy"][min(3,max(0,variant))] : family,
                face:face,eyes:eyes,appendages:appendages,satellites:satellites,bodyPixels:pixels.filter { !excluded.contains($0) })
        }
    }
}

extension ResolvedCreatureVolume {
    /// Render-only Taubin relaxation rounds pixel stair steps without changing
    /// connectivity, deleting holes or replacing the original resolved mask.
    func softened() -> Self {
        guard positions.count > 60 else { return self }
        var result = self
        var neighbors = Array(repeating: Set<Int>(), count: positions.count)
        for i in stride(from: 0, to: indices.count, by: 3) {
            let ids = (0..<3).map { Int(indices[i+$0]) }
            for j in 0..<3 {
                neighbors[ids[j]].insert(ids[(j+1)%3]); neighbors[ids[j]].insert(ids[(j+2)%3])
            }
        }
        for _ in 0..<4 {
            for weight: Float in [0.35,-0.36] {
                let old = result.positions
                result.positions = old.indices.map { index in
                    let adjacent = neighbors[index].sorted()
                    guard !adjacent.isEmpty else { return old[index] }
                    let mean = adjacent.reduce(SIMD3<Float>.zero) { $0+old[$1] } / Float(adjacent.count)
                    return old[index]+(mean-old[index])*weight
                }
            }
        }
        result.normals = Array(repeating: .zero, count: positions.count)
        for i in stride(from: 0, to: indices.count, by: 3) {
            let ids = (0..<3).map { Int(indices[i+$0]) }
            let a=result.positions[ids[1]]-result.positions[ids[0]], b=result.positions[ids[2]]-result.positions[ids[0]]
            let n=SIMD3<Float>(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x)
            for index in ids { result.normals[index] += n }
        }
        result.normals = result.normals.map { n in n/max(0.000001,sqrt(n.x*n.x+n.y*n.y+n.z*n.z)) }
        return result
    }
}
