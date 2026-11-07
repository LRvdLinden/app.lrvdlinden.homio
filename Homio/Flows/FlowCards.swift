import HomeKit
import SwiftUI

// MARK: - Homey-achtige flow-kaart

/// Soort kaart: Als (trigger), En (voorwaarde) of Dan (actie).
enum FlowCardType: String, Identifiable {
    case when, and, then
    var id: String { rawValue }

    var heading: String {
        switch self {
        case .when: return "Als…"
        case .and: return "En…"
        case .then: return "Dan…"
        }
    }

    var question: String {
        switch self {
        case .when: return "Wanneer moet deze flow starten?"
        case .and: return "Wat moet er ook kloppen?"
        case .then: return "Wat moet er gebeuren?"
        }
    }

    var addTitle: String {
        switch self {
        case .when: return "Kies een trigger"
        case .and: return "Voorwaarde toevoegen"
        case .then: return "Actie toevoegen"
        }
    }
}

/// Een deel van de kaarttekst: gewone tekst of een instelbare waarde (blauw, zoals in Homey).
struct CardText: Hashable {
    let text: String
    let isArgument: Bool

    static func t(_ s: String) -> CardText { CardText(text: s, isArgument: false) }
    static func a(_ s: String) -> CardText { CardText(text: s, isArgument: true) }
}

/// Icoon links op de kaart: een apparaat of een app (SF Symbol op een gekleurd vlak).
enum CardIcon {
    case device(Device)
    case app(symbol: String, color: Color)
}

/// Homey-apps die Homio nadoet, met hun kleuren uit de Homey-app.
enum FlowApp {
    static let dateTime = (name: "Datum & tijd", symbol: "clock.fill", color: Color(red: 0xDA / 255, green: 0x27 / 255, blue: 0x24 / 255))
    static let sun = (name: "Zon", symbol: "sun.horizon.fill", color: Color(red: 0xF7 / 255, green: 0xB5 / 255, blue: 0))
    static let presence = (name: "Aanwezigheid", symbol: "figure.walk", color: Color(red: 0x9C / 255, green: 0x47 / 255, blue: 0xFC / 255))
    static let scenes = (name: "Sferen", symbol: "sparkles", color: Color(red: 0xB6 / 255, green: 0x20 / 255, blue: 0xE0 / 255))
    static let homio = (name: "Homio", symbol: "timer", color: Color(red: 0x5C / 255, green: 0xCB / 255, blue: 0x41 / 255))
}

/// De kaart zelf: wit vlak, icoon links, eigenaar klein erboven, zin met blauwe waarden.
struct FlowCardView: View {
    let icon: CardIcon
    let owner: String
    let parts: [CardText]
    var invalid = false

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 2) {
                Text(owner)
                    .font(HomeyFont.tiny)
                    .foregroundStyle(Theme.textLight)
                    .lineLimit(1)
                sentence
                    .font(.system(size: 15, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if invalid {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.orange)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.card)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }

    private var sentence: Text {
        parts.reduce(Text("")) { result, part in
            if part.isArgument {
                return result + Text(part.text).foregroundColor(Theme.accent).underline(color: Theme.accent.opacity(0.35))
            }
            return result + Text(part.text).foregroundColor(Theme.text)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .device(let device):
            DeviceIcon(device: device, size: 26)
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall + 3, style: .continuous).fill(Theme.tileOff))
        case .app(let symbol, let color):
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall + 3, style: .continuous).fill(color.gradient))
        }
    }
}

/// "+ Kaart toevoegen" in Homey-blauw.
struct AddCardButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 16))
                Text(title).font(HomeyFont.smallMedium)
            }
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.accent.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Kaartinhoud uit een flow

@MainActor
struct FlowCardFactory {
    let home: HomeStore

