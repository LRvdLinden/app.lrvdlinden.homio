import HomeKit
import SwiftUI

struct FlowEditTarget: Identifiable {
    let id = UUID()
    let draft: FlowDraft
    let trigger: HMTrigger?
}

/// Het Flows-tabblad zoals in Homey: favorieten als pillen met startknop, daarna alle
/// flows als rijen met een ronde startknop, en sjablonen om snel te beginnen.
struct FlowsTab: View {
    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var flows: FlowStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var editing: FlowEditTarget?
    @State private var toDelete: HMTrigger?
    @State private var query = ""
    @State private var info: HMTrigger?

    private var filtered: [HMTrigger] {
        let all = home.triggers.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            HomeStateGate {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        let favorites = home.triggers.filter { flows.isFavorite($0) }
                        if !favorites.isEmpty && query.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeading(title: "Favoriete flows", subtitle: nil)
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                    ForEach(favorites, id: \.uniqueIdentifier) { trigger in
                                        FlowPill(trigger: trigger)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeading(title: "Alle flows",
                                           subtitle: "Flows draaien op je woninghub, ook als Homio dicht is.")
                            if filtered.isEmpty {
                                emptyState
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(filtered, id: \.uniqueIdentifier) { trigger in
                                        FlowRow(trigger: trigger,
                                                onOpen: { open(trigger) },
                                                onDelete: { toDelete = trigger })
                                    }
                                }
                            }
                        }
                        if query.isEmpty { templates }
                    }
                    .padding(.horizontal, sizeClass == .compact ? Theme.edge : Theme.edgeTablet)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
                .searchable(text: $query, prompt: "Zoek een flow")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("Automatisering")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = FlowEditTarget(draft: FlowDraft(), trigger: nil) } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nieuwe flow")
                }
            }
            .sheet(item: $editing) { target in
                FlowEditorView(initial: target.draft, replacing: target.trigger)
            }
            .confirmationDialog("Flow verwijderen?",
                                isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Verwijderen", role: .destructive) {
                    if let trigger = toDelete {
                        Task {
                            do { try await flows.delete(trigger) } catch { flows.lastError = error.localizedDescription }
                        }
                    }
                    toDelete = nil
                }
            }
            .alert(info?.name ?? "", isPresented: Binding(get: { info != nil }, set: { if !$0 { info = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Deze flow is gemaakt in de Woning-app. In Homio kun je hem aan- en uitzetten en starten; bewerken doe je in de Woning-app.\n\n" + (info.map { flows.summary(for: $0) } ?? ""))
            }
            .alert("Er ging iets mis", isPresented: Binding(
                get: { flows.lastError != nil },
                set: { if !$0 { flows.lastError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(flows.lastError ?? "")
            }
        }
    }

    private func open(_ trigger: HMTrigger) {
        if let draft = flows.draft(for: trigger) {
            editing = FlowEditTarget(draft: draft, trigger: trigger)
        } else {
            info = trigger
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.blueGradient))
            Text(query.isEmpty ? "Laat je huis zelf werken" : "Geen flow gevonden").font(HomeyFont.large.weight(.bold))
            if query.isEmpty {
                Text("Een flow is een zin: als er iets gebeurt, en het klopt, dan doet Homio iets. Bijvoorbeeld: als de gang beweging ziet en het is donker, dan gaat de ganglamp aan en na 5 minuten weer uit.")
                    .foregroundStyle(Theme.textLight)
                Button {
                    editing = FlowEditTarget(draft: FlowDraft(), trigger: nil)
                } label: {
                    Label("Nieuwe flow", systemImage: "plus")
                        .font(HomeyFont.bodyMedium)
                        .padding(.horizontal, 20)
                        .frame(height: 44)
                        .background(Capsule().fill(Theme.accent))
                        .foregroundStyle(.white)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.card))
    }

    // MARK: Snelstart-sjablonen

    private var templates: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Snel beginnen").font(.headline).foregroundStyle(Color.primary.opacity(0.7))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    template("Licht bij beweging", "figure.walk.motion") {
                        var d = FlowDraft(name: "Licht bij beweging")
                        d.when.kind = .device
                        d.when.deviceID = home.devices.first { $0.kind == .motion }?.id
                        d.when.event = .motion
                        d.ands = [AndCard(kind: .night)]
                        if let light = home.devices.first(where: { $0.kind == .light }) {
                            d.thens = [ActionStep.defaults(for: light)]
                        }
                        d.revertAfterMinutes = 5
                        return d
                    }
                    template("Thuiskomen in het donker", "figure.walk.arrival") {
                        var d = FlowDraft(name: "Thuiskomen in het donker")
                        d.when.kind = .presence
                        d.when.presence = .anyoneArrives
                        d.ands = [AndCard(kind: .night)]
                        d.thens = home.devices.filter { $0.kind == .light }.prefix(3).map { ActionStep.defaults(for: $0) }
                        return d
                    }
                    template("Welterusten om 23:00", "moon.fill") {
                        var d = FlowDraft(name: "Welterusten")
                        d.when.kind = .time
                        d.when.hour = 23
                        d.thens = home.devices.filter { $0.kind == .light }.map { light in
                            var step = ActionStep.defaults(for: light)
                            step.value = 0
                            return step
                        }
                        return d
                    }
                    template("Lampen aan bij zonsondergang", "sunset.fill") {
                        var d = FlowDraft(name: "Avondlicht")
                        d.when.kind = .sun
                        d.when.sunrise = false
                        d.thens = home.devices.filter { $0.kind == .light }.prefix(3).map { ActionStep.defaults(for: $0) }
                        return d
                    }
                    template("Alles uit als iedereen weg is", "figure.walk.departure") {
                        var d = FlowDraft(name: "Iedereen weg")
                        d.when.kind = .presence
                        d.when.presence = .lastLeaves
                        d.thens = home.devices.filter { $0.kind == .light || $0.kind == .outlet }.map { device in
                            var step = ActionStep.defaults(for: device)
                            step.value = 0
                            return step
                        }
                        if let lock = home.devices.first(where: { $0.kind == .lock }) {
                            d.thens.append(ActionStep.defaults(for: lock))
                        }
                        return d
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private func template(_ title: String, _ symbol: String, make: @escaping () -> FlowDraft) -> some View {
        Button {
            editing = FlowEditTarget(draft: make(), trigger: nil)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                GradientIcon(symbol: symbol, colors: [IconPalette.orange, IconPalette.yellow], size: 40)
                Text(title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(width: 170, height: 130, alignment: .topLeading)
            .card()
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.primary)
    }
}

struct FlowBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(color))
            .foregroundStyle(.black)
    }
}

