import HomeKit
import SwiftUI

// MARK: ALS

enum WhenKind: String, Codable, CaseIterable {
    case device, time, sun, presence

    var title: String {
        switch self {
        case .device: return "Een apparaat"
        case .time: return "Een tijdstip"
        case .sun: return "De zon"
        case .presence: return "Aankomen of vertrekken"
        }
    }

    var symbol: String {
        switch self {
        case .device: return "lightbulb.fill"
        case .time: return "clock.fill"
        case .sun: return "sunset.fill"
        case .presence: return "figure.walk.arrival"
        }
    }
}

enum DeviceEventKind: String, Codable, CaseIterable {
    case turnsOn, turnsOff, opens, closes, motion, locked, unlocked, above, below

    var label: String {
        switch self {
        case .turnsOn: return "gaat aan"
        case .turnsOff: return "gaat uit"
        case .opens: return "gaat open"
        case .closes: return "gaat dicht"
        case .motion: return "ziet beweging"
        case .locked: return "gaat op slot"
        case .unlocked: return "gaat van het slot"
        case .above: return "komt boven"
        case .below: return "komt onder"
        }
    }

    var needsThreshold: Bool { self == .above || self == .below }

    static func options(for kind: DeviceKind) -> [DeviceEventKind] {
        switch kind {
        case .light, .outlet, .switchKind, .fan: return [.turnsOn, .turnsOff]
        case .lock: return [.locked, .unlocked]
        case .contact, .garage: return [.opens, .closes]
        case .motion: return [.motion]
        case .temperature, .humidity, .thermostat: return [.above, .below]
        case .blinds: return []
        }
    }
}

enum PresenceKind: String, Codable, CaseIterable {
    case anyoneArrives, firstArrives, anyoneLeaves, lastLeaves, iArrive, iLeave

    var label: String {
        switch self {
        case .anyoneArrives: return "Iemand komt thuis"
        case .firstArrives: return "De eerste komt thuis"
        case .anyoneLeaves: return "Iemand vertrekt"
        case .lastLeaves: return "De laatste vertrekt"
        case .iArrive: return "Ik kom thuis"
        case .iLeave: return "Ik vertrek"
        }
    }

    var eventType: HMPresenceEventType {
        switch self {
        case .anyoneArrives, .iArrive: return .everyEntry
        case .firstArrives: return .firstEntry
        case .anyoneLeaves, .iLeave: return .everyExit
        case .lastLeaves: return .lastExit
        }
    }

    var userType: HMPresenceEventUserType {
        switch self {
        case .iArrive, .iLeave: return .currentUser
        default: return .homeUsers
        }
    }
}

struct WhenCard: Codable, Hashable {
    var kind: WhenKind = .device
    var deviceID: UUID?
    var event: DeviceEventKind = .turnsOn
    var threshold: Double = 21
    var hour = 7
    var minute = 0
    /// 1 = zondag … 7 = zaterdag. Leeg = elke dag.
    var weekdays: Set<Int> = []
    var sunrise = false
    var offsetMinutes = 0
    var presence: PresenceKind = .anyoneArrives
}

// MARK: EN

enum AndKind: String, Codable, CaseIterable {
    case timeBetween, night, day, deviceState

    var title: String {
        switch self {
        case .timeBetween: return "Tussen twee tijden"
        case .night: return "Als het donker is"
        case .day: return "Als het licht is"
        case .deviceState: return "Een apparaat is aan of uit"
        }
    }

    var symbol: String {
        switch self {
        case .timeBetween: return "clock.badge.checkmark"
        case .night: return "moon.stars.fill"
        case .day: return "sun.max.fill"
        case .deviceState: return "switch.2"
        }
    }
}

struct AndCard: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: AndKind
    var fromHour = 22
    var fromMinute = 0
    var toHour = 6
    var toMinute = 0
    var deviceID: UUID?
    var deviceOn = true
}

// MARK: DAN

enum ActionMode: String, Codable {
    case power, brightness, temperature, lock, position, door, scene
}

struct ActionStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var mode: ActionMode = .power
    var deviceID: UUID?
    var sceneID: UUID?
    /// Aan/uit en open/dicht als 1/0, anders procent of graden.
    var value: Double = 1

    static func defaults(for device: Device) -> ActionStep {
        var step = ActionStep(deviceID: device.id)
        switch device.kind {
        case .lock: step.mode = .lock; step.value = 1
        case .blinds: step.mode = .position; step.value = 100
        case .thermostat: step.mode = .temperature; step.value = device.targetTemperature ?? 20
        case .garage: step.mode = .door; step.value = 0
        default: step.mode = .power; step.value = 1
        }
        return step
    }
}

// MARK: Flow

struct FlowDraft: Codable, Hashable {
    var name = ""
    var when = WhenCard()
    var ands: [AndCard] = []
    var thens: [ActionStep] = []
    /// Na zoveel minuten weer terug (0 = nooit).
    var revertAfterMinutes = 0
    var enabled = true
}

