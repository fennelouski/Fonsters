import Foundation
import RealityKit
import AppKit

@main struct VerifyFur {
    @MainActor static func main() throws {
        var metrics: [[String: Any]] = []
        for fixture in PlayroomCompanion.fixtures {
            let start = Date()
            let rig = try CreatureRig(fixture.descriptor)
            var models = 0, parts = 0, largestBatch = 0
            func inspect(_ entity: Entity) {
                if entity.name.hasPrefix("fuzzy-"), let component = entity.components[ModelComponent.self] {
                    for material in component.materials {
                        guard let plush = material as? PhysicallyBasedMaterial else { fatalError("Coat must use a matte material") }
                        precondition(plush.roughness.scale >= 0.99 && plush.specular.scale <= 0.08 && plush.clearcoat.scale == 0)
                    }
                    let count = component.mesh.contents.models.reduce(0) { $0 + $1.parts.count }
                    models += 1; parts += count; largestBatch = max(largestBatch, count)
                    precondition(count <= 18, "Fibres must be grouped by material, not emitted as individual render parts")
                }
                for child in entity.children { inspect(child) }
            }
            inspect(rig.root)
            precondition(models == rig.furSurfaces && models < 60)
            precondition(rig.furStrands >= 4000 && rig.furStrands < 60_000 && rig.groomedFaceStrands > 0)
            let bounds = rig.root.visualBounds(relativeTo: rig.root)
            precondition([bounds.min.x, bounds.min.y, bounds.min.z, bounds.max.x, bounds.max.y, bounds.max.z, rig.groundOffset].allSatisfy(\.isFinite))
            precondition(rig.eyes.count == 2 && bounds.extents.z > 0.6)
            let cold = Date().timeIntervalSince(start), warmStart = Date()
            let warm = try CreatureRig(fixture.descriptor)
            let warmSeconds = Date().timeIntervalSince(warmStart)
            precondition(warm.furStrands == rig.furStrands && warm.root !== rig.root && warm.head !== rig.head)
            let room = try CreatureRig(fixture.descriptor, furDetail: .lobby)
            precondition(room.furTriangles <= rig.furTriangles * 3 / 5 && room.groomedFaceStrands > 0)
            var roomParts = 0
            func inspectRoom(_ entity: Entity) {
                if entity.name.hasPrefix("fuzzy-"), let component = entity.components[ModelComponent.self] {
                    let count = component.mesh.contents.models.reduce(0) { $0 + $1.parts.count }
                    precondition(count <= 6)
                    roomParts += count
                }
                for child in entity.children { inspectRoom(child) }
            }
            inspectRoom(room.root)
            precondition(roomParts < parts)
            metrics.append(["name": fixture.name, "strands": rig.furStrands, "triangles": rig.furTriangles,
                            "surfaces": models, "materialParts": parts, "maxPartsPerSurface": largestBatch,
                            "groomedFaceStrands": rig.groomedFaceStrands,
                            "constructionSeconds": cold, "warmConstructionSeconds": warmSeconds,
                            "lobbyStrands": room.furStrands, "lobbyTriangles": room.furTriangles,
                            "lobbyMaterialParts": roomParts])
        }
        let a = CreatureFur.ellipsoid(axes: [0.12, 0.25, 0.08], palette: 2, seed: 123)
        let b = CreatureFur.ellipsoid(axes: [0.12, 0.25, 0.08], palette: 2, seed: 123)
        precondition(a.positions == b.positions && a.normals == b.normals && a.materials == b.materials)
        precondition(a.indices.allSatisfy { Int($0) < a.positions.count })
        precondition(a.materials.count == a.triangles && a.normals.count == a.positions.count)
        precondition(a.positions.allSatisfy { [$0.x, $0.y, $0.z].allSatisfy(\.isFinite) })
        precondition(a.normals.allSatisfy { abs(simd_length($0) - 1) < 0.001 })
        precondition(a.materials.allSatisfy { $0 / 3 == 2 })
        precondition(a.maximumLength < 0.08, "Soft groom should not become long bristles on a narrow limb")
        print("PASS: matte non-clearcoated low-specular coats; twelve furry rigs have substantial depth, visible groomed faces and bounded material batches; narrow-limb fibres are finite, deterministic and use only their resolved colour")
        let data = try JSONSerialization.data(withJSONObject: ["version": 1, "styleVersion": CreatureFur.styleVersion, "fixtures": metrics], options: [.sortedKeys, .prettyPrinted])
        if CommandLine.arguments.count > 1 { try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic) }
        print(String(decoding: data, as: UTF8.self))
    }
}