    func when(_ w: WhenCard) -> (CardIcon, String, [CardText], Bool) {
        switch w.kind {
        case .device:
            guard let id = w.deviceID, let d = home.device(id: id) else {
                return (.app(symbol: "questionmark", color: .gray), "Apparaat", [.t("Kies een apparaat")], true)
            }
            if w.event.needsThreshold {
                let what = d.kind == .humidity ? "Vochtigheid" : "Temperatuur"
                return (.device(d), d.name, [.t("\(what) \(w.event.label) "), .a("\(w.threshold.oneDecimal)\(d.thresholdUnit)")], false)
            }
            return (.device(d), d.name, [.t(w.event.label.capitalizedFirst)], false)
        case .time:
            let time = String(format: "%02d:%02d", w.hour, w.minute)
            return (.app(symbol: FlowApp.dateTime.symbol, color: FlowApp.dateTime.color), FlowApp.dateTime.name,
                    [.t("Het is "), .a(time), .t(" op "), .a(days(w.weekdays))], false)
        case .sun:
            let moment = w.sunrise ? "zonsopkomst" : "zonsondergang"
            var parts: [CardText] = []
            if w.offsetMinutes == 0 {
                parts = [.t("Bij "), .a(moment)]
            } else {
                parts = [.a("\(abs(w.offsetMinutes)) min"), .t(w.offsetMinutes < 0 ? " voor " : " na "), .a(moment)]
            }
            return (.app(symbol: w.sunrise ? "sunrise.fill" : "sunset.fill", color: FlowApp.sun.color), FlowApp.sun.name, parts, false)
        case .presence:
            return (.app(symbol: FlowApp.presence.symbol, color: FlowApp.presence.color), FlowApp.presence.name,
                    [.a(w.presence.label)], false)
        }
    }

    func and(_ c: AndCard) -> (CardIcon, String, [CardText], Bool) {
        switch c.kind {
        case .timeBetween:
            return (.app(symbol: FlowApp.dateTime.symbol, color: FlowApp.dateTime.color), FlowApp.dateTime.name,
                    [.t("Tijd is tussen "), .a(String(format: "%02d:%02d", c.fromHour, c.fromMinute)),
                     .t(" en "), .a(String(format: "%02d:%02d", c.toHour, c.toMinute))], false)
        case .night:
            return (.app(symbol: "moon.stars.fill", color: FlowApp.sun.color), FlowApp.sun.name, [.t("Het is "), .a("donker")], false)
        case .day:
            return (.app(symbol: "sun.max.fill", color: FlowApp.sun.color), FlowApp.sun.name, [.t("Het is "), .a("licht")], false)
        case .deviceState:
            guard let id = c.deviceID, let d = home.device(id: id) else {
                return (.app(symbol: "questionmark", color: .gray), "Apparaat", [.t("Kies een apparaat")], true)
            }
            return (.device(d), d.name, [.t("Is "), .a(c.deviceOn ? d.stateWords.on : d.stateWords.off)], false)
        }
    }

    func then(_ s: ActionStep) -> (CardIcon, String, [CardText], Bool) {
        if s.mode == .scene {
            let name = home.scene(id: s.sceneID)?.name
            return (.app(symbol: FlowApp.scenes.symbol, color: FlowApp.scenes.color), FlowApp.scenes.name,
                    [.t("Start "), .a(name ?? "kies een sfeer")], name == nil)
        }
        guard let id = s.deviceID, let d = home.device(id: id) else {
            return (.app(symbol: "questionmark", color: .gray), "Apparaat", [.t("Kies een apparaat")], true)
        }
        let parts: [CardText]
        switch s.mode {
        case .power: parts = [.t("Zet "), .a(s.value > 0 ? "aan" : "uit")]
        case .brightness: parts = s.value > 0 ? [.t("Dim naar "), .a("\(Int(s.value))%")] : [.t("Zet "), .a("uit")]
        case .temperature: parts = [.t("Zet temperatuur op "), .a("\(s.value.oneDecimal)°")]
        case .lock: parts = [.t("Doe "), .a(s.value > 0 ? "op slot" : "van het slot")]
        case .position: parts = [.t("Zet op "), .a("\(Int(s.value))% open")]
        case .door: parts = [.a(s.value > 0 ? "Openen" : "Sluiten")]
        case .scene: parts = []
        }
        return (.device(d), d.name, parts, false)
    }

    func revert(_ minutes: Int) -> (CardIcon, String, [CardText], Bool) {
        (.app(symbol: FlowApp.homio.symbol, color: FlowApp.homio.color), FlowApp.homio.name,
         [.t("Na "), .a("\(minutes) min"), .t(" alles terugzetten")], false)
    }

