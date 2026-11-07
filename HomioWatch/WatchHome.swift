import HomeKit
import SwiftUI

/// Eén bedienbaar onderdeel van een accessoire, voor op de Watch.
struct WatchDevice: Identifiable {
    enum Kind {
        case light, outlet, switchKind, fan, lock, blinds, thermostat, garage, temperature, humidity, contact, motion
    }

    let service: HMService
    let accessory: HMAccessory
    let kind: Kind

    var id: UUID { service.uniqueIdentifier }
    var name: String { service.name.isEmpty ? accessory.name : service.name }
    var room: String { accessory.room?.name ?? "Standaardkamer" }
    var isReachable: Bool { accessory.isReachable }

    init?(service: HMService, accessory: HMAccessory) {
        let kind: Kind
        switch service.serviceType {
        case HMServiceTypeLightbulb: kind = .light
        case HMServiceTypeOutlet: kind = .outlet
        case HMServiceTypeSwitch: kind = .switchKind
        case HMServiceTypeFan: kind = .fan
        case HMServiceTypeLockMechanism: kind = .lock
        case HMServiceTypeWindowCovering: kind = .blinds
        case HMServiceTypeThermostat: kind = .thermostat
        case HMServiceTypeGarageDoorOpener: kind = .garage
        case HMServiceTypeTemperatureSensor: kind = .temperature
        case HMServiceTypeHumiditySensor: kind = .humidity
        case HMServiceTypeContactSensor: kind = .contact
        case HMServiceTypeMotionSensor: kind = .motion
        default: return nil
        }
        self.service = service
        self.accessory = accessory
        self.kind = kind
    }

    func characteristic(_ type: String) -> HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == type }
    }

    func number(_ type: String) -> Double? {
        (characteristic(type)?.value as? NSNumber)?.doubleValue
    }

    var isToggleable: Bool {
        switch kind {
        case .light, .outlet, .switchKind, .fan, .lock, .blinds, .garage: return true
        default: return false
        }
    }

    var isOn: Bool {
        switch kind {
        case .light, .outlet, .switchKind:
            return (number(HMCharacteristicTypePowerState) ?? 0) != 0
        case .fan:
            if characteristic(HMCharacteristicTypeActive) != nil { return (number(HMCharacteristicTypeActive) ?? 0) != 0 }
            return (number(HMCharacteristicTypePowerState) ?? 0) != 0
        case .lock: return number(HMCharacteristicTypeCurrentLockMechanismState) == 1
        case .blinds: return (number(HMCharacteristicTypeCurrentPosition) ?? 0) > 0
        case .garage: return number(HMCharacteristicTypeCurrentDoorState) == 0
        case .thermostat: return (number(HMCharacteristicTypeTargetHeatingCooling) ?? 0) != 0
        case .contact: return number(HMCharacteristicTypeContactState) == 1
        case .motion: return (number(HMCharacteristicTypeMotionDetected) ?? 0) != 0
        case .temperature, .humidity: return false
        }
    }

    var hasDetail: Bool {
        switch kind {
        case .light: return characteristic(HMCharacteristicTypeBrightness) != nil
        case .blinds, .thermostat: return true
        default: return false
        }
    }

    var symbol: String {
        switch kind {
        case .light: return isOn ? "lightbulb.fill" : "lightbulb"
        case .outlet: return "poweroutlet.type.f.fill"
        case .switchKind: return "switch.2"
        case .fan: return "fan.fill"
        case .lock: return isOn ? "lock.fill" : "lock.open.fill"
        case .blinds: return isOn ? "blinds.horizontal.open" : "blinds.horizontal.closed"
        case .thermostat: return "thermometer.medium"
        case .garage: return isOn ? "door.garage.open" : "door.garage.closed"
        case .temperature: return "thermometer.medium"
        case .humidity: return "humidity.fill"
        case .contact: return isOn ? "door.left.hand.open" : "door.left.hand.closed"
        case .motion: return "figure.walk.motion"
        }
    }

    var tint: Color {
        switch kind {
        case .light: return WatchPalette.yellow
        case .lock: return WatchPalette.blue
        case .thermostat: return WatchPalette.orange
        case .blinds: return .teal
        default: return .green
        }
    }

    var stateText: String {
        guard isReachable else { return "Geen reactie" }
        switch kind {
        case .light:
            guard isOn else { return "Uit" }
            if let b = number(HMCharacteristicTypeBrightness) { return "\(Int(b))%" }
            return "Aan"
        case .outlet, .switchKind, .fan: return isOn ? "Aan" : "Uit"
        case .lock: return isOn ? "Op slot" : "Open"
        case .blinds:
            let p = Int(number(HMCharacteristicTypeCurrentPosition) ?? 0)
            return p <= 0 ? "Dicht" : (p >= 100 ? "Open" : "\(p)% open")
        case .garage: return isOn ? "Open" : "Dicht"
        case .thermostat:
            let now = number(HMCharacteristicTypeCurrentTemperature).map { String(format: "%.1f°", $0) } ?? "–"
            if let target = number(HMCharacteristicTypeTargetTemperature) {
                return "\(now) → \(String(format: "%.1f°", target))"
            }
            return now
        case .temperature:
            return number(HMCharacteristicTypeCurrentTemperature).map { String(format: "%.1f°", $0) } ?? "–"
        case .humidity:
            return number(HMCharacteristicTypeCurrentRelativeHumidity).map { "\(Int($0))%" } ?? "–"
        case .contact: return isOn ? "Open" : "Dicht"
        case .motion: return isOn ? "Beweging" : "Rustig"
        }
    }
}