/// Welke apparaten welke rol kunnen spelen.
extension Device {
    var canTrigger: Bool { !DeviceEventKind.options(for: kind).isEmpty }
    var canBeControlled: Bool { isToggleable || kind == .thermostat }

    var hasStateCondition: Bool {
        switch kind {
        case .light, .outlet, .switchKind, .fan, .lock, .contact, .motion, .garage: return true
        default: return false
        }
    }

    /// Woorden voor "aan" en "uit" bij dit soort apparaat.
    var stateWords: (on: String, off: String) {
        switch kind {
        case .lock: return ("op slot", "van het slot")
        case .contact, .garage: return ("open", "dicht")
        case .motion: return ("ziet beweging", "ziet geen beweging")
        default: return ("aan", "uit")
        }
    }

    var thresholdUnit: String { kind == .humidity ? "%" : "°" }
}

// MARK: Beschrijvingen in gewone taal

@MainActor
extension FlowDraft {
    func whenText(_ home: HomeStore) -> String {
        switch when.kind {
        case .device:
            guard let id = when.deviceID, let device = home.device(id: id) else { return "Kies een apparaat" }
            if when.event.needsThreshold {
                return "\(device.name) \(when.event.label) \(when.threshold.oneDecimal)\(device.thresholdUnit)"
            }
            return "\(device.name) \(when.event.label)"
        case .time:
            let time = String(format: "%02d:%02d", when.hour, when.minute)
            if when.weekdays.isEmpty || when.weekdays.count == 7 { return "Elke dag om \(time)" }
            let symbols = Calendar.current.shortWeekdaySymbols
            let days = Weekdays.order.filter { when.weekdays.contains($0) }.map { symbols[$0 - 1] }
            return "Om \(time) op \(days.joined(separator: ", "))"
        case .sun:
            let base = when.sunrise ? "zonsopkomst" : "zonsondergang"
            if when.offsetMinutes == 0 { return "Bij \(base)" }
            let minutes = abs(when.offsetMinutes)
            return when.offsetMinutes < 0 ? "\(minutes) min voor \(base)" : "\(minutes) min na \(base)"
        case .presence:
            return when.presence.label
        }
    }

    func andText(_ card: AndCard, _ home: HomeStore) -> String {
        switch card.kind {
        case .timeBetween:
            return String(format: "Tussen %02d:%02d en %02d:%02d", card.fromHour, card.fromMinute, card.toHour, card.toMinute)
        case .night: return "Het is donker"
        case .day: return "Het is licht"
        case .deviceState:
            guard let id = card.deviceID, let device = home.device(id: id) else { return "Kies een apparaat" }
            let words = device.stateWords
            return "\(device.name) is \(card.deviceOn ? words.on : words.off)"
        }
    }

    static func actionText(_ step: ActionStep, _ home: HomeStore) -> String {
        if step.mode == .scene {
            return "Start \(home.scene(id: step.sceneID)?.name ?? "een sfeer")"
        }
        guard let id = step.deviceID, let device = home.device(id: id) else { return "Kies een apparaat" }
        switch step.mode {
        case .power: return "\(device.name) \(step.value > 0 ? "aan" : "uit")"
        case .brightness: return step.value > 0 ? "\(device.name) op \(Int(step.value))%" : "\(device.name) uit"
        case .temperature: return "\(device.name) naar \(step.value.oneDecimal)°"
        case .lock: return "\(device.name) \(step.value > 0 ? "op slot" : "van het slot")"
        case .position: return "\(device.name) \(Int(step.value))% open"
        case .door: return "\(device.name) \(step.value > 0 ? "openen" : "sluiten")"
        case .scene: return ""
        }
    }

    func summary(_ home: HomeStore) -> String {
        var text = "Als " + whenText(home).lowercasedFirst
        for card in ands { text += ", en " + andText(card, home).lowercasedFirst }
        let actions = thens.map { FlowDraft.actionText($0, home) }
        if !actions.isEmpty { text += " → " + actions.joined(separator: ", ") }
        if revertAfterMinutes > 0 { text += " (na \(revertAfterMinutes) min terug)" }
        return text
    }
}

enum Weekdays {
    /// Maandag eerst.
    static let order = [2, 3, 4, 5, 6, 7, 1]
}

extension String {
    var lowercasedFirst: String {
        guard let first else { return self }
        // Apparaatnamen houden hun hoofdletter.
        if first.isUppercase, dropFirst().first?.isUppercase == false,
           ["Elke", "Om", "Bij", "Tussen", "Het", "Iemand", "De", "Ik", "Kies", "Start"].contains(where: { hasPrefix($0 + " ") }) {
            return first.lowercased() + dropFirst()
        }
        return self
    }
}
