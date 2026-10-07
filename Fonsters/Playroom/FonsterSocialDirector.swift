#if os(macOS)
import Foundation
import Observation

@available(macOS 15.0, *)
@MainActor @Observable
final class FonsterSocialDirector {
    enum Mode: String, CaseIterable, Identifiable {
        case review, localFeed
        var id: String { rawValue }
        var title: String { self == .review ? "Review each draft" : "Post locally" }
    }
    let store: FonsterSocialStore
    private(set) var activeID: UUID?
    private(set) var mode = Mode.review
    private(set) var message = "A little presence, at your pace."
    @ObservationIgnored private var nextPilotAt = Date.distantPast
    @ObservationIgnored private var nextWritingAt = Date.distantPast
    init(store: FonsterSocialStore? = nil) { self.store = store ?? .localPreview() }
    var running: Bool { activeID != nil }
    func setMode(_ mode: Mode, lobby: LocalLobbyController) { stop(lobby: lobby); self.mode = mode }
    func start(lobby: LocalLobbyController, now: Date = .now) throws {
        let member = lobby.selectedMember
        guard !member.isVisitor, store.profile(member.id) != nil else { throw FonsterSocialError.noProfile }
        guard lobby.ready, !lobby.paused, !lobby.backgrounded, !lobby.lowPower, !lobby.still, !lobby.reduceMotion else { throw FonsterSocialError.unavailable }
        lobby.takeOwnerControl()
        activeID = member.id; nextPilotAt = max(nextPilotAt, now.addingTimeInterval(1)); nextWritingAt = max(nextWritingAt, now.addingTimeInterval(1))
        message = mode == .review ? "Local companion agent on · new moments become drafts." : "Local companion agent on · posting only to this Mac's feed."
    }
    func stop(lobby: LocalLobbyController) {
        guard activeID != nil else { return }
        activeID = nil; lobby.agent.takeOver(lobby: lobby)
        message = "Agent paused. Your profiles and posts are kept."
    }
    func ownerTookOver() {
        guard activeID != nil else { return }
        activeID = nil; message = "You took over. Start the profile agent again when you're ready."
    }
    func observe(_ action: FonsterAgentAction, id: UUID, source: FonsterAgentSource, now: Date) {
        let provenance: FonsterSocialSource = source == .simulated ? .simulatedAgent : .reviewedAgent
        let event: FonsterSocialEvent?
        switch action.kind {
        case .greet: event = .init(kind: .wave, source: provenance, date: now)
        case .playTogether: event = .init(kind: .game, source: provenance, date: now)
        case .quietTogether: event = .init(kind: .rest, source: provenance, date: now)
        case .explore: event = .init(kind: .explore, area: action.area, source: provenance, date: now)
        case .bench: event = .init(kind: .bench, source: provenance, date: now)
        case .react: event = Self.reaction(action.reaction ?? "", source: provenance, now: now)
        // Neither Fonster feelings nor private human reflections are social input.
        case .feeling, .reflect: event = nil
        }
        if let event { store.record(event, id: id) }
    }
    func ownerMoment(reaction: String, id: UUID, now: Date = .now) {
        if let event = Self.reaction(reaction, source: .ownerAction, now: now) { store.record(event, id: id) }
    }
    func advance(lobby: LocalLobbyController, now: Date) {
        guard let id = activeID, lobby.shouldAnimate else { return }
        guard lobby.selectedMember.id == id, !lobby.selectedMember.isVisitor else { stop(lobby: lobby); return }
        if now >= nextWritingAt {
            nextWritingAt = now.addingTimeInterval(60)
            do {
                let draft = try store.makeDraft(id: id, now: now)
                if mode == .localFeed { try FonsterLocalFeedAdapter().publish(draft.id, profileID: id, store: store, now: now) }
                message = mode == .review ? "A new Fonster moment is ready for your review." : "A new little moment joined this Mac's feed."
            } catch FonsterSocialError.noEvent { /* no fabricated filler or engagement */ }
            catch FonsterSocialError.limited { /* no tap or restart generated queue */ }
            catch { message = error.localizedDescription }
        }
        guard now >= nextPilotAt, !lobby.agent.running else { return }
        nextPilotAt = now.addingTimeInterval(100)
        do {
            try lobby.agent.prepareDemo(lobby: lobby, now: now, includeReflections: false)
            try lobby.agent.start(lobby: lobby, now: now)
        } catch { message = error.localizedDescription }
    }
    private static func reaction(_ reaction: String, source: FonsterSocialSource, now: Date) -> FonsterSocialEvent? {
        let kind: FonsterSocialEvent.Kind
        switch reaction {
        case "greet", "highFive": kind = .wave
        case "play", "fetch": kind = .game
        case "rest", "rub", "stretch": kind = .rest
        case "look": kind = .look
        case "hop", "spin": kind = .dance
        default: return nil
        }
        return .init(kind: kind, source: source, date: now)
    }
}
#endif
