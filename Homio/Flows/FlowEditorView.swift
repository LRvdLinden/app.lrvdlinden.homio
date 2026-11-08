import HomeKit
import SwiftUI

/// Flow-editor zoals in Homey: drie blokken (Als… En… Dan…) met kaarten.
/// Tik op een kaart om hem in te stellen; houd vast om te verwijderen.
struct FlowEditorView: View {
    let replacing: HMTrigger?

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var flows: FlowStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: FlowDraft
    @State private var saving = false
    @State private var error: String?
    @State private var picking: FlowCardType?
    @State private var editing: FlowCardRef?
    @State private var tested = false

    init(initial: FlowDraft, replacing: HMTrigger?) {
        self.replacing = replacing
        _draft = State(initialValue: initial)
    }

    private var factory: FlowCardFactory { FlowCardFactory(home: home) }
    private var hasTrigger: Bool { draft.when.kind != .device || draft.when.deviceID != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Naam van de flow", text: $draft.name)
                            .font(HomeyFont.xlarge)
                            .submitLabel(.done)
                        Toggle(isOn: $draft.enabled) {
                            Text(draft.enabled ? "Ingeschakeld" : "Uitgeschakeld")
                                .font(HomeyFont.small)
                                .foregroundStyle(Theme.textLight)
                        }
                        .tint(Theme.green)
                    }

                    block(.when) {
                        if hasTrigger {
                            let c = factory.when(draft.when)
                            card(c, ref: .when, deletable: false)
                        } else {
                            AddCardButton(title: FlowCardType.when.addTitle) { picking = .when }
                        }
                    }

                    block(.and) {
                        ForEach(draft.ands) { andCard in
                            card(factory.and(andCard), ref: .and(andCard.id), deletable: true)
                        }
                        AddCardButton(title: FlowCardType.and.addTitle) { picking = .and }
                    }

                    block(.then) {
                        ForEach(draft.thens) { step in
                            card(factory.then(step), ref: .then(step.id), deletable: true)
                        }
                        if draft.revertAfterMinutes > 0 {
                            card(factory.revert(draft.revertAfterMinutes), ref: .revert, deletable: true)
                        }
                        AddCardButton(title: FlowCardType.then.addTitle) { picking = .then }
                    }

                    if let replacing {
                        Button {
                            flows.run(replacing)
                            tested.toggle()
                        } label: {
                            Label("Test deze flow", systemImage: "play.fill")
                                .font(HomeyFont.bodyMedium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Capsule().fill(Theme.blueGradient))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(PressableStyle())
                        .sensoryFeedback(.success, trigger: tested)
                        Text("Test voert de bewaarde versie uit, zonder op de trigger te wachten.")
                            .font(HomeyFont.tiny)
                            .foregroundStyle(Theme.textLight)
                    }
                }
                .padding(Theme.edge)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.background)
            .navigationTitle(replacing == nil ? "Nieuwe flow" : "Flow bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("Bewaar") { save() }
                            .fontWeight(.semibold)
                            .disabled(draft.thens.isEmpty || !hasTrigger)
                    }
                }
            }
            .sheet(item: $picking) { type in
                FlowCardPicker(type: type, draft: $draft) { ref in
                    // Kaarten met waarden meteen openen om in te stellen.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { editing = ref }
                }
            }
            .sheet(item: $editing) { ref in
                FlowCardEditSheet(ref: ref, draft: $draft)
                    .presentationDetents([.medium, .large])
            }
            .alert("Bewaren lukte niet", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text((error ?? "") + "\n\nFlows hebben een woninghub nodig: een Apple TV of HomePod.")
            }
        }
        .interactiveDismissDisabled(saving)
    }

    private func block<Content: View>(_ type: FlowCardType, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(type.heading).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.text)
            }
            content()
        }
    }

    private func card(_ c: (CardIcon, String, [CardText], Bool), ref: FlowCardRef, deletable: Bool) -> some View {
        Button { editing = ref } label: {
            FlowCardView(icon: c.0, owner: c.1, parts: c.2, invalid: c.3)
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button { editing = ref } label: { Label("Instellen", systemImage: "slider.horizontal.3") }
            if ref == .when {
                Button { picking = .when } label: { Label("Andere trigger kiezen", systemImage: "arrow.triangle.2.circlepath") }
            }
            if deletable {
                Button(role: .destructive) { remove(ref) } label: { Label("Verwijderen", systemImage: "trash") }
            }
        }
    }

    private func remove(_ ref: FlowCardRef) {
        withAnimation {
            switch ref {
            case .when: break
            case .and(let id): draft.ands.removeAll { $0.id == id }
            case .then(let id): draft.thens.removeAll { $0.id == id }
            case .revert: draft.revertAfterMinutes = 0
            }
        }
    }

    private func save() {
        saving = true
        Task {
            do {
                try await flows.save(draft, replacing: replacing)
                saving = false
                dismiss()
            } catch {
                saving = false
                self.error = error.localizedDescription
            }
        }
    }
}

