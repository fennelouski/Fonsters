#if os(macOS) || os(iOS)
import SwiftUI
import simd

@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
struct LobbyWaypointsView: View {
    @Bindable var lobby: LocalLobbyController
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: LobbyWaypoint.Viewpoint?
    @State private var name = ""
    @State private var renaming: UUID?
    @State private var help = false
    @State private var catalog = false
    @State private var previewID = UUID()
    @State private var landmarkKind = "windmill"
    @FocusState private var naming: Bool
    private var preview: LobbyWaypoint {
        let view = draft ?? lobby.waypointViewpoint
        let map = view.worldID == lobby.mappedDemo?.area.id ? lobby.mappedDemo : nil
        let near = map?.near(view.position) ?? []
        return .init(id: previewID, name: name, createdAt: .now, viewpoint: view,
                     landmarkNames: near.prefix(3).map(\.name), areaName: map?.area.name, landmarkSymbol: map.map { $0.symbol(near.first?.kind) })
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(FonsterTone.world.ink)
                    Text("Saved places").font(.title2.bold())
                    Spacer()
                    FonsterIconButton(title: "Waypoint help", symbol: "questionmark.circle", detail: "Explain saving, naming, and returning to places.") { help.toggle() }
                    FonsterIconButton(title: "Close saved places", symbol: "xmark") { close() }
                }
                if help {
                    Text("Pin the view you’re exploring, give it a name, then tap its arrow to return. Session start always takes you home. Undo restores your previous view. Sorting opens after seven saved places. Saved views stay private. The public mapped sample is offline; it never tracks your location.")
                        .font(.callout).foregroundStyle(FonsterChrome.secondary).transition(.opacity)
                }
                row(.home, permanent: true)
                if let map = lobby.mappedDemo {
                    HStack {
                        Image(systemName: "globe.europe.africa.fill").foregroundStyle(FonsterTone.world.ink)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(map.area.name).font(.headline)
                            Text("Offline mapped sample · incomplete coverage").font(.caption).foregroundStyle(FonsterChrome.secondary)
                        }
                        Spacer()
                        FonsterIconButton(title: "Explore mapped landmarks", symbol: "map", tone: .world, selected: catalog, detail: "Choose a real mapped windmill, playground, or waterway in this public sample. No location permission or network request.") { catalog.toggle() }
                            .accessibilityIdentifier("mappedLandmarkCatalog")
                    }.padding(12).background(FonsterTone.world.wash, in: RoundedRectangle(cornerRadius: 18))
                    if catalog {
                        FonsterControlGroup(title: "Landmark type", tone: .world) {
                            ForEach(["windmill", "playground", "waterway"], id: \.self) { kind in
                                FonsterIconButton(title: kind == "windmill" ? "Windmills" : kind == "playground" ? "Playgrounds" : "Waterways", symbol: map.symbol(kind), tone: .world, selected: landmarkKind == kind) { landmarkKind = kind }
                                    .accessibilityIdentifier("mappedKind_" + kind)
                            }
                        }
                        LazyVStack(spacing: 8) {
                            ForEach(map.features.filter { $0.kind == landmarkKind }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { feature in
                                Button { lobby.visitMappedFeature(feature); close() } label: {
                                    HStack { Image(systemName: map.symbol(feature.kind)); Text(feature.name).lineLimit(2); Spacer(); Image(systemName: "arrow.up.right") }
                                        .font(.callout).padding(12).background(FonsterChrome.surface, in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain).fonsterHoverHelp("Explore mapped " + feature.kind + ": " + feature.name)
                                    .accessibilityIdentifier("mappedFeature_" + feature.id)
                            }
                        }
                    }
                }
                if let draft {
                    VStack(spacing: 12) {
                        WaypointThumbnail(waypoint: preview, map: lobby.mappedDemo).frame(height: 130).clipShape(RoundedRectangle(cornerRadius: 18))
                        HStack {
                            TextField("Place name", text: $name).textFieldStyle(.roundedBorder).focused($naming)
                                .accessibilityIdentifier("waypointNameField").onSubmit { save(draft) }
                            FonsterIconButton(title: "Save waypoint", symbol: "checkmark", tone: .world) { save(draft) }
                                .accessibilityIdentifier("saveWaypoint")
                            FonsterIconButton(title: "Cancel naming", symbol: "xmark") { self.draft = nil; renaming = nil; naming = false }
                        }
                    }.transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    HStack {
                        WaypointThumbnail(waypoint: preview, map: lobby.mappedDemo).frame(width: 88, height: 62).clipShape(RoundedRectangle(cornerRadius: 12))
                        Text(preview.terrain).font(.headline)
                        Spacer()
                        FonsterIconButton(title: "Pin this place", symbol: "plus.circle.fill", tone: .world, detail: "Save the current view. Choose a name before saving.") {
                            draft = lobby.waypointViewpoint; name = preview.terrain; renaming = nil; naming = true
                        }.accessibilityIdentifier("pinCurrentPlace")
                    }.padding(12).background(FonsterTone.world.wash, in: RoundedRectangle(cornerRadius: 18))
                }
                if let error = lobby.waypoints.error { Text(error).font(.callout).foregroundStyle(FonsterChrome.primary).accessibilityIdentifier("waypointSaveError") }
                if lobby.waypoints.canSort {
                    Menu {
                        ForEach(LobbyWaypointMemory.Order.allCases, id: \.self) { order in
                            Button { lobby.waypointOrder = order } label: { Label(order.title, systemImage: order.symbol) }
                        }
                    } label: { Label(lobby.waypointOrder.title, systemImage: "arrow.up.arrow.down") }
                    .fonsterHoverHelp("Sort saved places by date, distance, or name").accessibilityIdentifier("waypointSort")
                }
                LazyVStack(spacing: 10) { ForEach(lobby.sortedWaypoints) { row($0, permanent: false) } }
                if lobby.waypoints.waypoints.isEmpty { Image(systemName: "map").font(.system(size: 36)).foregroundStyle(FonsterChrome.secondary).frame(maxWidth: .infinity).padding(18).accessibilityLabel("No saved places yet. Use Pin this place to start exploring.") }
            }.padding(24)
        }
        .foregroundStyle(FonsterChrome.primary).background(FonsterChrome.background)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82), value: draft != nil)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: help)
        #if os(macOS)
        .frame(width: 540, height: 640)
        #else
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        #endif
    }
    private func row(_ waypoint: LobbyWaypoint, permanent: Bool) -> some View {
        HStack(spacing: 12) {
            WaypointThumbnail(waypoint: waypoint, map: lobby.mappedDemo).frame(width: 88, height: 62).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(waypoint.name).font(.headline)
                Text(permanent ? "Pinned for this session" : waypoint.metadata).font(.caption).foregroundStyle(FonsterChrome.secondary)
                if !permanent { Text(waypoint.createdAt, format: .dateTime.month(.abbreviated).day()).font(.caption2).foregroundStyle(FonsterChrome.secondary) }
            }
            Spacer(minLength: 4)
            if !permanent {
                FonsterIconButton(title: "Rename " + waypoint.name, symbol: "pencil", tone: .world) { draft = waypoint.viewpoint; name = waypoint.name; renaming = waypoint.id; naming = true }
            }
            FonsterIconButton(title: "Go to " + waypoint.name, symbol: permanent ? "house.fill" : "arrow.up.right", tone: .world, detail: "Restore this place’s camera view. Undo returns to your previous view.") { lobby.visitWaypoint(waypoint); close() }
                .accessibilityIdentifier(permanent ? "waypointSessionStart" : "visitWaypoint_" + waypoint.name)
        }.padding(12).background(FonsterChrome.surface, in: RoundedRectangle(cornerRadius: 18))
    }
    private func save(_ view: LobbyWaypoint.Viewpoint) {
        if let renaming { lobby.waypoints.rename(renaming, name: name) }
        else { lobby.waypoints.save(name: name, viewpoint: view, landmarkNames: preview.landmarkNames, areaName: preview.areaName, landmarkSymbol: preview.landmarkSymbol) }
        draft = nil; renaming = nil; naming = false
    }
}

