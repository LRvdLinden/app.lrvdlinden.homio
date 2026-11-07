import HomeKit
import SwiftUI

enum DeviceKind: String {
    case light, outlet, switchKind, thermostat, lock, blinds, fan, garage
    case temperature, humidity, contact, motion

    init?(serviceType: String) {
        switch serviceType {
        case HMServiceTypeLightbulb: self = .light
        case HMServiceTypeOutlet: self = .outlet
        case HMServiceTypeSwitch: self = .switchKind
        case HMServiceTypeThermostat: self = .thermostat
        case HMServiceTypeLockMechanism: self = .lock
        case HMServiceTypeWindowCovering: self = .blinds
        case HMServiceTypeFan: self = .fan
        case HMServiceTypeGarageDoorOpener: self = .garage
        case HMServiceTypeTemperatureSensor: self = .temperature
        case HMServiceTypeHumiditySensor: self = .humidity
        case HMServiceTypeContactSensor: self = .contact
        case HMServiceTypeMotionSensor: self = .motion
        default: return nil
        }
    }

    var isSensor: Bool {
        switch self {
        case .temperature, .humidity, .contact, .motion: return true
        default: return false
        }
    }

    var tint: Color {
        switch self {
        case .light: return Theme.amber
        case .outlet, .switchKind: return .green
        case .thermostat: return .orange
        case .lock: return .blue
        case .blinds: return .teal
        case .fan: return .cyan
        case .garage: return .indigo
        case .temperature, .humidity, .contact, .motion: return .white
        }
    }
}

/// Eén bedienbare dienst van een accessoire (een lamp, een stekker, een slot ...).
struct Device: Identifiable {
    let service: HMService
    let accessory: HMAccessory
    let kind: DeviceKind

    var id: UUID { service.uniqueIdentifier }
    var name: String { service.name.isEmpty ? accessory.name : service.name }
    var roomName: String { accessory.room?.name ?? "Standaardkamer" }
    var isReachable: Bool { accessory.isReachable }
    var tint: Color { kind.tint }

    func characteristic(_ type: String) -> HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == type }
    }

    func number(_ type: String) -> Double? {
        (characteristic(type)?.value as? NSNumber)?.doubleValue
    }

    func flag(_ type: String) -> Bool {
        (number(type) ?? 0) != 0
    }

    var brightness: Double? { number(HMCharacteristicTypeBrightness) }
    var currentTemperature: Double? { number(HMCharacteristicTypeCurrentTemperature) }
    var targetTemperature: Double? { number(HMCharacteristicTypeTargetTemperature) }
    var position: Double? { number(HMCharacteristicTypeCurrentPosition) }

    /// "Aan" in de breedste zin: lamp aan, slot op slot, gordijn open, deur open.
    var isOn: Bool {
        switch kind {
        case .light, .outlet, .switchKind:
            return flag(HMCharacteristicTypePowerState)
        case .fan:
            if characteristic(HMCharacteristicTypeActive) != nil { return flag(HMCharacteristicTypeActive) }
            return flag(HMCharacteristicTypePowerState)
        case .lock:
            return number(HMCharacteristicTypeCurrentLockMechanismState) == 1
        case .blinds:
            return (position ?? 0) > 0
        case .garage:
            return number(HMCharacteristicTypeCurrentDoorState) == 0
        case .thermostat:
            return (number(HMCharacteristicTypeTargetHeatingCooling) ?? 0) != 0
        case .contact:
            return number(HMCharacteristicTypeContactState) == 1
        case .motion:
            return flag(HMCharacteristicTypeMotionDetected)
        case .temperature, .humidity:
            return false
        }
    }

    var isToggleable: Bool {
        switch kind {
        case .light, .outlet, .switchKind, .fan, .lock, .blinds, .garage: return true
        default: return false
        }
    }

    var symbol: String {
        switch kind {
        case .light: return isOn ? "lightbulb.fill" : "lightbulb"
        case .outlet: return "poweroutlet.type.f.fill"
        case .switchKind: return "switch.2"
        case .thermostat: return "thermometer.medium"
        case .lock: return isOn ? "lock.fill" : "lock.open.fill"
        case .blinds: return isOn ? "blinds.horizontal.open" : "blinds.horizontal.closed"
        case .fan: return "fan.fill"
        case .garage: return isOn ? "door.garage.open" : "door.garage.closed"
        case .temperature: return "thermometer.medium"
        case .humidity: return "humidity.fill"
        case .contact: return isOn ? "door.left.hand.open" : "door.left.hand.closed"
        case .motion: return "figure.walk.motion"
        }
    }

    var stateText: String {
        guard isReachable else { return "Geen reactie" }
        switch kind {
        case .light:
            guard isOn else { return "Uit" }
            if let b = brightness { return "\(Int(b))%" }
            return "Aan"
        case .outlet, .switchKind, .fan:
            return isOn ? "Aan" : "Uit"
        case .thermostat:
            let current = currentTemperature.map { "\($0.oneDecimal)°" } ?? "–"
            if isOn, let target = targetTemperature { return "\(current) → \(target.oneDecimal)°" }
            return isOn ? current : "Uit · \(current)"
        case .lock:
            switch Int(number(HMCharacteristicTypeCurrentLockMechanismState) ?? 3) {
            case 1: return "Op slot"
            case 0: return "Open"
            case 2: return "Klemt"
            default: return "Onbekend"
            }
        case .blinds:
            let p = Int(position ?? 0)
            if p <= 0 { return "Gesloten" }
            if p >= 100 { return "Open" }
            return "\(p)% open"
        case .garage:
            switch Int(number(HMCharacteristicTypeCurrentDoorState) ?? 4) {
            case 0: return "Open"
            case 1: return "Dicht"
            case 2: return "Gaat open"
            case 3: return "Gaat dicht"
            default: return "Gestopt"
            }
        case .temperature:
            return currentTemperature.map { "\($0.oneDecimal)°" } ?? "–"
        case .humidity:
            return number(HMCharacteristicTypeCurrentRelativeHumidity).map { "\(Int($0))%" } ?? "–"
        case .contact:
            return isOn ? "Open" : "Dicht"
        case .motion:
            return isOn ? "Beweging" : "Geen beweging"
        }
    }
}

struct RoomGroup: Identifiable {
    let name: String
    let devices: [Device]
    var id: String { name }
}

extension HMActionSet {
    var symbol: String {
        switch actionSetType {
        case HMActionSetTypeWakeUp: return "sun.horizon.fill"
        case HMActionSetTypeSleep: return "moon.fill"
        case HMActionSetTypeHomeDeparture: return "figure.walk.departure"
        case HMActionSetTypeHomeArrival: return "house.fill"
        default: return "sparkles"
        }
    }

    var isBuiltIn: Bool { actionSetType != HMActionSetTypeUserDefined }
}
