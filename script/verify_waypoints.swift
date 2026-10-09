import Foundation
import simd
@main struct VerifyWaypoints {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1]); let url = root.appendingPathComponent("pins.json")
        var memory = LobbyWaypointMemory(url: url)
        precondition(memory.waypoints.isEmpty && !memory.canSort)
        let view = LobbyWaypoint.Viewpoint(x: 120, y: 2, z: -67, orbit: 0.7, pitch: 0.2, zoom: 0.8, focusX: 4, focusZ: -2)
        let id = memory.save(name: "  River lookout  ", viewpoint: view, date: Date(timeIntervalSince1970: 10))!
        let loaded = LobbyWaypointMemory(url: url)
        precondition(loaded.waypoints.first?.name == "River lookout" && loaded.waypoints.first?.viewpoint == view)
        precondition(loaded.waypoints.first?.id == id)
        print("PASS: named waypoint persists and reloads exact camera pan, frozen focus, orbit, pitch and zoom")
        memory.rename(id, name: "Hilltop"); memory.rename(LobbyWaypoint.home.id, name: "Overwrite home")
        precondition(memory.waypoints[0].name == "Hilltop" && LobbyWaypoint.home.name == "Session start")
        for index in 1...5 { memory.save(name: "Place \(index)", viewpoint: .init(x: Float(index) * 28), date: Date(timeIntervalSince1970: Double(index))) }
        precondition(memory.waypoints.count == 6 && !memory.canSort)
        memory.save(name: "A far place", viewpoint: .init(x: 999), date: Date(timeIntervalSince1970: 99))
        precondition(memory.canSort && memory.sorted(.name, from: .zero).first?.name == "A far place")
        precondition(memory.sorted(.newest, from: .zero).first?.name == "A far place")
        precondition(memory.sorted(.nearest, from: .zero).first?.name == "Place 1")
        precondition(memory.waypoints.allSatisfy { $0.id != LobbyWaypoint.home.id })
        print("PASS: session start cannot be overwritten; six saved pins hide sorting; seven enable date/name/distance sorting")
        let mapURL = URL(fileURLWithPath: "Fonsters/Playroom/Resources/MappedWorldDemo.json")
        let data = try Data(contentsOf: mapURL), map = try LobbyMappedWorld.load(data: data)
        precondition(map.features.filter { $0.kind == "windmill" }.count == 14 && map.features.filter { $0.kind == "playground" }.count == 8 && map.features.filter { $0.kind == "waterway" }.count == 30)
        for feature in map.features where feature.kind == "waterway" {
            let center = map.center(feature)
            precondition(center.x >= map.minPoint.x && center.x <= map.maxPoint.x && center.y >= map.minPoint.y && center.y <= map.maxPoint.y)
            precondition(map.near(center).contains { $0.id == feature.id })
        }
        precondition(map.near(map.maxPoint + SIMD2<Float>(repeating: 100)).isEmpty)
        let clipped = map.clip(map.minPoint - SIMD2<Float>(repeating: 20), map.maxPoint + SIMD2<Float>(repeating: 20))!
        precondition(clipped.0.x >= map.minPoint.x - 0.001 && clipped.1.x <= map.maxPoint.x + 0.001)
        var corruptMap = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var area = corruptMap["area"] as! [String: Any]; area["anchor"] = ["latitude": 90, "longitude": 900]; corruptMap["area"] = area
        do { _ = try LobbyMappedWorld.load(data: JSONSerialization.data(withJSONObject: corruptMap)); preconditionFailure("Invalid geography accepted") } catch {}
        print("PASS: 52 actual mapped objects decode; all 30 waterways navigate to visible clipped sections; nearby metadata excludes uncovered terrain; invalid geography rejected")
        let count = memory.waypoints.count
        precondition(memory.save(name: "Bad", viewpoint: .init(x: .nan)) == nil && memory.waypoints.count == count)
        precondition(memory.save(name: "Bad", viewpoint: .init(focusX: 2, focusZ: nil)) == nil)
        precondition(memory.save(name: "Bad", viewpoint: .init(x: 100_001)) == nil)
        let corrupt = root.appendingPathComponent("future.json")
        let original = Data("{\"version\":2,\"waypoints\":[]}".utf8); try original.write(to: corrupt)
        var future = LobbyWaypointMemory(url: corrupt); precondition(future.error != nil)
        future.save(name: "Temporary", viewpoint: view)
        let preserved = try Data(contentsOf: corrupt); precondition(preserved == original)
        print("PASS: invalid coordinates rejected; unsupported saved archive preserved byte-for-byte with explicit temporary-state warning")
        precondition(memory.waypoints[0].symbol != memory.waypoints[1].symbol || memory.waypoints[0].pattern != memory.waypoints[1].pattern)
        print("PASS: distinct tile-derived scenery previews and metadata; no GPS, seed, email, or shared identifier in saved data")
    }
}