/// Kop van een sectie, zoals in Homey: vet, met een grijze uitleg eronder.
struct SectionHeading: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(HomeyFont.large.weight(.bold)).foregroundStyle(Theme.text)
            if let subtitle {
                Text(subtitle).font(HomeyFont.small).foregroundStyle(Theme.textLight)
            }
        }
    }
}

/// Ronde startknop van een flow (blauw verloop, grijs als hij uit staat).
struct FlowRunButton: View {
    let trigger: HMTrigger
    var size: CGFloat = 40
    @EnvironmentObject private var flows: FlowStore
    @State private var ran = 0

    var body: some View {
        Button {
            flows.run(trigger)
            ran += 1
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: size * 0.03)
                .frame(width: size, height: size)
                .background(Circle().fill(trigger.isEnabled ? AnyShapeStyle(Theme.green) : AnyShapeStyle(Theme.iconLight)))
                .symbolEffect(.bounce, value: ran)
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.success, trigger: ran)
        .accessibilityLabel("\(trigger.name) nu uitvoeren")
    }
}

/// Favoriete flow als pil (Homey FlowTileSmall): startknop + naam.
private struct FlowPill: View {
    let trigger: HMTrigger

    var body: some View {
        HStack(spacing: 8) {
            FlowRunButton(trigger: trigger, size: 32)
            Text(trigger.name)
                .font(HomeyFont.smallMedium)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card)
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1))
        .opacity(trigger.isEnabled ? 1 : 0.45)
    }
}

/// Eén flow in de lijst: startknop, naam, aantal acties en status.
private struct FlowRow: View {
    let trigger: HMTrigger
    let onOpen: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var flows: FlowStore

    private var editable: Bool { flows.draft(for: trigger) != nil }

    var body: some View {
        HStack(spacing: 12) {
            FlowRunButton(trigger: trigger)
            Button(action: onOpen) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(trigger.name)
                                .font(HomeyFont.bodyMedium)
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                            if flows.isFavorite(trigger) {
                                Image(systemName: "heart.fill").font(.caption2).foregroundStyle(Theme.red)
                            }
                        }
                        Text(subtitle)
                            .font(HomeyFont.tiny)
                            .foregroundStyle(Theme.textLight)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: editable ? "chevron.right" : "info.circle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.iconLight)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 60)
        .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.card))
        .opacity(trigger.isEnabled ? 1 : 0.6)
        .contextMenu {
            Button { flows.run(trigger) } label: { Label("Nu uitvoeren", systemImage: "play.fill") }
            Button { flows.toggleFavorite(trigger) } label: {
                Label(flows.isFavorite(trigger) ? "Uit favorieten" : "Aan favorieten", systemImage: "heart")
            }
            Button {
                Task { await flows.setEnabled(trigger, !trigger.isEnabled) }
            } label: {
                Label(trigger.isEnabled ? "Uitschakelen" : "Inschakelen",
                      systemImage: trigger.isEnabled ? "pause.circle" : "checkmark.circle")
            }
            Button(action: onOpen) { Label(editable ? "Bewerken" : "Info", systemImage: editable ? "pencil" : "info.circle") }
            Button(role: .destructive, action: onDelete) { Label("Verwijderen", systemImage: "trash") }
        }
    }

    private var subtitle: String {
        if !trigger.isEnabled { return "Uitgeschakeld" }
        let count = flows.actionCount(trigger)
        var parts = [count == 1 ? "1 actie" : "\(count) acties"]
        if !editable { parts.append("uit de Woning-app") }
        return parts.joined(separator: " · ")
    }
}