/// A small illustrated map of the same deterministic tile seen in the world.
/// Pin coordinates, terrain and placement make each saved view distinctive.
struct WaypointThumbnail: View {
    let waypoint: LobbyWaypoint
    var map: LobbyMappedWorld? = nil
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.65, green: 0.79, blue: 0.57)))
            let w = size.width, h = size.height
            if waypoint.viewpoint.worldID == nil {
            context.fill(Path(CGRect(x: 0, y: h * 0.47, width: w, height: h * 0.075)), with: .color(Color(red: 0.92, green: 0.86, blue: 0.70)))
            context.fill(Path(CGRect(x: w * 0.47, y: 0, width: w * 0.075, height: h)), with: .color(Color(red: 0.92, green: 0.86, blue: 0.70)))
            }
            for i in 0..<(waypoint.viewpoint.worldID == nil ? 8 : 0) {
                let n = waypoint.pattern &+ UInt64(i) &* 7919
                let px = CGFloat(n % 11) * 2 + 2, pz = CGFloat((n / 17) % 11) * 2 + 2
                guard abs(px - 14) >= 2, abs(pz - 14) >= 2 else { continue }
                let rect = CGRect(x: px / 28 * w - w * 0.05, y: pz / 28 * h - h * 0.07, width: w * 0.13, height: h * 0.18)
                if waypoint.pattern % 4 == 1 { context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Color(red: 0.72, green: 0.48, blue: 0.35))) }
                else { context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.24, green: 0.48, blue: 0.24))) }
            }
            if let map, waypoint.viewpoint.worldID == map.area.id {
                let origin = SIMD2<Float>(Float(waypoint.tileX) * 28, Float(waypoint.tileZ) * 28)
                func point(_ p: SIMD2<Float>) -> CGPoint { CGPoint(x: CGFloat((p.x - origin.x) / 28) * w, y: CGFloat((p.y - origin.y) / 28) * h) }
                for feature in map.features {
                    if feature.kind == "waterway" {
                        for line in feature.geometry.lines {
                            let points = line.map(map.project)
                            for (a, b) in zip(points, points.dropFirst()) {
                                guard let (a, b) = map.clip(a, b, lower: simd_max(origin, map.minPoint), upper: simd_min(origin + SIMD2<Float>(repeating: 28), map.maxPoint)) else { continue }
                                var path = Path(); path.move(to: point(a)); path.addLine(to: point(b))
                                context.stroke(path, with: .color(Color(red: 0.35, green: 0.69, blue: 0.79)), lineWidth: feature.waterwayType == "river" ? h * 0.13 : h * 0.018)
                            }
                        }
                    } else {
                        let center = map.center(feature)
                        if center.x >= origin.x && center.y >= origin.y && center.x < origin.x + 28 && center.y < origin.y + 28 {
                            context.draw(Text(Image(systemName: map.symbol(feature.kind))).font(.system(size: 12)).foregroundStyle(Color(red: 0.18, green: 0.37, blue: 0.28)), at: point(center))
                        }
                    }
                }
            }
            let p = waypoint.viewpoint.position
            let x = CGFloat(p.x / 28 - floor(p.x / 28)) * w, y = CGFloat(p.y / 28 - floor(p.y / 28)) * h
            context.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(Color(red: 0.13, green: 0.32, blue: 0.27)))
            context.draw(Text(Image(systemName: waypoint.symbol)).font(.system(size: min(w, h) * 0.24, weight: .bold)).foregroundStyle(Color.white), at: CGPoint(x: w * 0.82, y: h * 0.22))
        }.accessibilityLabel(waypoint.terrain + ", tile \(waypoint.tileX), \(waypoint.tileZ)")
    }
}

@available(macOS 15.0, iOS 18.0, tvOS 26.0, *)
struct WaypointWorldPins: View {
    @Bindable var lobby: LocalLobbyController
    var body: some View {
        GeometryReader { geometry in
            ForEach(lobby.waypointMarkers) { marker in
                Button { lobby.visitWaypoint(marker.waypoint) } label: {
                    Image(systemName: marker.id == LobbyWaypoint.home.id ? "house.circle.fill" : "mappin.circle.fill")
                        .font(.system(size: 25)).foregroundStyle(.white, FonsterTone.world.ink)
                        .padding(8).background(.regularMaterial, in: Circle()).shadow(color: .black.opacity(0.15), radius: 5, y: 3)
                }.buttonStyle(.plain).fonsterHoverHelp("Return to " + marker.waypoint.name)
                    .accessibilityLabel("Return to " + marker.waypoint.name)
                    .position(x: CGFloat(marker.point.x) * geometry.size.width, y: CGFloat(marker.point.y) * geometry.size.height)
            }
        }.allowsHitTesting(true).accessibilityIdentifier("waypointWorldMarkers")
    }
}
#endif