/// HomeKit op de Watch.
@MainActor
final class WatchHome: NSObject, ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var revision = 0
    @Published var lastError: String?

    private var manager: HMHomeManager?
    private var observed = Set<UUID>()

    override init() {
        super.init()
        let m = HMHomeManager()
        m.delegate = self
        manager = m
    }

    var home: HMHome? { manager?.homes.first { $0.isPrimary } ?? manager?.homes.first }

    var devices: [WatchDevice] {
        guard let home else { return [] }
        var result: [WatchDevice] = []
        for accessory in home.accessories {
            for service in accessory.services where service.isUserInteractive {
                if let device = WatchDevice(service: service, accessory: accessory) { result.append(device) }
            }
        }
        return result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var rooms: [String] {
        let order = home?.rooms.map(\.name) ?? []
        let names = Set(devices.map(\.room))
        return names.sorted { (order.firstIndex(of: $0) ?? Int.max) < (order.firstIndex(of: $1) ?? Int.max) }
    }

    func devices(in room: String) -> [WatchDevice] {
        devices.filter { $0.room == room }
    }

    func device(id: UUID) -> WatchDevice? {
        devices.first { $0.id == id }
    }

    var scenes: [HMActionSet] {
        (home?.actionSets ?? [])
            .filter { $0.actionSetType != HMActionSetTypeTriggerOwned && !$0.name.hasPrefix("Homio · ") }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var triggers: [HMTrigger] {
        (home?.triggers ?? []).sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var lightsOn: Int { devices.filter { $0.kind == .light && $0.isOn }.count }

    var indoorTemperature: Double? {
        let temps = devices.compactMap { d -> Double? in
            guard d.kind == .temperature || d.kind == .thermostat else { return nil }
            return d.number(HMCharacteristicTypeCurrentTemperature)
        }
        return temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)
    }

    fileprivate func reload() {
        for home in manager?.homes ?? [] {
            for accessory in home.accessories {
                accessory.delegate = self
                guard !observed.contains(accessory.uniqueIdentifier) else { continue }
                observed.insert(accessory.uniqueIdentifier)
                for service in accessory.services {
                    for c in service.characteristics {
                        if c.properties.contains(HMCharacteristicPropertySupportsEventNotification) {
                            c.enableNotification(true) { _ in }
                        }
                        if c.properties.contains(HMCharacteristicPropertyReadable) {
                            c.readValue { [weak self] _ in
                                Task { @MainActor in self?.revision &+= 1 }
                            }
                        }
                    }
                }
            }
        }
        isReady = true
        revision &+= 1
    }

    // MARK: Bedienen

    func toggle(_ d: WatchDevice) {
        switch d.kind {
        case .light, .outlet, .switchKind:
            write(d.characteristic(HMCharacteristicTypePowerState), !d.isOn)
        case .fan:
            if let active = d.characteristic(HMCharacteristicTypeActive) {
                write(active, d.isOn ? 0 : 1)
            } else {
                write(d.characteristic(HMCharacteristicTypePowerState), !d.isOn)
            }
        case .lock:
            write(d.characteristic(HMCharacteristicTypeTargetLockMechanismState), d.isOn ? 0 : 1)
        case .blinds:
            write(d.characteristic(HMCharacteristicTypeTargetPosition), d.isOn ? 0 : 100)
        case .garage:
            write(d.characteristic(HMCharacteristicTypeTargetDoorState), d.isOn ? 1 : 0)
        case .thermostat:
            write(d.characteristic(HMCharacteristicTypeTargetHeatingCooling), d.isOn ? 0 : 1)
        default:
            break
        }
    }

    func write(_ characteristic: HMCharacteristic?, _ value: Any) {
        guard let characteristic else { return }
        characteristic.writeValue(value) { [weak self] error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                self?.revision &+= 1
            }
        }
    }

    func run(_ scene: HMActionSet) {
        home?.executeActionSet(scene) { [weak self] error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                self?.revision &+= 1
            }
        }
    }

}

extension WatchHome: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in self.reload() }
    }
}

extension WatchHome: HMAccessoryDelegate {
    nonisolated func accessory(_ accessory: HMAccessory, service: HMService,
                               didUpdateValueFor characteristic: HMCharacteristic) {
        Task { @MainActor in self.revision &+= 1 }
    }

    nonisolated func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        Task { @MainActor in self.revision &+= 1 }
    }
}