    private func days(_ set: Set<Int>) -> String {
        if set.isEmpty || set.count == 7 { return "elke dag" }
        if set == [2, 3, 4, 5, 6] { return "werkdagen" }
        if set == [1, 7] { return "het weekend" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return Weekdays.order.filter { set.contains($0) }.map { symbols[$0 - 1] }.joined(separator: ", ")
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

// MARK: - Kaartkiezer (zoals "Kaart kiezen" in Homey)

/// Kies eerst een app of apparaat, daarna de kaart.
struct FlowCardPicker: View {
    let type: FlowCardType
    @Binding var draft: FlowDraft
    /// Wordt aangeroepen met de nieuwe kaart, zodat de editor hem meteen kan openen.
    var onAdded: (FlowCardRef) -> Void

    @EnvironmentObject private var home: HomeStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private func matches(_ s: String) -> Bool {
        query.isEmpty || s.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Apps") {
                    ForEach(apps.indices, id: \.self) { i in
                        let app = apps[i]
                        if matches(app.name) {
                            NavigationLink {
                                AppCardsList(type: type, app: app.name, draft: $draft) { ref in
                                    onAdded(ref)
                                    dismiss()
                                }
                            } label: {
                                row(icon: .app(symbol: app.symbol, color: app.color), title: app.name, subtitle: nil)
                            }
                        }
                    }
                }
                ForEach(rooms, id: \.name) { room in
                    let devices = room.devices.filter { matches($0.name) || matches(room.name) }
                    if !devices.isEmpty {
                        Section(room.name) {
                            ForEach(devices) { device in
                                NavigationLink {
                                    DeviceCardsList(type: type, device: device, draft: $draft) { ref in
                                        onAdded(ref)
                                        dismiss()
                                    }
                                } label: {
                                    row(icon: .device(device), title: device.name, subtitle: device.stateText)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Zoek een app of apparaat")
            .navigationTitle(type.addTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer") { dismiss() } }
            }
        }
    }

    private var apps: [(name: String, symbol: String, color: Color)] {
        switch type {
        case .when: return [FlowApp.dateTime, FlowApp.sun, FlowApp.presence]
        case .and: return [FlowApp.dateTime, FlowApp.sun]
        case .then:
            var list = [FlowApp.scenes]
            if draft.revertAfterMinutes == 0 { list.append(FlowApp.homio) }
            return list
        }
    }

    private var rooms: [RoomGroup] {
        home.rooms.map { room in
            RoomGroup(name: room.name, devices: room.devices.filter { d in
                switch type {
                case .when: return d.canTrigger
                case .and: return d.hasStateCondition
                case .then: return d.canBeControlled
                }
            })
        }
    }

    private func row(icon: CardIcon, title: String, subtitle: String?) -> some View {
        HStack(spacing: 12) {
            FlowCardView(icon: icon, owner: "", parts: []).iconOnly
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(HomeyFont.tiny).foregroundStyle(Theme.textLight)
                }
            }
        }
    }
}

extension FlowCardView {
    /// Alleen het icoonvlak, voor lijsten.
    var iconOnly: some View {
        Group {
            switch icon {
            case .device(let device):
                DeviceIcon(device: device, size: 20)
                    .foregroundStyle(Theme.text)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.tileOff))
            case .app(let symbol, let color):
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color.gradient))
            }
        }
    }
}

/// Verwijzing naar een kaart in de flow (om hem na toevoegen meteen te openen).
enum FlowCardRef: Identifiable, Hashable {
    case when
    case and(UUID)
    case then(UUID)
    case revert

    var id: String {
        switch self {
        case .when: return "when"
        case .and(let id): return "and-\(id)"
        case .then(let id): return "then-\(id)"
        case .revert: return "revert"
        }
    }
}

private struct PickRow: View {
    let parts: [CardText]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                parts.reduce(Text("")) { $0 + Text($1.text).foregroundColor($1.isArgument ? Theme.accent : Theme.text) }
                Spacer()
                Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
            }
        }
    }
}

