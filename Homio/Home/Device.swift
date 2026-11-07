import HomeKit
import SwiftUI

enum DeviceKind: String {
    case light, outlet, switchKind, thermostat, lock, blinds, fan, garage
    case window, door, airPurifier, heaterCooler, humidifier, valve, security
    case temperature, humidity, contact, motion, occupancy, smoke, carbonMonoxide, leak, lux, airQuality
    /// Alleen via Matter: speaker, tv, robotstofzuiger, huishoudapparaat, energie, overige sensor.
    case speaker, tv, vacuum, appliance, energy, sensor

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
        case HMServiceTypeWindow: self = .window
        case HMServiceTypeDoor: self = .door
        case HMServiceTypeAirPurifier: self = .airPurifier
        case HMServiceTypeHeaterCooler: self = .heaterCooler
        case HMServiceTypeHumidifierDehumidifier: self = .humidifier
        case HMServiceTypeValve, HMServiceTypeFaucet, HMServiceTypeIrrigationSystem: self = .valve
        case HMServiceTypeSecuritySystem: self = .security
        case HMServiceTypeTemperatureSensor: self = .temperature
        case HMServiceTypeHumiditySensor: self = .humidity
        case HMServiceTypeContactSensor: self = .contact
        case HMServiceTypeMotionSensor: self = .motion
        case HMServiceTypeOccupancySensor: self = .occupancy
        case HMServiceTypeSmokeSensor: self = .smoke
        case HMServiceTypeCarbonMonoxideSensor, HMServiceTypeCarbonDioxideSensor: self = .carbonMonoxide
        case HMServiceTypeLeakSensor: self = .leak
        case HMServiceTypeLightSensor: self = .lux
        case HMServiceTypeAirQualitySensor: self = .airQuality
        default: return nil
        }
    }

    var isSensor: Bool {
        switch self {
        case .temperature, .humidity, .contact, .motion, .occupancy, .smoke, .carbonMonoxide, .leak, .lux, .airQuality, .sensor:
            return true
        default:
            return false
        }
    }

    /// Sensoren die alarm slaan (rode tegel).
    var isAlarm: Bool { [.smoke, .carbonMonoxide, .leak].contains(self) }

    /// Apparaten die via "Active" aan/uit gaan.
    var usesActive: Bool { [.airPurifier, .heaterCooler, .humidifier, .valve].contains(self) }

    /// Apparaten met een positie (0–100).
    var usesPosition: Bool { [.blinds, .window, .door].contains(self) }

    /// Accentkleur in de stijl van Homey.
    var tint: Color {
        switch self {
        case .light: return Color(red: 1.0, green: 0.71, blue: 0.0)
        case .outlet, .switchKind, .valve: return Theme.green
        case .thermostat, .heaterCooler: return Theme.orange
        case .lock, .security: return Theme.accent
        case .blinds, .window, .door: return .teal
        case .fan, .airPurifier, .humidifier: return .cyan
        case .garage: return .indigo
        case .smoke, .carbonMonoxide, .leak: return Theme.red
        case .motion, .occupancy, .contact: return Theme.accent
        case .temperature, .humidity, .lux, .airQuality, .sensor: return Theme.textLight
        case .speaker: return Theme.purple
        case .tv: return Theme.accent
        case .vacuum, .appliance: return Theme.green
        case .energy: return Theme.yellow
        }
    }

    /// Standaardicoon (asset) voor dit soort apparaat, wisselend met de stand.
    func iconName(isOn: Bool) -> String {
        let base: String
        switch self {
        case .light: base = isOn ? "light-on" : "light"
        case .outlet: base = "plug"
        case .switchKind: base = "switch"
        case .thermostat: base = "thermostat"
        case .lock: base = isOn ? "lock-closed" : "lock-open"
        case .blinds: base = isOn ? "blinds-open" : "blinds-closed"
        case .fan: base = "fan"
        case .garage: base = isOn ? "garage-open" : "garage-closed"
        case .window: base = "window"
        case .door: base = isOn ? "door-open" : "door-closed"
        case .airPurifier: base = "purifier"
        case .heaterCooler: base = "heater"
        case .humidifier: base = "humidifier"
        case .valve: base = "valve"
        case .security: base = "security"
        case .temperature: base = "thermometer"
        case .humidity: base = "humidity"
        case .contact: base = isOn ? "door-open" : "door-closed"
        case .motion: base = "motion"
        case .occupancy: base = "occupancy"
        case .smoke: base = "smoke"
        case .carbonMonoxide: base = "co"
        case .leak: base = "leak"
        case .lux: base = "lux"
        case .airQuality: base = "air"
        case .speaker: base = "speaker"
        case .tv: base = "tv"
        case .vacuum: base = "vacuum"
        case .appliance: base = "appliance"
        case .energy: base = "energy"
        case .sensor: base = "sensor"
        }
        return "dev-" + base
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
        case .window, .door:
            return (position ?? 0) > 0
        case .airPurifier, .heaterCooler, .humidifier, .valve:
            return flag(HMCharacteristicTypeActive)
        case .security:
            return (number(HMCharacteristicTypeCurrentSecuritySystemState) ?? 3) != 3
        case .contact:
            return number(HMCharacteristicTypeContactState) == 1
        case .motion:
            return flag(HMCharacteristicTypeMotionDetected)
        case .occupancy:
            return flag(HMCharacteristicTypeOccupancyDetected)
        case .smoke:
            return flag(HMCharacteristicTypeSmokeDetected)
        case .carbonMonoxide:
            return flag(HMCharacteristicTypeCarbonMonoxideDetected) || flag(HMCharacteristicTypeCarbonDioxideDetected)
        case .leak:
            return flag(HMCharacteristicTypeLeakDetected)
        case .temperature, .humidity, .lux, .airQuality, .speaker, .tv, .vacuum, .appliance, .energy, .sensor:
            return false
        }
    }

    /// Batterij bijna leeg (op welke dienst van het accessoire dan ook).
    var lowBattery: Bool {
        accessory.services.contains { service in
            service.characteristics.contains {
                $0.characteristicType == HMCharacteristicTypeStatusLowBattery && (($0.value as? NSNumber)?.intValue ?? 0) == 1
            }
        }
    }

    /// Naam van het eigen vector-icoon in de asset catalog.
    var iconName: String { kind.iconName(isOn: isOn) }

    var isToggleable: Bool {
        switch kind {
        case .light, .outlet, .switchKind, .fan, .lock, .blinds, .garage,
             .window, .door, .airPurifier, .heaterCooler, .humidifier, .valve: return true
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
        case .window: return "window.vertical.open"
        case .door: return isOn ? "door.left.hand.open" : "door.left.hand.closed"
        case .airPurifier: return "air.purifier.fill"
        case .heaterCooler: return "heater.vertical.fill"
        case .humidifier: return "humidifier.fill"
        case .valve: return "spigot.fill"
        case .security: return "checkmark.shield.fill"
        case .occupancy: return "person.fill"
        case .smoke: return "smoke.fill"
        case .carbonMonoxide: return "carbon.monoxide.cloud.fill"
        case .leak: return "drop.triangle.fill"
        case .lux: return "sun.max.fill"
        case .airQuality: return "aqi.medium"
        case .speaker: return "hifispeaker.fill"
        case .tv: return "tv.fill"
        case .vacuum: return "circle.circle.fill"
        case .appliance: return "washer.fill"
        case .energy: return "bolt.fill"
        case .sensor: return "sensor.fill"
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
        case .blinds, .window, .door:
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
        case .airPurifier, .humidifier, .valve:
            return isOn ? "Aan" : "Uit"
        case .heaterCooler:
            let current = currentTemperature.map { "\($0.oneDecimal)°" } ?? "–"
            return isOn ? "Aan · \(current)" : "Uit · \(current)"
        case .security:
            switch Int(number(HMCharacteristicTypeCurrentSecuritySystemState) ?? 3) {
            case 0: return "Thuis"
            case 1: return "Afwezig"
            case 2: return "Nacht"
            case 4: return "Alarm!"
            default: return "Uitgeschakeld"
            }
        case .occupancy:
            return isOn ? "Aanwezig" : "Niemand"
        case .smoke:
            return isOn ? "Rook!" : "Geen rook"
        case .carbonMonoxide:
            return isOn ? "Gas gemeten!" : "Veilig"
        case .leak:
            return isOn ? "Lekkage!" : "Droog"
        case .lux:
            return number(HMCharacteristicTypeCurrentLightLevel).map { "\(Int($0)) lux" } ?? "–"
        case .airQuality:
            switch Int(number(HMCharacteristicTypeAirQuality) ?? 0) {
            case 1: return "Uitstekend"
            case 2: return "Goed"
            case 3: return "Redelijk"
            case 4: return "Matig"
            case 5: return "Slecht"
            default: return "Onbekend"
            }
        case .speaker, .tv, .vacuum, .appliance, .energy, .sensor:
            return isReachable ? "Bereikbaar" : "Geen reactie"
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
