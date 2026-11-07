import HomeKit
import SwiftUI

enum FlowError: LocalizedError {
    case noHome, missingDevice, unsupported, noActions

    var errorDescription: String? {
        switch self {
        case .noHome: return "Er is nog geen woning."
        case .missingDevice: return "Een gekozen apparaat bestaat niet meer."
        case .unsupported: return "Dit apparaat kan deze gebeurtenis niet melden."
        case .noActions: return "Voeg minstens één actie toe bij 'Dan'."
        }
    }
}

/// Bouwt flows en sferen om naar echte HomeKit-automatiseringen. Die draaien op je
/// woninghub (Apple TV of HomePod), dus ook als Homio dicht is.
@MainActor
final class FlowStore: ObservableObject {
    static let shared = FlowStore()

    /// Ontwerp per automatisering (sleutel: trigger-ID), zodat je hem later kunt bewerken.
    @Published private(set) var drafts: [String: FlowDraft] = [:]
    /// Actiegroepen die Homio voor flows heeft gemaakt; die tonen we niet als sfeer.
    @Published private(set) var ownedActionSetIDs: Set<String> = []
    @Published var lastError: String?

    private let key = "homio.flows.v1"

    private struct Stored: Codable {
        var drafts: [String: FlowDraft]
        var owned: Set<String>
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            drafts = stored.drafts
            ownedActionSetIDs = stored.owned
        }
        CloudSync.shared.register("flows", apply: { [weak self] data in
            guard let self, let remote = try? JSONDecoder().decode(Stored.self, from: data) else { return }
            self.drafts = remote.drafts
            self.ownedActionSetIDs = remote.owned
            if let local = try? JSONEncoder().encode(remote) {
                UserDefaults.standard.set(local, forKey: self.key)
            }
            HomeStore.shared.bump()
        }, current: { [weak self] in
            guard let self else { return nil }
            return try? JSONEncoder().encode(Stored(drafts: self.drafts, owned: self.ownedActionSetIDs))
        })
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(Stored(drafts: drafts, owned: ownedActionSetIDs)) {
            UserDefaults.standard.set(data, forKey: key)
            CloudSync.shared.push("flows", payload: data)
        }
    }

    private var store: HomeStore { HomeStore.shared }

    func draft(for trigger: HMTrigger) -> FlowDraft? {
        drafts[trigger.uniqueIdentifier.uuidString]
    }

    // MARK: Flows bewaren

    func save(_ input: FlowDraft, replacing old: HMTrigger?) async throws {
        guard let home = store.home else { throw FlowError.noHome }
        guard !input.thens.isEmpty else { throw FlowError.noActions }
        var draft = input
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.name = draft.whenText(store)
        }

        let events = try makeEvents(draft.when)
        let predicate = makePredicate(draft.ands)
        var recurrences: [DateComponents]?
        if draft.when.kind == .time, !draft.when.weekdays.isEmpty, draft.when.weekdays.count < 7 {
            recurrences = draft.when.weekdays.sorted().map { day in
                var c = DateComponents()
                c.weekday = day
                return c
            }
        }
        var endEvents: [HMEvent]?
        if draft.revertAfterMinutes > 0 {
            endEvents = [HMDurationEvent(duration: TimeInterval(draft.revertAfterMinutes * 60))]
        }

        if let old { try await delete(old) }

        let uniqueName = uniqueTriggerName(draft.name, in: home)
        let trigger = HMEventTrigger(name: uniqueName, events: events, end: endEvents,
                                     recurrences: recurrences, predicate: predicate)
        try await perform { home.addTrigger(trigger, completionHandler: $0) }

        do {
            let deviceSteps = draft.thens.filter { $0.mode != .scene }
            if !deviceSteps.isEmpty {
                let set = try await addActionSet(named: "Homio · \(uniqueName) · \(shortID())", in: home)
                ownedActionSetIDs.insert(set.uniqueIdentifier.uuidString)
                persist()
                try await addActions(for: deviceSteps, to: set)
                try await perform { trigger.addActionSet(set, completionHandler: $0) }
            }
            for step in draft.thens where step.mode == .scene {
                if let scene = store.scene(id: step.sceneID) {
                    try await perform { trigger.addActionSet(scene, completionHandler: $0) }
                }
            }
            try await perform { trigger.enable(draft.enabled, completionHandler: $0) }
        } catch {
            // Halve automatisering niet laten staan.
            try? await delete(trigger)
            throw error
        }

        draft.name = uniqueName
        drafts[trigger.uniqueIdentifier.uuidString] = draft
        persist()
        store.bump()
    }

    func delete(_ trigger: HMTrigger) async throws {
        guard let home = store.home else { throw FlowError.noHome }
        let owned = trigger.actionSets.filter { ownedActionSetIDs.contains($0.uniqueIdentifier.uuidString) }
        try await perform { home.removeTrigger(trigger, completionHandler: $0) }
        for set in owned {
            try? await perform { home.removeActionSet(set, completionHandler: $0) }
            ownedActionSetIDs.remove(set.uniqueIdentifier.uuidString)
        }
        drafts[trigger.uniqueIdentifier.uuidString] = nil
        persist()
        store.bump()
    }

    func setEnabled(_ trigger: HMTrigger, _ enabled: Bool) async {
        do {
            try await perform { trigger.enable(enabled, completionHandler: $0) }
            if var draft = drafts[trigger.uniqueIdentifier.uuidString] {
                draft.enabled = enabled
                drafts[trigger.uniqueIdentifier.uuidString] = draft
                persist()
            }
        } catch {
            lastError = error.localizedDescription
        }
        store.bump()
    }

    /// Voert de acties van een flow nu meteen uit.
    func run(_ trigger: HMTrigger) {
        for set in trigger.actionSets { store.run(set) }
    }

    // MARK: Sferen

    func saveScene(name: String, steps: [ActionStep], existing: HMActionSet?) async throws {
        guard let home = store.home else { throw FlowError.noHome }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let set: HMActionSet
        if let existing {
            set = existing
            if !trimmed.isEmpty, trimmed != existing.name {
                try await perform { existing.updateName(trimmed, completionHandler: $0) }
            }
            for action in existing.actions {
                try await perform { existing.removeAction(action, completionHandler: $0) }
            }
        } else {
            set = try await addActionSet(named: trimmed.isEmpty ? "Nieuwe sfeer" : trimmed, in: home)
        }
        try await addActions(for: steps.filter { $0.mode != .scene }, to: set)
        store.bump()
    }

    func deleteScene(_ scene: HMActionSet) async {
        guard let home = store.home else { return }
        do {
            try await perform { home.removeActionSet(scene, completionHandler: $0) }
        } catch {
            store.lastError = error.localizedDescription
        }
        store.bump()
    }

    /// Leest de acties van een bestaande sfeer terug als stappen.
    func steps(of scene: HMActionSet) -> [ActionStep] {
        var byService: [UUID: [String: Double]] = [:]
        for action in scene.actions {
            guard let write = action as? HMCharacteristicWriteAction<NSCopying>,
                  let serviceID = write.characteristic.service?.uniqueIdentifier,
                  let number = write.targetValue as? NSNumber else { continue }
            byService[serviceID, default: [:]][write.characteristic.characteristicType] = number.doubleValue
        }
        var steps: [ActionStep] = []
        for (serviceID, values) in byService {
            guard let device = store.device(id: serviceID) else { continue }
            var step = ActionStep.defaults(for: device)
            if let b = values[HMCharacteristicTypeBrightness] {
                step.mode = .brightness
                step.value = (values[HMCharacteristicTypePowerState] ?? 1) == 0 ? 0 : b
            } else if let p = values[HMCharacteristicTypePowerState] ?? values[HMCharacteristicTypeActive] {
                step.mode = .power
                step.value = p
            } else if let l = values[HMCharacteristicTypeTargetLockMechanismState] {
                step.mode = .lock
                step.value = l
            } else if let t = values[HMCharacteristicTypeTargetTemperature] {
                step.mode = .temperature
                step.value = t
            } else if let pos = values[HMCharacteristicTypeTargetPosition] {
                step.mode = .position
                step.value = pos
            } else if let door = values[HMCharacteristicTypeTargetDoorState] {
                step.mode = .door
                step.value = door == 0 ? 1 : 0
            }
            steps.append(step)
        }
        return steps.sorted { lhs, rhs in
            let a = store.device(id: lhs.deviceID ?? UUID())?.name ?? ""
            let b = store.device(id: rhs.deviceID ?? UUID())?.name ?? ""
            return a.localizedCompare(b) == .orderedAscending
        }
    }

    // MARK: Beschrijving van elke automatisering (ook die uit de Woning-app)

    func summary(for trigger: HMTrigger) -> String {
        if let draft = draft(for: trigger) { return draft.summary(store) }
        var when = "Automatisering"
        if let timer = trigger as? HMTimerTrigger {
            when = "Om \(timer.fireDate.formatted(date: .omitted, time: .shortened))"
        } else if let eventTrigger = trigger as? HMEventTrigger, let first = eventTrigger.events.first {
            when = describe(first)
        }
        let count = trigger.actionSets.reduce(0) { $0 + $1.actions.count }
        return "\(when) → \(count == 1 ? "1 actie" : "\(count) acties")"
    }

    private func describe(_ event: HMEvent) -> String {
        if let e = event as? HMSignificantTimeEvent {
            return e.significantEvent == .sunrise ? "Bij zonsopkomst" : "Bij zonsondergang"
        }
        if let e = event as? HMCalendarEvent {
            let c = e.fireDateComponents
            return String(format: "Om %02d:%02d", c.hour ?? 0, c.minute ?? 0)
        }
        if event is HMPresenceEvent { return "Bij aankomen of vertrekken" }
        if event is HMLocationEvent { return "Bij een locatie" }
        if let e = event as? HMCharacteristicThresholdRangeEvent {
            return "Als \(e.characteristic.service?.name ?? "een sensor") een grens passeert"
        }
        if let e = event as? HMCharacteristicEvent<NSCopying> {
            return "Als \(e.characteristic.service?.accessory?.name ?? "een apparaat") verandert"
        }
        return "Bij een gebeurtenis"
    }

    // MARK: Van ontwerp naar HomeKit

    private func makeEvents(_ when: WhenCard) throws -> [HMEvent] {
        switch when.kind {
        case .time:
            var c = DateComponents()
            c.hour = when.hour
            c.minute = when.minute
            return [HMCalendarEvent(fire: c)]
        case .sun:
            var offset = DateComponents()
            offset.minute = when.offsetMinutes
            return [HMSignificantTimeEvent(significantEvent: when.sunrise ? .sunrise : .sunset, offset: offset)]
        case .presence:
            return [HMPresenceEvent(presenceEventType: when.presence.eventType,
                                    presenceUserType: when.presence.userType)]
        case .device:
            guard let id = when.deviceID, let device = store.device(id: id) else { throw FlowError.missingDevice }
            guard let event = deviceEvent(device, when.event, threshold: when.threshold) else { throw FlowError.unsupported }
            return [event]
        }
    }

    private func deviceEvent(_ device: Device, _ kind: DeviceEventKind, threshold: Double) -> HMEvent? {
        switch kind {
        case .turnsOn, .turnsOff:
            let on = kind == .turnsOn
            if let power = device.characteristic(HMCharacteristicTypePowerState) {
                return HMCharacteristicEvent(characteristic: power, triggerValue: NSNumber(value: on))
            }
            if let active = device.characteristic(HMCharacteristicTypeActive) {
                return HMCharacteristicEvent(characteristic: active, triggerValue: NSNumber(value: on ? 1 : 0))
            }
            return nil
        case .locked, .unlocked:
            guard let c = device.characteristic(HMCharacteristicTypeCurrentLockMechanismState) else { return nil }
            return HMCharacteristicEvent(characteristic: c, triggerValue: NSNumber(value: kind == .locked ? 1 : 0))
        case .opens, .closes:
            let open = kind == .opens
            if let c = device.characteristic(HMCharacteristicTypeContactState) {
                return HMCharacteristicEvent(characteristic: c, triggerValue: NSNumber(value: open ? 1 : 0))
            }
            if let c = device.characteristic(HMCharacteristicTypeCurrentDoorState) {
                return HMCharacteristicEvent(characteristic: c, triggerValue: NSNumber(value: open ? 0 : 1))
            }
            return nil
        case .motion:
            guard let c = device.characteristic(HMCharacteristicTypeMotionDetected) else { return nil }
            return HMCharacteristicEvent(characteristic: c, triggerValue: NSNumber(value: true))
        case .above, .below:
            let type = device.kind == .humidity ? HMCharacteristicTypeCurrentRelativeHumidity : HMCharacteristicTypeCurrentTemperature
            guard let c = device.characteristic(type) else { return nil }
            let range = kind == .above
                ? HMNumberRange(minValue: NSNumber(value: threshold))
                : HMNumberRange(maxValue: NSNumber(value: threshold))
            return HMCharacteristicThresholdRangeEvent(characteristic: c, thresholdRange: range)
        }
    }

    private func makePredicate(_ ands: [AndCard]) -> NSPredicate? {
        var parts: [NSPredicate] = []
        for card in ands {
            switch card.kind {
            case .timeBetween:
                var from = DateComponents()
                from.hour = card.fromHour
                from.minute = card.fromMinute
                var to = DateComponents()
                to.hour = card.toHour
                to.minute = card.toMinute
                let crossesMidnight = (card.fromHour * 60 + card.fromMinute) > (card.toHour * 60 + card.toMinute)
                if crossesMidnight {
                    // Over middernacht heen: van 'van' tot 23:59, of van 00:00 tot 'tot'.
                    var endOfDay = DateComponents()
                    endOfDay.hour = 23
                    endOfDay.minute = 59
                    var startOfDay = DateComponents()
                    startOfDay.hour = 0
                    startOfDay.minute = 0
                    parts.append(NSCompoundPredicate(orPredicateWithSubpredicates: [
                        HMEventTrigger.predicateForEvaluatingTriggerOccurringBetweenDate(with: from, secondDateWith: endOfDay),
                        HMEventTrigger.predicateForEvaluatingTriggerOccurringBetweenDate(with: startOfDay, secondDateWith: to)
                    ]))
                } else {
                    parts.append(HMEventTrigger.predicateForEvaluatingTriggerOccurringBetweenDate(with: from, secondDateWith: to))
                }
            case .night:
                parts.append(HMEventTrigger.predicate(
                    forEvaluatingTriggerOccurringBetweenSignificantEvent: HMSignificantTimeEvent(significantEvent: .sunset, offset: nil),
                    secondSignificantEvent: HMSignificantTimeEvent(significantEvent: .sunrise, offset: nil)))
            case .day:
                parts.append(HMEventTrigger.predicate(
                    forEvaluatingTriggerOccurringBetweenSignificantEvent: HMSignificantTimeEvent(significantEvent: .sunrise, offset: nil),
                    secondSignificantEvent: HMSignificantTimeEvent(significantEvent: .sunset, offset: nil)))
            case .deviceState:
                guard let id = card.deviceID, let device = store.device(id: id),
                      let condition = stateCondition(device) else { continue }
                parts.append(HMEventTrigger.predicateForEvaluatingTrigger(
                    condition.characteristic, relatedBy: .equalTo,
                    toValue: card.deviceOn ? condition.on : condition.off))
            }
        }
        if parts.isEmpty { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }

    private func stateCondition(_ device: Device) -> (characteristic: HMCharacteristic, on: NSNumber, off: NSNumber)? {
        switch device.kind {
        case .light, .outlet, .switchKind:
            guard let c = device.characteristic(HMCharacteristicTypePowerState) else { return nil }
            return (c, NSNumber(value: true), NSNumber(value: false))
        case .fan:
            if let c = device.characteristic(HMCharacteristicTypePowerState) { return (c, NSNumber(value: true), NSNumber(value: false)) }
            guard let c = device.characteristic(HMCharacteristicTypeActive) else { return nil }
            return (c, NSNumber(value: 1), NSNumber(value: 0))
        case .lock:
            guard let c = device.characteristic(HMCharacteristicTypeCurrentLockMechanismState) else { return nil }
            return (c, NSNumber(value: 1), NSNumber(value: 0))
        case .contact:
            guard let c = device.characteristic(HMCharacteristicTypeContactState) else { return nil }
            return (c, NSNumber(value: 1), NSNumber(value: 0))
        case .motion:
            guard let c = device.characteristic(HMCharacteristicTypeMotionDetected) else { return nil }
            return (c, NSNumber(value: true), NSNumber(value: false))
        case .garage:
            guard let c = device.characteristic(HMCharacteristicTypeCurrentDoorState) else { return nil }
            return (c, NSNumber(value: 0), NSNumber(value: 1))
        default:
            return nil
        }
    }

    /// De HomeKit-schrijfacties voor één stap.
    func writeTargets(_ step: ActionStep) -> [(HMCharacteristic, NSNumber)] {
        guard let id = step.deviceID, let device = store.device(id: id) else { return [] }
        let power = device.characteristic(HMCharacteristicTypePowerState)
        switch step.mode {
        case .power:
            if let power { return [(power, NSNumber(value: step.value > 0))] }
            if let active = device.characteristic(HMCharacteristicTypeActive) {
                return [(active, NSNumber(value: step.value > 0 ? 1 : 0))]
            }
            return []
        case .brightness:
            var result: [(HMCharacteristic, NSNumber)] = []
            if let power { result.append((power, NSNumber(value: step.value > 0))) }
            if step.value > 0, let b = device.characteristic(HMCharacteristicTypeBrightness) {
                result.append((b, NSNumber(value: Int(step.value.rounded()))))
            }
            return result
        case .temperature:
            guard let c = device.characteristic(HMCharacteristicTypeTargetTemperature) else { return [] }
            return [(c, NSNumber(value: Float(step.value)))]
        case .lock:
            guard let c = device.characteristic(HMCharacteristicTypeTargetLockMechanismState) else { return [] }
            return [(c, NSNumber(value: step.value > 0 ? 1 : 0))]
        case .position:
            guard let c = device.characteristic(HMCharacteristicTypeTargetPosition) else { return [] }
            return [(c, NSNumber(value: Int(step.value.rounded())))]
        case .door:
            guard let c = device.characteristic(HMCharacteristicTypeTargetDoorState) else { return [] }
            return [(c, NSNumber(value: step.value > 0 ? 0 : 1))]
        case .scene:
            return []
        }
    }

    // MARK: HomeKit-hulpjes

    private func addActions(for steps: [ActionStep], to set: HMActionSet) async throws {
        // Eén actie per eigenschap: de laatste stap wint.
        var targets: [UUID: (HMCharacteristic, NSNumber)] = [:]
        var order: [UUID] = []
        for step in steps {
            for target in writeTargets(step) {
                let key = target.0.uniqueIdentifier
                if targets[key] == nil { order.append(key) }
                targets[key] = target
            }
        }
        for key in order {
            guard let target = targets[key] else { continue }
            let action = HMCharacteristicWriteAction(characteristic: target.0, targetValue: target.1)
            try await perform { set.addAction(action, completionHandler: $0) }
        }
    }

    private func addActionSet(named name: String, in home: HMHome) async throws -> HMActionSet {
        try await withCheckedThrowingContinuation { continuation in
            home.addActionSet(withName: name) { set, error in
                if let set {
                    continuation.resume(returning: set)
                } else {
                    continuation.resume(throwing: error ?? FlowError.noHome)
                }
            }
        }
    }

    private func perform(_ body: (@escaping (Error?) -> Void) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            body { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func uniqueTriggerName(_ name: String, in home: HMHome) -> String {
        let existing = Set(home.triggers.map(\.name))
        guard existing.contains(name) else { return name }
        var n = 2
        while existing.contains("\(name) \(n)") { n += 1 }
        return "\(name) \(n)"
    }

    private func shortID() -> String {
        String(UUID().uuidString.prefix(4))
    }
}