/// Een kaart instellen: de kaart bovenaan, eronder de waarden.
struct FlowCardEditSheet: View {
    let ref: FlowCardRef
    @Binding var draft: FlowDraft

    @EnvironmentObject private var home: HomeStore
    @Environment(\.dismiss) private var dismiss

    private var factory: FlowCardFactory { FlowCardFactory(home: home) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                switch ref {
                case .when:
                    Section { WhenFields(draft: $draft) }
                case .and(let id):
                    if let index = draft.ands.firstIndex(where: { $0.id == id }) {
                        Section {
                            AndRow(card: $draft.ands[index], devices: home.devices.filter(\.hasStateCondition))
                        }
                    }
                case .then(let id):
                    if let index = draft.thens.firstIndex(where: { $0.id == id }) {
                        Section { ActionRow(step: $draft.thens[index], allowScene: true) }
                    }
                case .revert:
                    Section {
                        Picker("Terugzetten na", selection: $draft.revertAfterMinutes) {
                            ForEach([1, 2, 5, 10, 15, 30, 60], id: \.self) { m in
                                Text("\(m) min").tag(m)
                            }
                        }
                    } footer: {
                        Text("Handig bij beweging: lamp aan, en na een paar minuten weer uit.")
                    }
                }
            }
            .navigationTitle("Kaart instellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gereed") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch ref {
        case .when:
            let c = factory.when(draft.when)
            FlowCardView(icon: c.0, owner: c.1, parts: c.2, invalid: c.3)
        case .and(let id):
            if let card = draft.ands.first(where: { $0.id == id }) {
                let c = factory.and(card)
                FlowCardView(icon: c.0, owner: c.1, parts: c.2, invalid: c.3)
            }
        case .then(let id):
            if let step = draft.thens.first(where: { $0.id == id }) {
                let c = factory.then(step)
                FlowCardView(icon: c.0, owner: c.1, parts: c.2, invalid: c.3)
            }
        case .revert:
            let c = factory.revert(draft.revertAfterMinutes)
            FlowCardView(icon: c.0, owner: c.1, parts: c.2, invalid: c.3)
        }
    }
}

/// De instelbare waarden van de trigger-kaart.
struct WhenFields: View {
    @Binding var draft: FlowDraft
    @EnvironmentObject private var home: HomeStore

    private var triggerDevices: [Device] { home.devices.filter(\.canTrigger) }

