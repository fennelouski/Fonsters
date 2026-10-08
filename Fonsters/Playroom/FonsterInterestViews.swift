#if os(macOS) || os(iOS)
import SwiftUI

struct FonsterInterestChip: View {
    let entity: FonsterInterestEntity
    var selected = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: entity.symbol).frame(width: 18).accessibilityHidden(true)
                Text(entity.title).font(.callout.weight(.semibold)).lineLimit(2)
                if selected { Image(systemName: "checkmark").font(.caption.weight(.bold)).accessibilityHidden(true) }
            }.padding(.horizontal, 13).padding(.vertical, 11)
                .foregroundStyle(FonsterTone.company.ink)
                .background(FonsterTone.company.wash, in: Capsule())
        }.buttonStyle(.plain)
            .fonsterHelp(entity.title + " · " + entity.source, symbol: entity.symbol,
                         detail: "View the source record and the details a visitor would see.")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("interestChip_" + entity.id)
    }
}

/// Owner text stays in the private draft. Results and selections are different
/// values; delayed work can never turn the query into a public chip.
struct FonsterInterestField: View {
    let title: String
    let symbol: String
    @Binding var values: [String]
    @Binding var selections: [FonsterInterestSelection]?
    let category: FonsterInterestCategory
    let identifier: String
    @Environment(\.scenePhase) private var scenePhase
    @State private var text = ""
    @State private var results: [FonsterInterestEntity] = []
    @State private var loading = false
    @State private var showing = false
    @State private var initialID: String?
    @FocusState private var focused: Bool
    private var chosen: [FonsterInterestEntity] {
        (selections ?? []).filter { $0.category == category }.compactMap { FonsterInterestCatalog.entity($0.catalogID) }
    }
    private var taskKey: String { category.rawValue + ":" + text + ":" + String(scenePhase == .active) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(FonsterChrome.primary)
            HStack(alignment: .top, spacing: 8) {
                TextField("Find an interest", text: $text, prompt: Text("Find an interest").foregroundStyle(FonsterChrome.secondary), axis: .vertical)
                    .lineLimit(1...3).textFieldStyle(.plain).foregroundStyle(FonsterChrome.primary)
                    .accessibilityLabel(title).accessibilityIdentifier(identifier).focused($focused)
                    .onChange(of: text) { _, value in
                        if value.count > 512 { text = String(value.prefix(512)) }
                        values = FonsterBiography.list(from: value)
                    }
                if loading { ProgressView().controlSize(.small).accessibilityLabel("Finding source records") }
                else if !results.isEmpty {
                    FonsterIconButton(title: "Choose from \(results.count) source records", symbol: "plus", tone: .company) {
                        focused = false; initialID = results.first?.id; showing = true
                    }.overlay(alignment: .topTrailing) {
                        Text(results.count, format: .number).font(.caption2.bold())
                            .padding(4).foregroundStyle(FonsterChrome.onSelection)
                            .background(FonsterTone.company.ink, in: Circle()).offset(x: 4, y: -4)
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }.accessibilityIdentifier(identifier + "Results")
                }
            }.padding(14).background(FonsterChrome.surface, in: RoundedRectangle(cornerRadius: 16))
            if !chosen.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(chosen) { entity in
                            FonsterInterestChip(entity: entity, selected: true) { focused = false; initialID = entity.id; showing = true }
                        }
                    }.padding(.vertical, 3)
                }.scrollIndicators(.hidden)
            }
            if !loading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && results.isEmpty {
                Label("Private draft · no match in the local catalog", systemImage: "lock")
                    .font(.caption).foregroundStyle(FonsterChrome.secondary).accessibilityIdentifier(identifier + "Private")
            }
        }
        .onAppear { text = values.joined(separator: ", ") }
        .onChange(of: values) { _, value in
            if FonsterBiography.list(from: text) != value { text = value.joined(separator: ", ") }
        }
        .task(id: taskKey) {
            results = []; loading = false
            guard scenePhase == .active, text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return }
            loading = true
            do {
                try await Task.sleep(for: .milliseconds(180))
                let found = try await FonsterCatalogResolver.shared.resolve(text, category: category)
                try Task.checkCancellation()
                results = found; loading = false
            } catch { if !Task.isCancelled { loading = false } }
        }
        .modifier(FonsterInterestPresentation(showing: $showing, entities: pickerEntities, initialID: initialID,
                                            selections: $selections, category: category, editable: true))
    }
    private var pickerEntities: [FonsterInterestEntity] {
        (results + chosen).reduce(into: []) { result, entity in if !result.contains(entity) { result.append(entity) } }
    }
}

