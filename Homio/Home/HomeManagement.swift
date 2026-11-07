import HomeKit
import SwiftUI

/// Gezondheid van één accessoire: bereikbaar, batterij, firmware.
struct AccessoryHealth: Identifiable {
    let accessory: HMAccessory
    var id: UUID { accessory.uniqueIdentifier }
    var name: String { accessory.name }
    var room: String { accessory.room?.name ?? "Standaardkamer" }
    var reachable: Bool { accessory.isReachable }
    let battery: Double?
    let lowBattery: Bool
    let charging: Bool

    var manufacturer: String? { accessory.manufacturer }
    var model: String? { accessory.model }
    var firmware: String? { accessory.firmwareVersion }

    var needsAttention: Bool { !reachable || lowBattery }

    var batterySymbol: String {
        if charging { return "battery.100percent.bolt" }
        guard let battery else { return lowBattery ? "battery.25percent" : "battery.100percent" }
        switch battery {
        case ..<15: return "battery.0percent"
        case ..<40: return "battery.25percent"
        case ..<65: return "battery.50percent"
        case ..<90: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}

/// Beheer en hulpjes bovenop HomeStore: namen, kamers, verwijderen, gezondheid, groepen.
extension HomeStore {

    // MARK: Gezondheid

    var health: [AccessoryHealth] {
        guard let home else { return [] }
        return home.accessories.map { accessory in
            var battery: Double?
            var low = false
            var charging = false
            for service in accessory.services {
                for c in service.characteristics {
                    let n = (c.value as? NSNumber)?.doubleValue
                    switch c.characteristicType {
                    case HMCharacteristicTypeBatteryLevel: if let n { battery = n }
                    case HMCharacteristicTypeStatusLowBattery: if (n ?? 0) != 0 { low = true }
                    case HMCharacteristicTypeChargingState: if (n ?? 0) == 1 { charging = true }
                    default: break
                    }
                }
            }
            if let b = battery, b <= 15 { low = true }
            return AccessoryHealth(accessory: accessory, battery: battery, lowBattery: low, charging: charging)
        }
        .sorted { lhs, rhs in
            if lhs.needsAttention != rhs.needsAttention { return lhs.needsAttention }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: Aan/uit zetten (ook voor groepen en Siri)

    func set(_ device: Device, on: Bool) {
        guard device.isToggleable, device.isOn != on else { return }
        toggle(device)
    }

    func setBrightness(_ device: Device, percent: Int) {
        guard device.kind == .light else { return }
        if percent <= 0 {
            write(device.characteristic(HMCharacteristicTypePowerState), false)
            return
        }
        if !device.isOn { write(device.characteristic(HMCharacteristicTypePowerState), true) }
        if let b = device.characteristic(HMCharacteristicTypeBrightness) {
            write(b, min(100, percent))
        }
    }

    func setColor(_ device: Device, hue: Double, saturation: Double) {
        if !device.isOn { write(device.characteristic(HMCharacteristicTypePowerState), true) }
        write(device.characteristic(HMCharacteristicTypeHue), NSNumber(value: Float(hue)))
        write(device.characteristic(HMCharacteristicTypeSaturation), NSNumber(value: Float(saturation)))
    }

    func setColorTemperature(_ device: Device, mireds: Int) {
        if !device.isOn { write(device.characteristic(HMCharacteristicTypePowerState), true) }
        write(device.characteristic(HMCharacteristicTypeColorTemperature), mireds)
    }

    // MARK: Namen en kamers

    var allRooms: [HMRoom] {
        guard let home else { return [] }
        return [home.roomForEntireHome()] + home.rooms
    }

    func rename(_ device: Device, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let interactive = device.accessory.services.filter(\.isUserInteractive)
        let completion: (Error?) -> Void = { [weak self] error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                self?.bump()
            }
        }
        if interactive.count <= 1 {
            device.accessory.updateName(trimmed, completionHandler: completion)
        } else {
            device.service.updateName(trimmed, completionHandler: completion)
        }
    }

    func move(_ device: Device, to room: HMRoom) {
        home?.assignAccessory(device.accessory, to: room) { [weak self] error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                self?.bump()
            }
        }
    }

    func remove(_ accessory: HMAccessory) {
        home?.removeAccessory(accessory) { [weak self] error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                self?.bump()
            }
        }
    }

    func addRoom(named name: String, then: ((HMRoom) -> Void)? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        home?.addRoom(withName: trimmed) { [weak self] room, error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                if let room { then?(room) }
                self?.bump()
            }
        }
    }

    func rename(_ room: HMRoom, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        room.updateName(trimmed) { [weak self] error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                self?.bump()
            }
        }
    }

    func remove(_ room: HMRoom) {
        home?.removeRoom(room) { [weak self] error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                self?.bump()
            }
        }
    }

    /// Wacht (hooguit 6 seconden) tot HomeKit is ingeladen; voor Siri en Opdrachten.
    func waitUntilReady() async {
        start()
        var waited = 0
        while !isReady && waited < 60 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }
    }
}
