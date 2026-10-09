#if os(macOS) || os(iOS)
import SwiftUI
import SceneKit
import CoreText
import simd

/// Explicitly transparent native surface; the world stays visible beneath it.
#if os(macOS)
typealias LaunchViewRepresentable = NSViewRepresentable
#else
typealias LaunchViewRepresentable = UIViewRepresentable
#endif
@available(macOS 15.0, iOS 18.0, *)
struct FonsterLaunchViewport: LaunchViewRepresentable {
    let scene: SCNScene
    private func make() -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = scene; view.backgroundColor = .clear
        #if os(iOS)
        view.isOpaque = false
        #endif
        view.isPlaying = true; view.rendersContinuously = true
        view.antialiasingMode = .multisampling4X
        return view
    }
    #if os(macOS)
    func makeNSView(context: Context) -> SCNView { make() }
    func updateNSView(_ view: SCNView, context: Context) {}
    #else
    func makeUIView(context: Context) -> SCNView { make() }
    func updateUIView(_ view: SCNView, context: Context) {}
    #endif
}

/// Launch-only mascots. Equal-topology meshes let the *body and fur* morph,
/// rather than putting portraits over a typeset word. No saved appearance changes.
@available(macOS 15.0, iOS 18.0, *)
@MainActor final class FonsterLaunchScene {
    let scene = SCNScene()
    private var letters: [SCNNode] = []
    private var morphers: [SCNMorpher] = []
    init() {
        scene.background.contents = FonsterPlatformColor.clear
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true; camera.camera?.orthographicScale = 1.5
        camera.position = SCNVector3(0, 0, 8); scene.rootNode.addChildNode(camera)
        let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni
        light.light?.intensity = 950; light.position = SCNVector3(-3, 5, 6); scene.rootNode.addChildNode(light)
        let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .ambient
        fill.light?.intensity = 500; scene.rootNode.addChildNode(fill)
        let colors: [FonsterPlatformColor] = [.systemPink, .systemGreen, .systemPurple, .systemTeal, .systemOrange, .systemIndigo, .systemRed]
        for (i, letter) in "ONSTERS".enumerated() {
            let pair = Self.meshes(letter)
            let body = SCNNode(geometry: pair.0)
            let material = SCNMaterial(); material.diffuse.contents = colors[i]
            material.lightingModel = .physicallyBased; material.roughness.contents = 1.0
            material.isDoubleSided = true; body.geometry?.materials = [material]
            let morph = SCNMorpher(); morph.targets = [pair.1]; morph.calculationMode = .normalized
            body.morpher = morph; morphers.append(morph)
            let creature = SCNNode(); creature.addChildNode(body)
            // Faces are on the body, with depth and soft material, never portraits.
            for x: Float in [-0.12, 0.12] {
                let eye = SCNNode(geometry: SCNSphere(radius: 0.082)); eye.geometry?.firstMaterial?.diffuse.contents = FonsterPlatformColor.white
                eye.position = SCNVector3(x, 0.29, 0.22); creature.addChildNode(eye)
                let pupil = SCNNode(geometry: SCNSphere(radius: 0.038)); pupil.geometry?.firstMaterial?.diffuse.contents = FonsterPlatformColor.black
                pupil.position = SCNVector3(x, 0.30, 0.289); creature.addChildNode(pupil)
            }
            for j in 0..<9 {
                let x = Float(j - 4) * 0.025
                let smile = SCNNode(geometry: SCNSphere(radius: 0.021)); smile.geometry?.firstMaterial?.diffuse.contents = FonsterPlatformColor.white
                smile.position = SCNVector3(x, 0.13 + x * x * 5, 0.245); creature.addChildNode(smile)
            }
            creature.scale = SCNVector3(0.42, 0.42, 0.42)
            creature.eulerAngles = SCNVector3(-0.07, -0.23, 0)
            creature.position = SCNVector3(-3, -0.1, -0.2); creature.opacity = 0
            scene.rootNode.addChildNode(creature); letters.append(creature)
        }
    }
    func emerge(quick: Bool) {
        for (i, node) in letters.enumerated() {
            let move = SCNAction.move(to: SCNVector3(Float(i - 3) * 0.85 + 0.4, 0, 0), duration: quick ? 0.45 : 0.65)
            move.timingMode = .easeInEaseOut
            node.runAction(.sequence([.wait(duration: Double(i) * 0.035), .group([move, .fadeIn(duration: 0.15)])]))
        }
    }
    func formLetters(quick: Bool) {
        for (i, node) in letters.enumerated() {
            let morph = morphers[i]
            node.runAction(.customAction(duration: quick ? 0.45 : 0.65) { _, elapsed in
                let p = Double(elapsed) / (quick ? 0.45 : 0.65)
                morph.setWeight(CGFloat(p * p * (3 - 2 * p)), forTargetAt: 0)
            })
        }
    }
    func scatter(quick: Bool) {
        for (i, node) in letters.enumerated() {
            let run = SCNAction.moveBy(x: CGFloat(i.isMultiple(of: 2) ? -8 : 8), y: CGFloat(i % 3) * 0.5, z: -2, duration: quick ? 0.45 : 0.65)
            run.timingMode = .easeIn
            node.runAction(.group([run, .rotateBy(x: 0, y: 0.4, z: i.isMultiple(of: 2) ? -0.3 : 0.3, duration: 0.5)]))
        }
    }
    func stop() {
        for node in letters { node.removeAllActions() }
        scene.rootNode.isPaused = true
    }
    private static func meshes(_ letter: Character) -> (SCNGeometry, SCNGeometry) {
        let font = CTFontCreateWithName("AvenirNext-Heavy" as CFString, 100, nil)
        var character = String(letter).utf16.first!, glyph: CGGlyph = 0
        CTFontGetGlyphsForCharacters(font, &character, &glyph, 1)
        let path = CTFontCreatePathForGlyph(font, glyph, nil)!
        let bounds = path.boundingBox
        var blob: [SCNVector3] = [], shaped: [SCNVector3] = [], indices: [Int32] = []
        var blobNormals: [SCNVector3] = [], shapedNormals: [SCNVector3] = []
        func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ ta: SIMD3<Float>, _ tb: SIMD3<Float>, _ tc: SIMD3<Float>) {
            let n = Int32(blob.count); indices += [n, n + 1, n + 2]
            let normal = simd_normalize(simd_cross(b-a,c-a))
            let targetNormal = simd_normalize(simd_cross(tb-ta,tc-ta))
            for _ in 0..<3 {
                blobNormals.append(SCNVector3(normal.x,normal.y,normal.z))
                shapedNormals.append(SCNVector3(targetNormal.x,targetNormal.y,targetNormal.z))
            }
            for p in [a,b,c] { blob.append(SCNVector3(p.x,p.y,p.z)) }
            for p in [ta,tb,tc] { shaped.append(SCNVector3(p.x,p.y,p.z)) }
        }
        let columns = 42, rows = 54
        func occupied(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, y >= 0, x < columns, y < rows else { return false }
            return path.contains(CGPoint(x: bounds.minX + (CGFloat(x) + 0.5) / CGFloat(columns) * bounds.width,
                                         y: bounds.minY + (CGFloat(y) + 0.5) / CGFloat(rows) * bounds.height))
        }
        func point(_ x: Int, _ y: Int, _ z: Float) -> SIMD3<Float> {
            [Float((CGFloat(x) / CGFloat(columns) - 0.5) * bounds.width / bounds.height) * 1.15,
             Float(CGFloat(y) / CGFloat(rows) - 0.5) * 1.15, z]
        }
        func round(_ p: SIMD3<Float>) -> SIMD3<Float> {
            let length = sqrt(p.x*p.x + p.y*p.y + p.z*p.z)
            return [p.x / length * 0.46, p.y / length * 0.46, p.z / length * 0.32]
        }
        func face(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
            triangle(round(a),round(b),round(c),a,b,c)
            triangle(round(a),round(c),round(d),a,c,d)
        }
        for y in 0..<rows { for x in 0..<columns where occupied(x,y) {
            let a=point(x,y,0.14), b=point(x+1,y,0.14), c=point(x+1,y+1,0.14), d=point(x,y+1,0.14)
            let e=point(x,y,-0.14), f=point(x+1,y,-0.14), g=point(x+1,y+1,-0.14), h=point(x,y+1,-0.14)
            // A watertight extruded silhouette: adjoining cells share positions.
            // Only outside faces are emitted, with no separate bead geometry.
            face(a,b,c,d); face(h,g,f,e)
            if !occupied(x-1,y) { face(e,a,d,h) }
            if !occupied(x+1,y) { face(b,f,g,c) }
            if !occupied(x,y-1) { face(e,f,b,a) }
            if !occupied(x,y+1) { face(d,c,g,h) }
            for strand in 0..<5 {
                let angle = Float(x*17 + y*31 + strand*7) * 2.399963
                let t = (a+b+c+d) / 4 + SIMD3<Float>(cos(angle)*0.009,sin(angle)*0.009,0)
                let direction = SIMD3<Float>(cos(angle)*0.045,sin(angle)*0.045,0.055)
                let edge = SIMD3<Float>(0.0015,-0.0015,0)
                let start = round(t)
                triangle(start-edge,start+edge,start+direction,t-edge,t+edge,t+direction)
            }
        }}
        let elements = [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        return (SCNGeometry(sources: [.init(vertices: blob), .init(normals: blobNormals)], elements: elements), SCNGeometry(sources: [.init(vertices: shaped), .init(normals: shapedNormals)], elements: elements))
    }
}
#endif