private struct FonsterInterestPresentation: ViewModifier {
    @Binding var showing: Bool
    let entities: [FonsterInterestEntity]
    let initialID: String?
    @Binding var selections: [FonsterInterestSelection]?
    let category: FonsterInterestCategory
    let editable: Bool
    func body(content: Content) -> some View {
        #if os(macOS)
        content.popover(isPresented: $showing) { picker.frame(width: 420, height: 470) }
        #else
        content.sheet(isPresented: $showing) {
            picker.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        #endif
    }
    private var picker: some View {
        FonsterInterestPicker(entities: entities, initialID: initialID, selections: $selections,
                              category: category, editable: editable) { showing = false }
    }
}

private struct FonsterInterestPicker: View {
    let entities: [FonsterInterestEntity]
    let initialID: String?
    @Binding var selections: [FonsterInterestSelection]?
    let category: FonsterInterestCategory
    let editable: Bool
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var position: String?
    @State private var parentGate = ParentActionGate()
    private var index: Int { entities.firstIndex { $0.id == position } ?? 0 }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "square.stack.3d.up").foregroundStyle(FonsterTone.company.ink).accessibilityHidden(true)
                Text(editable ? "Source records" : "Interests").font(.headline)
                Spacer()
                FonsterInfo(title: "Source records", detail: "These entries are checked snapshots in a small local catalog, not live search. A source match identifies an interest; it is not a safety approval or endorsement. Choose more than one source with the checkmark. Tap it again to remove that choice. Only these canonical entries can be included in a new visit; your typed draft and backstory remain private. Swipe or use the arrows to browse.")
                FonsterIconButton(title: "Close source records", symbol: "xmark", action: close).accessibilityIdentifier("closeInterestRecords")
            }.padding(.horizontal, 20).padding(.top, 18)
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(entities) { entity in
                        detail(entity).padding(.horizontal, 20)
                            .containerRelativeFrame(.horizontal).id(entity.id)
                    }
                }.scrollTargetLayout()
            }.scrollIndicators(.hidden).scrollTargetBehavior(.paging).scrollPosition(id: $position)
            HStack {
                FonsterIconButton(title: "Previous source", symbol: "chevron.left") { position = entities[max(0, index - 1)].id }.disabled(index == 0)
                Spacer()
                Text("\(entities.isEmpty ? 0 : index + 1) / \(entities.count)").font(.caption.monospacedDigit()).foregroundStyle(FonsterChrome.secondary)
                Spacer()
                FonsterIconButton(title: "Next source", symbol: "chevron.right") { position = entities[min(entities.count - 1, index + 1)].id }.disabled(index + 1 >= entities.count)
            }.padding(.horizontal, 20).padding(.bottom, 16)
        }.background(FonsterChrome.background).foregroundStyle(FonsterChrome.primary)
            .onAppear { position = initialID ?? entities.first?.id }
            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.12), value: position)
            .parentActions(parentGate)
    }
    private func detail(_ entity: FonsterInterestEntity) -> some View {
        let selected = (selections ?? []).contains(.init(category: category, catalogID: entity.id))
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: entity.category == .places ? "mappin.and.ellipse" : entity.category == .music ? "music.note" : entity.symbol)
                        .font(.system(size: 36, weight: .light)).foregroundStyle(FonsterTone.company.ink)
                    Spacer()
                    if editable {
                        FonsterIconButton(title: selected ? "Remove this source" : "Select this source", symbol: selected ? "checkmark" : "plus", tone: .company, selected: selected) {
                            let choice = FonsterInterestSelection(category: category, catalogID: entity.id)
                            var next = selections ?? []
                            if selected { next.removeAll { $0 == choice } } else if next.count < 32 { next.append(choice) }
                            selections = next.isEmpty ? nil : next
                        }.accessibilityIdentifier("selectInterest_" + entity.id)
                    }
                }
                Text(entity.title).font(.title2.bold()).accessibilityIdentifier("interestDetailTitle")
                Label(entity.source, systemImage: entity.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(FonsterTone.company.ink)
                Text(entity.summary).font(.callout).foregroundStyle(FonsterChrome.secondary)
                HStack {
                    Text(entity.url.host ?? entity.source).font(.caption).foregroundStyle(FonsterChrome.secondary).lineLimit(2)
                    Spacer()
                    FonsterIconButton(title: "Open source in your browser", symbol: "arrow.up.right.square", tone: .world,
                        detail: "A grown-up reviews this link before leaving Fonsters for the source website.") {
                        parentGate.request("Open \(entity.url.host ?? "the source") in the browser. That website has its own privacy policy and content.") { openURL(entity.url) }
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: "eye").accessibilityHidden(true)
                    Label(entity.title, systemImage: entity.symbol)
                        .font(.callout.weight(.semibold)).padding(.horizontal, 13).padding(.vertical, 11)
                        .foregroundStyle(FonsterTone.company.ink).background(FonsterTone.company.wash, in: Capsule())
                        .accessibilityLabel("Visitor preview: " + entity.title + ", " + entity.source)
                }
            }.padding(.vertical, 14)
        }
    }
}

/// Recipient details never render a name, biography or query supplied in a visit.
struct FonsterRecipientInterests: View {
    let selections: [FonsterInterestSelection]
    @State private var showing = false
    @State private var initialID: String?
    private var checked: [FonsterInterestSelection] { FonsterInterestCatalog.validated(selections) }
    private var entities: [FonsterInterestEntity] {
        checked.compactMap { FonsterInterestCatalog.entity($0.catalogID) }.reduce(into: []) { result, item in
            if !result.contains(item) { result.append(item) }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entities.isEmpty { Label("No source interests shared", systemImage: "lock").font(.callout).foregroundStyle(FonsterChrome.secondary) }
            ForEach(entities) { entity in
                FonsterInterestChip(entity: entity) { initialID = entity.id; showing = true }
            }
        }.foregroundStyle(FonsterChrome.primary)
            .modifier(FonsterInterestPresentation(showing: $showing, entities: entities, initialID: initialID,
                selections: .constant(nil), category: .likes, editable: false))
    }
}
#endif
