import HomeKit
import SwiftUI

struct FlowEditTarget: Identifiable {
    let id = UUID()
    let draft: FlowDraft
    let trigger: HMTrigger?
}

/// Het Flows-tabblad: alle automatiseringen, met aan/uit, nu uitvoeren, bewerken en verwijderen.
struct FlowsTab: View {
    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var flows: FlowStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var editing: FlowEditTarget?
    @State private var toDelete: HMTrigger?

    var body: some View {
        NavigationStack {
            HomeStateGate {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        intro
                        if home.triggers.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .compact ? 300 : 360), spacing: 14)],
                                      spacing: 14) {
                                ForEach(home.triggers, id: \.uniqueIdentifier) { trigger in
                                    FlowCard(trigger: trigger,
                                             onEdit: { edit(trigger) },
                                             onDelete: { toDelete = trigger })
                                }
                            }
                        }
                        templates
                    }
                    .padding(.horizontal, sizeClass == .compact ? 16 : 28)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("Flows")
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

    private func edit(_ trigger: HMTrigger) {
        if let draft = flows.draft(for: trigger) {
            editing = FlowEditTarget(draft: draft, trigger: trigger)
        }
    }

    private var intro: some View {
        HStack(spacing: 10) {
            FlowBadge(text: "ALS", color: IconPalette.orange)
            FlowBadge(text: "EN", color: IconPalette.yellow)
            FlowBadge(text: "DAN", color: IconPalette.blue)
            Text("Flows draaien op je woninghub, ook als Homio dicht is.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            GradientIcon(symbol: "arrow.triangle.branch", colors: [IconPalette.orange, IconPalette.blue], size: 56)
            Text("Laat je huis zelf werken").font(.title2.weight(.bold))
            Text("Maak een flow: als er iets gebeurt, en het klopt, dan doet Homio iets. Bijvoorbeeld: als de gang beweging ziet en het is donker, dan gaat de ganglamp aan en na 5 minuten weer uit.")
                .foregroundStyle(.secondary)
            Button {
                editing = FlowEditTarget(draft: FlowDraft(), trigger: nil)
            } label: {
                Label("Nieuwe flow", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Snelstart-sjablonen

    private var templates: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Snel beginnen").font(.headline).foregroundStyle(.white.opacity(0.7))
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
        .foregroundStyle(.white)
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

private struct FlowCard: View {
    let trigger: HMTrigger
    let onEdit: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var flows: FlowStore
    @EnvironmentObject private var home: HomeStore
    @State private var ran = false

    private var editable: Bool { flows.draft(for: trigger) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                GradientIcon(symbol: "arrow.triangle.branch",
                             colors: trigger.isEnabled ? [IconPalette.orange, IconPalette.blue] : [Color.gray, Color.gray.opacity(0.6)],
                             size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(trigger.name).font(.headline).lineLimit(2)
                    if let last = trigger.lastFireDate {
                        Text("Laatst: \(last.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("Aan", isOn: Binding(
                    get: { trigger.isEnabled },
                    set: { value in Task { await flows.setEnabled(trigger, value) } }
                ))
                .labelsHidden()
                .tint(IconPalette.blue)
            }
            Text(flows.summary(for: trigger))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(4)
            HStack(spacing: 8) {
                Button {
                    flows.run(trigger)
                    ran.toggle()
                } label: {
                    Label("Nu uitvoeren", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .tint(IconPalette.blue)
                Spacer()
                if editable {
                    Button(action: onEdit) { Image(systemName: "pencil") }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Bewerken")
                }
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Verwijderen")
            }
            .font(.subheadline.weight(.semibold))
            if !editable {
                Text("Gemaakt in de Woning-app. Aan/uit en uitvoeren kan hier; bewerken in de Woning-app.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .card()
        .sensoryFeedback(.success, trigger: ran)
        .contextMenu {
            Button { flows.run(trigger) } label: { Label("Nu uitvoeren", systemImage: "play.fill") }
            if editable {
                Button(action: onEdit) { Label("Bewerken", systemImage: "pencil") }
            }
            Button(role: .destructive, action: onDelete) { Label("Verwijderen", systemImage: "trash") }
        }
    }
}