private struct AppCardsList: View {
    let type: FlowCardType
    let app: String
    @Binding var draft: FlowDraft
    let done: (FlowCardRef) -> Void
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        List {
            switch (type, app) {
            case (.when, FlowApp.dateTime.name):
                PickRow(parts: [.t("Het is "), .a("…"), .t(" op "), .a("…")]) {
                    draft.when = WhenCard(kind: .time)
                    done(.when)
                }
            case (.when, FlowApp.sun.name):
                PickRow(parts: [.t("Bij "), .a("zonsondergang")]) {
                    draft.when = WhenCard(kind: .sun, sunrise: false)
                    done(.when)
                }
                PickRow(parts: [.t("Bij "), .a("zonsopkomst")]) {
                    draft.when = WhenCard(kind: .sun, sunrise: true)
                    done(.when)
                }
            case (.when, FlowApp.presence.name):
                ForEach(PresenceKind.allCases, id: \.self) { p in
                    PickRow(parts: [.a(p.label)]) {
                        draft.when = WhenCard(kind: .presence, presence: p)
                        done(.when)
                    }
                }
            case (.and, FlowApp.dateTime.name):
                PickRow(parts: [.t("Tijd is tussen "), .a("…"), .t(" en "), .a("…")]) {
                    let card = AndCard(kind: .timeBetween)
                    draft.ands.append(card)
                    done(.and(card.id))
                }
            case (.and, FlowApp.sun.name):
                PickRow(parts: [.t("Het is "), .a("donker")]) {
                    let card = AndCard(kind: .night)
                    draft.ands.append(card)
                    done(.and(card.id))
                }
                PickRow(parts: [.t("Het is "), .a("licht")]) {
                    let card = AndCard(kind: .day)
                    draft.ands.append(card)
                    done(.and(card.id))
                }
            case (.then, FlowApp.scenes.name):
                if home.scenes.isEmpty {
                    Text("Nog geen sferen.").foregroundStyle(Theme.textLight)
                }
                ForEach(home.scenes, id: \.uniqueIdentifier) { scene in
                    PickRow(parts: [.t("Start "), .a(scene.name)]) {
                        let step = ActionStep(mode: .scene, sceneID: scene.uniqueIdentifier)
                        draft.thens.append(step)
                        done(.then(step.id))
                    }
                }
            case (.then, FlowApp.homio.name):
                PickRow(parts: [.t("Na "), .a("5 min"), .t(" alles terugzetten")]) {
                    draft.revertAfterMinutes = 5
                    done(.revert)
                }
                Text("De woninghub zet alle acties van deze flow na de gekozen tijd terug, bijvoorbeeld de lamp weer uit na beweging.")
                    .font(HomeyFont.tiny)
                    .foregroundStyle(Theme.textLight)
            default:
                EmptyView()
            }
        }
        .navigationTitle(app)
    }
}

private struct DeviceCardsList: View {
    let type: FlowCardType
    let device: Device
    @Binding var draft: FlowDraft
    let done: (FlowCardRef) -> Void

    var body: some View {
        List {
            switch type {
            case .when:
                ForEach(DeviceEventKind.options(for: device.kind), id: \.self) { event in
                    PickRow(parts: event.needsThreshold
                            ? [.t("\(device.kind == .humidity ? "Vochtigheid" : "Temperatuur") \(event.label) "), .a("…")]
                            : [.t(event.label.capitalizedFirst)]) {
                        var w = WhenCard(kind: .device)
                        w.deviceID = device.id
                        w.event = event
                        w.threshold = device.kind == .humidity ? 60 : 21
                        draft.when = w
                        done(.when)
                    }
                }
            case .and:
                ForEach([true, false], id: \.self) { on in
                    PickRow(parts: [.t("Is "), .a(on ? device.stateWords.on : device.stateWords.off)]) {
                        var card = AndCard(kind: .deviceState)
                        card.deviceID = device.id
                        card.deviceOn = on
                        draft.ands.append(card)
                        done(.and(card.id))
                    }
                }
            case .then:
                ForEach(actions.indices, id: \.self) { i in
                    let item = actions[i]
                    PickRow(parts: item.1) {
                        var step = ActionStep.defaults(for: device)
                        step.mode = item.2
                        step.value = item.3
                        draft.thens.append(step)
                        done(.then(step.id))
                    }
                }
            }
        }
        .navigationTitle(device.name)
    }

    private var actions: [(String, [CardText], ActionMode, Double)] {
        switch device.kind {
        case .light:
            var list: [(String, [CardText], ActionMode, Double)] = [
                ("on", [.t("Zet "), .a("aan")], .power, 1), ("off", [.t("Zet "), .a("uit")], .power, 0)
            ]
            if device.characteristic(HMCharacteristicTypeBrightness) != nil {
                list.append(("dim", [.t("Dim naar "), .a("…")], .brightness, 70))
            }
            return list
        case .lock:
            return [("lock", [.t("Doe "), .a("op slot")], .lock, 1), ("unlock", [.t("Doe "), .a("van het slot")], .lock, 0)]
        case .blinds, .window, .door:
            return [("open", [.t("Zet op "), .a("100% open")], .position, 100), ("close", [.t("Zet op "), .a("0% open")], .position, 0),
                    ("pos", [.t("Zet op "), .a("…")], .position, 50)]
        case .thermostat:
            return [("temp", [.t("Zet temperatuur op "), .a("…")], .temperature, device.targetTemperature ?? 20)]
        case .garage:
            return [("open", [.a("Openen")], .door, 1), ("close", [.a("Sluiten")], .door, 0)]
        default:
            return [("on", [.t("Zet "), .a("aan")], .power, 1), ("off", [.t("Zet "), .a("uit")], .power, 0)]
        }
    }
}