    var body: some View {
        switch draft.when.kind {
        case .device:
            if let id = draft.when.deviceID, let device = home.device(id: id) {
                Picker("Gebeurtenis", selection: $draft.when.event) {
                    ForEach(DeviceEventKind.options(for: device.kind), id: \.self) { e in
                        Text(e.label.capitalizedFirst).tag(e)
                    }
                }
                if draft.when.event.needsThreshold {
                    Stepper(value: $draft.when.threshold, in: device.kind == .humidity ? 0.0...100.0 : -10.0...40.0,
                            step: device.kind == .humidity ? 5 : 0.5) {
                        LabeledContent("Grens", value: "\(draft.when.threshold.oneDecimal)\(device.thresholdUnit)")
                    }
                }
            } else {
                Text("Kies een apparaat met \"Andere trigger kiezen\".").foregroundStyle(Theme.textLight)
            }
        case .time:
            DatePicker("Tijd", selection: timeBinding, displayedComponents: .hourAndMinute)
            WeekdayPicker(selection: $draft.when.weekdays)
        case .sun:
            Picker("Moment", selection: $draft.when.sunrise) {
                Text("Zonsopkomst").tag(true)
                Text("Zonsondergang").tag(false)
            }
            .pickerStyle(.segmented)
            Stepper(value: $draft.when.offsetMinutes, in: -120...120, step: 5) {
                LabeledContent("Verschuiving",
                               value: draft.when.offsetMinutes == 0 ? "Precies op tijd"
                                   : (draft.when.offsetMinutes < 0 ? "\(-draft.when.offsetMinutes) min ervoor"
                                                                    : "\(draft.when.offsetMinutes) min erna"))
            }
        case .presence:
            Picker("Wie", selection: $draft.when.presence) {
                ForEach(PresenceKind.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            Text("Werkt met de locatie van gezinsleden in Apple Woning.")
                .font(.caption)
                .foregroundStyle(Theme.textLight)
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = draft.when.hour
                c.minute = draft.when.minute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft.when.hour = c.hour ?? 0
                draft.when.minute = c.minute ?? 0
            }
        )
    }
}

struct StepHeader: View {
    let badge: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            FlowBadge(text: badge, color: color)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

/// Maandag t/m zondag als rondjes; niets gekozen = elke dag.
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Weekdays.order, id: \.self) { day in
                    let on = selection.contains(day)
                    Button {
                        if on { selection.remove(day) } else { selection.insert(day) }
                    } label: {
                        Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                            .font(.subheadline.weight(.bold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(on ? IconPalette.orange : Color.primary.opacity(0.1)))
                            .foregroundStyle(on ? Color.black : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(selection.isEmpty ? "Elke dag" : "Alleen op de gekozen dagen")
                .font(.caption)
                .foregroundStyle(Theme.textLight)
        }
    }
}

private struct AndRow: View {
    @Binding var card: AndCard
    let devices: [Device]
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(card.kind.title, systemImage: card.kind.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(IconPalette.yellow)
            switch card.kind {
            case .timeBetween:
                DatePicker("Van", selection: time(\.fromHour, \.fromMinute), displayedComponents: .hourAndMinute)
                DatePicker("Tot", selection: time(\.toHour, \.toMinute), displayedComponents: .hourAndMinute)
            case .night:
                Text("Tussen zonsondergang en zonsopkomst").font(.caption).foregroundStyle(Theme.textLight)
            case .day:
                Text("Tussen zonsopkomst en zonsondergang").font(.caption).foregroundStyle(Theme.textLight)
            case .deviceState:
                Picker("Apparaat", selection: $card.deviceID) {
                    ForEach(devices) { device in
                        Text("\(device.name) · \(device.roomName)").tag(Optional(device.id))
                    }
                }
                if let id = card.deviceID, let device = home.device(id: id) {
                    Picker("Is", selection: $card.deviceOn) {
                        Text(device.stateWords.on).tag(true)
                        Text(device.stateWords.off).tag(false)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func time(_ hour: WritableKeyPath<AndCard, Int>, _ minute: WritableKeyPath<AndCard, Int>) -> Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = card[keyPath: hour]
                c.minute = card[keyPath: minute]
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                card[keyPath: hour] = c.hour ?? 0
                card[keyPath: minute] = c.minute ?? 0
            }
        )
    }
}

/// Eén actie: een apparaat bedienen of een sfeer starten. Ook gebruikt in de sfeer-editor.
struct ActionRow: View {
    @Binding var step: ActionStep
    var allowScene = false

    @EnvironmentObject private var home: HomeStore

    private var devices: [Device] { home.devices.filter(\.canBeControlled) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if step.mode == .scene && allowScene {
                Label("Sfeer starten", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(IconPalette.blue)
                Picker("Sfeer", selection: $step.sceneID) {
                    ForEach(home.scenes, id: \.uniqueIdentifier) { scene in
                        Text(scene.name).tag(Optional(scene.uniqueIdentifier))
                    }
                }
            } else {
                Picker("Apparaat", selection: Binding(
                    get: { step.deviceID },
                    set: { id in
                        guard let id, let device = home.device(id: id) else { return }
                        let fresh = ActionStep.defaults(for: device)
                        step.deviceID = id
                        step.mode = fresh.mode
                        step.value = fresh.value
                    }
                )) {
                    ForEach(devices) { device in
                        Label("\(device.name) · \(device.roomName)", systemImage: device.symbol)
                            .tag(Optional(device.id))
                    }
                }
                if let id = step.deviceID, let device = home.device(id: id) {
                    controls(for: device)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func controls(for device: Device) -> some View {
        switch device.kind {
        case .light:
            Picker("Actie", selection: Binding(
                get: { step.mode == .brightness ? 2 : (step.value > 0 ? 1 : 0) },
                set: { choice in
                    switch choice {
                    case 2:
                        step.mode = .brightness
                        if step.value <= 1 { step.value = 70 }
                    case 1:
                        step.mode = .power
                        step.value = 1
                    default:
                        step.mode = .power
                        step.value = 0
                    }
                }
            )) {
                Text("Aan").tag(1)
                Text("Uit").tag(0)
                if device.characteristic(HMCharacteristicTypeBrightness) != nil {
                    Text("Dimmen").tag(2)
                }
            }
            .pickerStyle(.segmented)
            if step.mode == .brightness {
                HStack {
                    Image(systemName: "sun.min")
                    Slider(value: $step.value, in: 1...100, step: 1).tint(IconPalette.yellow)
                    Text("\(Int(step.value))%").monospacedDigit().frame(width: 48, alignment: .trailing)
                }
            }
        case .outlet, .switchKind, .fan:
            onOff("Aan", "Uit")
        case .lock:
            onOff("Op slot", "Van het slot")
        case .garage:
            onOff("Openen", "Sluiten")
        case .blinds:
            HStack {
                Image(systemName: "blinds.horizontal.closed")
                Slider(value: $step.value, in: 0...100, step: 5).tint(.teal)
                Text("\(Int(step.value))%").monospacedDigit().frame(width: 48, alignment: .trailing)
            }
        case .thermostat:
            Stepper(value: $step.value, in: 10...30, step: 0.5) {
                LabeledContent("Temperatuur", value: "\(step.value.oneDecimal)°")
            }
        default:
            EmptyView()
        }
    }

    private func onOff(_ on: String, _ off: String) -> some View {
        Picker("Actie", selection: Binding(
            get: { step.value > 0 },
            set: { step.value = $0 ? 1 : 0 }
        )) {
            Text(on).tag(true)
            Text(off).tag(false)
        }
        .pickerStyle(.segmented)
    }
}
