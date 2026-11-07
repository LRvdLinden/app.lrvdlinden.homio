import HomeKit
import SwiftUI

/// Flow-editor in drie stappen: ALS (oranje), EN (geel), DAN (blauw).
struct FlowEditorView: View {
    let replacing: HMTrigger?

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var flows: FlowStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: FlowDraft
    @State private var saving = false
    @State private var error: String?

    init(initial: FlowDraft, replacing: HMTrigger?) {
        self.replacing = replacing
        _draft = State(initialValue: initial)
    }

    private var triggerDevices: [Device] { home.devices.filter(\.canTrigger) }
    private var conditionDevices: [Device] { home.devices.filter(\.hasStateCondition) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Naam (bijv. Licht in de gang)", text: $draft.name)
                    Toggle("Ingeschakeld", isOn: $draft.enabled)
                }

                // ALS
                Section {
                    Picker("Wat", selection: $draft.when.kind) {
                        ForEach(WhenKind.allCases, id: \.self) { kind in
                            Label(kind.title, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    whenFields
                } header: {
                    StepHeader(badge: "ALS", color: IconPalette.orange, text: draft.whenText(home))
                }

                // EN
                Section {
                    ForEach($draft.ands) { $card in
                        AndRow(card: $card, devices: conditionDevices)
                    }
                    .onDelete { draft.ands.remove(atOffsets: $0) }
                    Menu {
                        ForEach(AndKind.allCases, id: \.self) { kind in
                            Button {
                                var card = AndCard(kind: kind)
                                if kind == .deviceState { card.deviceID = conditionDevices.first?.id }
                                draft.ands.append(card)
                            } label: {
                                Label(kind.title, systemImage: kind.symbol)
                            }
                        }
                    } label: {
                        Label("Voorwaarde toevoegen", systemImage: "plus.circle.fill")
                            .foregroundStyle(IconPalette.yellow)
                    }
                } header: {
                    StepHeader(badge: "EN", color: IconPalette.yellow,
                               text: draft.ands.isEmpty ? "Altijd (geen voorwaarden)" : "\(draft.ands.count) voorwaarde(n)")
                } footer: {
                    Text("Alle voorwaarden moeten kloppen. Veeg naar links om er een te verwijderen.")
                }

                // DAN
                Section {
                    ForEach($draft.thens) { $step in
                        ActionRow(step: $step, allowScene: true)
                    }
                    .onDelete { draft.thens.remove(atOffsets: $0) }
                    Menu {
                        Button {
                            if let device = home.devices.first(where: \.canBeControlled) {
                                draft.thens.append(ActionStep.defaults(for: device))
                            }
                        } label: { Label("Apparaat bedienen", systemImage: "lightbulb.fill") }
                        Button {
                            draft.thens.append(ActionStep(mode: .scene, sceneID: home.scenes.first?.uniqueIdentifier))
                        } label: { Label("Sfeer starten", systemImage: "sparkles") }
                        .disabled(home.scenes.isEmpty)
                    } label: {
                        Label("Actie toevoegen", systemImage: "plus.circle.fill")
                            .foregroundStyle(IconPalette.blue)
                    }
                    Picker("Daarna terug na", selection: $draft.revertAfterMinutes) {
                        Text("Nooit").tag(0)
                        ForEach([1, 2, 5, 10, 15, 30, 60], id: \.self) { m in
                            Text("\(m) min").tag(m)
                        }
                    }
                } header: {
                    StepHeader(badge: "DAN", color: IconPalette.blue,
                               text: draft.thens.isEmpty ? "Nog geen acties" : "\(draft.thens.count) actie(s)")
                } footer: {
                    Text("Met 'Daarna terug na' zet de woninghub alles na die tijd weer terug, bijvoorbeeld de lamp uit na beweging.")
                }

                Section {
                    Text(draft.summary(home))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Samenvatting")
                }
            }
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
                            .disabled(draft.thens.isEmpty)
                    }
                }
            }
            .alert("Bewaren lukte niet", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text((error ?? "") + "\n\nFlows hebben een woninghub nodig: een Apple TV of HomePod.")
            }
        }
        .interactiveDismissDisabled(saving)
    }

    // MARK: ALS-velden

    @ViewBuilder
    private var whenFields: some View {
        switch draft.when.kind {
        case .device:
            if triggerDevices.isEmpty {
                Text("Geen apparaten die iets kunnen melden.").foregroundStyle(.secondary)
            } else {
                Picker("Apparaat", selection: Binding(
                    get: { draft.when.deviceID ?? triggerDevices.first?.id },
                    set: { id in
                        draft.when.deviceID = id
                        if let id, let device = home.device(id: id) {
                            let options = DeviceEventKind.options(for: device.kind)
                            if !options.contains(draft.when.event), let first = options.first { draft.when.event = first }
                        }
                    }
                )) {
                    ForEach(triggerDevices) { device in
                        Text("\(device.name) · \(device.roomName)").tag(Optional(device.id))
                    }
                }
                if let device = home.device(id: draft.when.deviceID ?? triggerDevices.first?.id ?? UUID()) {
                    Picker("Gebeurtenis", selection: $draft.when.event) {
                        ForEach(DeviceEventKind.options(for: device.kind), id: \.self) { e in
                            Text(e.label).tag(e)
                        }
                    }
                    if draft.when.event.needsThreshold {
                        Stepper(value: $draft.when.threshold, in: device.kind == .humidity ? 0.0...100.0 : -10.0...40.0,
                                step: device.kind == .humidity ? 5 : 0.5) {
                            LabeledContent("Grens", value: "\(draft.when.threshold.oneDecimal)\(device.thresholdUnit)")
                        }
                    }
                }
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
                .foregroundStyle(.secondary)
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

    private func save() {
        var toSave = draft
        if toSave.when.kind == .device && toSave.when.deviceID == nil {
            toSave.when.deviceID = triggerDevices.first?.id
        }
        saving = true
        Task {
            do {
                try await flows.save(toSave, replacing: replacing)
                saving = false
                dismiss()
            } catch {
                saving = false
                self.error = error.localizedDescription
            }
        }
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
                .foregroundStyle(.white)
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
                            .background(Circle().fill(on ? IconPalette.orange : Color.white.opacity(0.1)))
                            .foregroundStyle(on ? Color.black : Color.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(selection.isEmpty ? "Elke dag" : "Alleen op de gekozen dagen")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                Text("Tussen zonsondergang en zonsopkomst").font(.caption).foregroundStyle(.secondary)
            case .day:
                Text("Tussen zonsopkomst en zonsondergang").font(.caption).foregroundStyle(.secondary)
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
