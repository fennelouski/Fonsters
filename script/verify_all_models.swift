import Foundation
import RealityKit
import AppKit
import CryptoKit

@main struct VerifyAllModels {
    @MainActor static func main() throws {
        var families: [String: String] = [:]
        // Deterministic old/imported/time-style seeds, never replacement seeds.
        for i in 0..<1500 {
            let seed = i < 1000 ? "little-fonster-\(i)" : "2026-10-11T\(i):00:00.000Z"
            let config = resolveConfig(seed: seed), descriptor = CreatureAppearanceDescriptor.resolve(seed: seed)
            precondition(descriptor.raster == generateCreatureGrid(seed: seed).flatMap { $0 })
            if descriptor.supported { continue }
            let label: String
            if config.avatarMode == .creature {
                label = config.complexityTier < 4 ? "low-tier" : (config.upsideDown ? "inverted" : (config.symmetryAxis == .horizontal ? "horizontal" : "asymmetric"))
            } else if config.avatarMode == .space { label = "space-\(segmentPick(seed: seed, segmentId: "space_kind", n: 4))" }
            else { label = config.avatarMode.rawValue }
            if families[label] == nil { families[label] = seed }
        }
        precondition(Set(["low-tier", "inverted", "horizontal", "asymmetric", "cloud", "flower", "repeating", "space-0", "space-1", "space-2", "space-3"]).isSubset(of: Set(families.keys)))
        var metrics: [[String: Any]] = []
        let legacyJSON = try JSONEncoder().encode(CreatureAppearanceDescriptor.resolve(seed:families.values.sorted().first!))
        var legacyObject = try JSONSerialization.jsonObject(with:legacyJSON) as! [String:Any]
        var legacyVolume = legacyObject["volume"] as! [String:Any]
        legacyVolume.removeValue(forKey:"anatomy"); legacyVolume["version"] = 1
        legacyObject["volume"] = legacyVolume
        let restored = try JSONDecoder().decode(CreatureAppearanceDescriptor.self,from:JSONSerialization.data(withJSONObject:legacyObject))
        let restoredRig = try CreatureRig(restored,furDetail:.world)
        precondition(!restoredRig.eyes.isEmpty && restoredRig.mouth != nil)

        for (family, seed) in families.sorted(by: { $0.key < $1.key }) {
            let descriptor = CreatureAppearanceDescriptor.resolve(seed: seed)
            let geometry = ResolvedCreatureVolume.make(descriptor)
            precondition(descriptor.volume?.version == 2 && !geometry.positions.isEmpty)
            precondition(geometry.positions == ResolvedCreatureVolume.make(descriptor).positions)
            precondition(geometry.indices.count / 3 == geometry.materials.count)
            let soft = geometry.softened()
            precondition(soft.indices == geometry.indices && soft.materials == geometry.materials)
            precondition(soft.positions == geometry.softened().positions)
            precondition(soft.positions.allSatisfy { [$0.x,$0.y,$0.z].allSatisfy(\.isFinite) })
            precondition(soft.normals.allSatisfy { abs(simd_length($0)-1)<0.001 })
            precondition(geometry.positions.allSatisfy { [$0.x,$0.y,$0.z].allSatisfy(\.isFinite) })
            precondition(geometry.normals.allSatisfy { abs(simd_length($0)-1) < 0.001 })
            var edges: [String: Int] = [:], volume: Float = 0, projected = Set<Int>()
            for i in stride(from: 0, to: geometry.indices.count, by: 3) {
                let ids = (0..<3).map { Int(geometry.indices[i + $0]) }
                let a = geometry.positions[ids[0]], b = geometry.positions[ids[1]], c = geometry.positions[ids[2]]
                precondition(simd_length(simd_cross(b-a, c-a)) > 0.00001, "Degenerate face \(family)")
                volume += simd_dot(a, simd_cross(b,c)) / 6
                for e in 0..<3 {
                    let p = ids[e], q = ids[(e+1)%3], key = "\(min(p,q)):\(max(p,q))"
                    edges[key, default: 0] += 1
                }
                if a.z > 0 && b.z > 0 && c.z > 0 {
                    let center = (a+b+c)/3
                    let x = Int(floor(center.x/0.0625+16)), y = Int(floor(16-center.y/0.0625))
                    precondition((0..<32).contains(x) && (0..<32).contains(y))
                    precondition(geometry.materials[i/3] == UInt32(descriptor.raster[y*32+x]))
                    projected.insert(y*32+x)
                }
            }
            precondition(edges.values.allSatisfy { $0 == 2 }, "Open/non-manifold mesh \(family)")
            precondition(volume > 0.001, "Inverted or zero-volume mesh \(family)")
            precondition(projected == Set(descriptor.volume!.pixels.map { $0.y*32+$0.x }), "Changed silhouette \(family)")
            let encoded = try JSONEncoder().encode(descriptor)
            let decoded = try JSONDecoder().decode(CreatureAppearanceDescriptor.self, from: encoded)
            precondition(decoded == descriptor)
            precondition(!String(decoding: encoded, as: UTF8.self).contains(seed))
            let rig = try CreatureRig(descriptor, furDetail: .world)
            let bounds = rig.root.visualBounds(relativeTo: rig.root)
            precondition(bounds.extents.z >= 0.44 && rig.root.findEntity(named: "resolved-volumetric-body") != nil)
            precondition(rig.furStrands >= 400 && rig.furStrands < 20000 && rig.furSurfaces >= 1 && rig.groundOffset.isFinite)
            precondition(!rig.eyes.isEmpty && rig.eyes.count == rig.pupils.count && rig.mouth != nil)
            rig.express(smile:-0.6,smilingEyes:0,opening:0.1)
            let sad = rig.facialGeometry!.curvature
            rig.express(smile:0.9,smilingEyes:0.8,opening:0.7)
            precondition(rig.facialGeometry!.curvature > sad)
            rig.animateFamily(time:2,energy:1,moving:true)
            rig.animateFamily(time:2,energy:1,moving:false)
            for part in descriptor.volume!.anatomy!.satellites {
                let entity = rig.root.findEntity(named:part.id)!
                precondition(entity.position == .zero && abs(entity.orientation.angle) < 0.001)
                let b=entity.visualBounds(relativeTo:nil)
                precondition(rig.touchHit(origin:b.center+[0,0,5],direction:[0,0,-1]) != nil,"Every satellite needs a live touch surface")
            }
            precondition(rig.limbs.count == descriptor.volume!.anatomy!.appendages.count)
            let hit = rig.touchHit(origin: [0,0,5], direction: [0,0,-1])
            precondition(hit != nil, "Volume needs a touch surface")
            metrics.append(["family": family, "triangles": geometry.indices.count/3, "depth": bounds.extents.z, "signedVolume": volume, "furStrands": rig.furStrands])
        }
        // Render and inspect separately after the allowed native-build window.
        for fixture in PlayroomCompanion.fixtures {
            let rig = try CreatureRig(fixture.descriptor, furDetail: .world)
            precondition(rig.root.findEntity(named: "resolved-head") != nil && rig.eyes.count == 2)
        }
        let report = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
        if CommandLine.arguments.count > 1 { try report.write(to: URL(fileURLWithPath: CommandLine.arguments[1])) }
        print("PASS: 1,500 preserved rasters; eleven fallback categories have closed nonzero volumes, original palette/mask projection, deterministic geometry, Codable privacy, live RealityKit meshes, fur and touch surfaces; twelve original articulated rigs remain available.")
        print(String(decoding: report, as: UTF8.self))
    }
}
