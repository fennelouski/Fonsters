#if os(macOS) || os(iOS) || os(tvOS)
import RealityKit
import Metal
import simd

/// Two fixed-topology volumetric meshes. Only existing vertex buffers change;
/// no per-frame mesh/entity/material creation and no additional shader toolchain.
@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
@MainActor final class CreatureFacialGeometry {
    struct Vertex { var position: SIMD3<Float>; var normal: SIMD3<Float> }
    let cavity: ModelEntity
    let rim: ModelEntity
    // Retain native buffers: MeshResource.contents omits LowLevelMesh vertices.
    let cavityMesh: LowLevelMesh
    let rimMesh: LowLevelMesh
    let width: Float, height: Float
    private let steps = 32, sides = 8
    private var lastSmile: Float = -10, lastOpening: Float = -10
    private(set) var curvature: Float = 0.45

    init(width: Float, height: Float, cavityMaterial: PhysicallyBasedMaterial, rimMaterial: PhysicallyBasedMaterial) throws {
        self.width = width; self.height = height
        let count = 66, stations = 33
        var cavityIndices: [UInt32] = []
        for i in 0..<32 {
            let a = UInt32(i * 2), b = a + 2, back = UInt32(stations * 2)
            cavityIndices += [a, a + 1, b, a + 1, b + 1, b,
                              a + back, b + back, a + 1 + back, a + 1 + back, b + back, b + 1 + back]
        }
        let sideStart = UInt32(stations * 4)
        for i in 0..<count {
            let a = sideStart + UInt32(i * 4)
            cavityIndices += [a, a + 1, a + 2, a + 1, a + 3, a + 2]
        }
        var rimIndices: [UInt32] = []
        for i in 0..<count { for j in 0..<8 {
            let a = UInt32(i * 8 + j), b = UInt32(i * 8 + (j + 1) % 8)
            let c = UInt32((i + 1) % count * 8 + j), d = UInt32((i + 1) % count * 8 + (j + 1) % 8)
            rimIndices += [a, b, c, b, d, c]
        } }
        let bounds = BoundingBox(min: [-width * 0.6, -height * 1.2, -0.015], max: [width * 0.6, height * 1.2, 0.1])
        func make(_ vertices: Int, _ indices: [UInt32]) throws -> LowLevelMesh {
            var descriptor = LowLevelMesh.Descriptor()
            descriptor.vertexCapacity = vertices; descriptor.indexCapacity = indices.count; descriptor.indexType = .uint32
            descriptor.vertexAttributes = [
                .init(semantic: .position, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.position)!),
                .init(semantic: .normal, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.normal)!)]
            descriptor.vertexLayouts = [.init(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride)]
            let mesh = try LowLevelMesh(descriptor: descriptor)
            mesh.withUnsafeMutableBytes(bufferIndex: 0) { bytes in
                let target = bytes.bindMemory(to: Vertex.self)
                for i in 0..<vertices { target[i] = .init(position: .zero, normal: [0, 0, 1]) }
            }
            mesh.withUnsafeMutableIndices { bytes in
                let target = bytes.bindMemory(to: UInt32.self)
                for i in indices.indices { target[i] = indices[i] }
            }
            mesh.parts.replaceAll([.init(indexCount: indices.count, topology: .triangle, bounds: bounds)])
            return mesh
        }
        cavityMesh = try make(stations * 4 + count * 4, cavityIndices)
        rimMesh = try make(count * 8, rimIndices)
        cavity = ModelEntity(mesh: try MeshResource(from: cavityMesh), materials: [cavityMaterial]); cavity.name = "smile-cavity"
        rim = ModelEntity(mesh: try MeshResource(from: rimMesh), materials: [rimMaterial]); rim.name = "smile-rim"
        update(smile: 0.45, opening: 1)
    }
    func update(smile: Float, opening: Float) {
        guard smile.isFinite, opening.isFinite else { return }
        let smile = min(1, max(-0.85, smile)), opening = min(1.4, max(0.3, opening))
        guard abs(smile - lastSmile) > 0.002 || abs(opening - lastOpening) > 0.003 else { return }
        lastSmile = smile; lastOpening = opening; curvature = smile
        let edges = (0...steps).map { CreatureMouthCurve.edges(t: Float($0) / Float(steps) * 2 - 1, width: width, height: height, smile: smile, opening: opening) }
        let outline = edges.map { $0.0 } + edges.reversed().map { $0.1 }
        cavityMesh.withUnsafeMutableBytes(bufferIndex: 0) { bytes in
            let vertices = bytes.bindMemory(to: Vertex.self)
            for i in edges.indices {
                let (top, bottom) = edges[i]
                vertices[i * 2] = .init(position: [top.x, top.y, 0.052], normal: [0, 0, 1])
                vertices[i * 2 + 1] = .init(position: [bottom.x, bottom.y, 0.052], normal: [0, 0, 1])
                let back = edges.count * 2 + i * 2
                vertices[back] = .init(position: [top.x, top.y, 0.016], normal: [0, 0, -1])
                vertices[back + 1] = .init(position: [bottom.x, bottom.y, 0.016], normal: [0, 0, -1])
            }
            for i in outline.indices {
                let a = outline[i], b = outline[(i + 1) % outline.count], delta = b - a
                let normal = simd_normalize(SIMD3<Float>(-delta.y, delta.x, 0))
                let start = edges.count * 4 + i * 4
                for (j, point) in [SIMD3<Float>(a.x, a.y, 0.052), [b.x, b.y, 0.052], [a.x, a.y, 0.016], [b.x, b.y, 0.016]].enumerated() {
                    vertices[start + j] = .init(position: point, normal: normal)
                }
            }
        }
        rimMesh.withUnsafeMutableBytes(bufferIndex: 0) { bytes in
            let vertices = bytes.bindMemory(to: Vertex.self)
            let radius = min(0.023, width * 0.032)
            for i in outline.indices {
                let tangent = simd_normalize(outline[(i + 1) % outline.count] - outline[(i + outline.count - 1) % outline.count])
                let outward = SIMD3<Float>(-tangent.y, tangent.x, 0)
                for side in 0..<sides {
                    let angle = Float(side) / Float(sides) * 2 * .pi
                    let normal = outward * cos(angle) + SIMD3<Float>(0, 0, sin(angle))
                    let point = outline[i]
                    vertices[i * sides + side] = .init(position: SIMD3<Float>(point.x, point.y, 0.057) + normal * radius, normal: normal)
                }
            }
        }
    }
}
#endif
