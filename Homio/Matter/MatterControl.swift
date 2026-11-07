import Foundation
import SwiftUI

/// De huidige stand van een Matter-eindpunt, gelezen uit de cache van de node.
struct MatterState {
    var reachable = false
    var hasOnOff = false
    var on = false
    var brightness: Double?          // 0–100
    var colorTempMireds: Double?
    var hue: Double?                 // 0–360
    var saturation: Double?          // 0–1
    var lockState: Int?              // 0 niet helemaal, 1 op slot, 2 open, 3 ontgrendeld
    var openPercent: Double?         // 0 = dicht, 100 = open (Homio-volgorde)
    var temperature: Double?         // °C
    var targetTemperature: Double?   // °C
    var systemMode: Int?
    var humidity: Double?            // %
    var lux: Double?
    var occupied: Bool?
    var booleanState: Bool?
    var smoke: Int?
    var co: Int?
    var airQuality: Int?
    var fanPercent: Double?
    var fanMode: Int?
    var valveOpen: Bool?
    var operationalState: Int?
    var powerW: Double?
    var batteryPercent: Double?
    var batteryLevel: Int?           // 0 ok, 1 laag, 2 kritiek

    var lowBattery: Bool { (batteryLevel ?? 0) >= 1 || (batteryPercent ?? 100) <= 15 }
}

extension MatterStore {
    func state(_ e: MatterEndpoint) -> MatterState {
        _ = revision
        var s = MatterState()
        guard let node = node(e.nodeID) else { return s }
        let ep = e.endpoint
        s.reachable = node.state != .unreachable
        if let on = node.value(ep, MC.onOff, 0) as? NSNumber {
            s.hasOnOff = true
            s.on = on.boolValue
        }
        if let level = node.number(ep, MC.level, 0) { s.brightness = (level / 254 * 100).rounded() }
        s.colorTempMireds = node.number(ep, MC.color, 0x0007)
        if let h = node.number(ep, MC.color, 0x0000) { s.hue = h / 254 * 360 }
        if let sat = node.number(ep, MC.color, 0x0001) { s.saturation = sat / 254 }
        s.lockState = (node.value(ep, MC.doorLock, 0) as? NSNumber)?.intValue
        if let closed = node.number(ep, MC.windowCovering, 0x000E) { s.openPercent = max(0, min(100, 100 - closed / 100)) }
        if let t = node.number(ep, MC.thermostat, 0x0000) { s.temperature = t / 100 }
        else if let t = node.number(ep, MC.temperature, 0) { s.temperature = t / 100 }
        if let heat = node.number(ep, MC.thermostat, 0x0012) { s.targetTemperature = heat / 100 }
        s.systemMode = (node.value(ep, MC.thermostat, 0x001C) as? NSNumber)?.intValue
        if let h = node.number(ep, MC.humidity, 0) { s.humidity = h / 100 }
        if let l = node.number(ep, MC.illuminance, 0) { s.lux = l <= 0 ? 0 : pow(10, (l - 1) / 10_000) }
        if let o = node.value(ep, MC.occupancy, 0) as? NSNumber { s.occupied = (o.intValue & 1) == 1 }
        s.booleanState = (node.value(ep, MC.booleanState, 0) as? NSNumber)?.boolValue
        s.smoke = (node.value(ep, MC.smokeCO, 0x0001) as? NSNumber)?.intValue
        s.co = (node.value(ep, MC.smokeCO, 0x0002) as? NSNumber)?.intValue
        s.airQuality = (node.value(ep, MC.airQuality, 0) as? NSNumber)?.intValue
        s.fanPercent = node.number(ep, MC.fan, 0x0003) ?? node.number(ep, MC.fan, 0x0002)
        s.fanMode = (node.value(ep, MC.fan, 0x0000) as? NSNumber)?.intValue
        if let v = node.value(ep, MC.valve, 0x0004) as? NSNumber { s.valveOpen = v.intValue == 1 }
        s.operationalState = (node.value(ep, MC.opState, 0x0004) as? NSNumber
                              ?? node.value(ep, MC.rvcOpState, 0x0004) as? NSNumber)?.intValue
        if let mW = node.number(ep, MC.elecPower, 0x0008) { s.powerW = mW / 1000 }
        // Batterij zit soms op een ander eindpunt (vaak 0 of 1).
        for candidate in [ep, 0, 1] {
            if let pct = node.number(candidate, MC.powerSource, 0x000C) { s.batteryPercent = pct / 2 }
            if let lvl = node.value(candidate, MC.powerSource, 0x000E) as? NSNumber { s.batteryLevel = lvl.intValue }
            if s.batteryPercent != nil || s.batteryLevel != nil { break }
        }
        return s
    }

    /// "Aan" in de breedste zin, net als bij HomeKit-apparaten.
    func isOn(_ e: MatterEndpoint, _ s: MatterState) -> Bool {
        switch e.kind {
        case .lock: return s.lockState == 1
        case .blinds: return (s.openPercent ?? 0) > 0
        case .thermostat: return s.hasOnOff ? s.on : (s.systemMode ?? 0) != 0
        case .heaterCooler: return s.hasOnOff ? s.on : (s.systemMode ?? 0) != 0
        case .fan, .airPurifier: return s.hasOnOff ? s.on : ((s.fanMode ?? 0) != 0 || (s.fanPercent ?? 0) > 0)
        case .valve: return s.valveOpen ?? s.on
        case .contact: return s.booleanState == false          // geen contact = open
        case .leak: return s.booleanState == true
        case .smoke: return (s.smoke ?? 0) > 0 || (s.co ?? 0) > 0
        case .occupancy, .motion: return s.occupied == true
        case .vacuum, .appliance: return s.operationalState == 1
        default: return s.on
        }
    }

    func isToggleable(_ e: MatterEndpoint, _ s: MatterState) -> Bool {
        switch e.kind {
        case .lock: return s.lockState != nil
        case .blinds: return s.openPercent != nil
        case .thermostat, .heaterCooler: return s.hasOnOff || s.systemMode != nil
        case .fan, .airPurifier: return s.hasOnOff || s.fanMode != nil
        case .valve: return s.valveOpen != nil || s.hasOnOff
        case .vacuum: return s.operationalState != nil
        default: return !e.kind.isSensor && s.hasOnOff
        }
    }

    func stateText(_ e: MatterEndpoint, _ s: MatterState) -> String {
        guard s.reachable else { return "Geen reactie" }
        let on = isOn(e, s)
        switch e.kind {
        case .light:
            guard on else { return "Uit" }
            return s.brightness.map { "\(Int($0))%" } ?? "Aan"
        case .lock:
            switch s.lockState {
            case 1: return "Op slot"
            case 2, 3: return "Open"
            case 0: return "Klemt"
            default: return "Onbekend"
            }
        case .blinds:
            let p = Int(s.openPercent ?? 0)
            return p <= 0 ? "Gesloten" : (p >= 100 ? "Open" : "\(p)% open")
        case .thermostat, .heaterCooler, .temperature:
            let t = s.temperature.map { "\($0.oneDecimal)°" } ?? "–"
            if e.kind == .temperature { return t }
            return on ? (s.targetTemperature.map { "\(t) → \($0.oneDecimal)°" } ?? t) : "Uit · \(t)"
        case .humidity: return s.humidity.map { "\(Int($0))%" } ?? "–"
        case .lux: return s.lux.map { "\(Int($0)) lux" } ?? "–"
        case .occupancy, .motion: return on ? "Aanwezig" : "Niemand"
        case .contact: return on ? "Open" : "Dicht"
        case .leak: return on ? "Lekkage!" : "Droog"
        case .smoke:
            if (s.smoke ?? 0) > 0 { return "Rook!" }
            if (s.co ?? 0) > 0 { return "CO gemeten!" }
            return "Veilig"
        case .airQuality:
            switch s.airQuality {
            case 1: return "Goed"
            case 2: return "Redelijk"
            case 3: return "Matig"
            case 4: return "Slecht"
            case 5: return "Zeer slecht"
            case 6: return "Extreem slecht"
            default: return "Onbekend"
            }
        case .vacuum, .appliance:
            switch s.operationalState {
            case 0: return "Gestopt"
            case 1: return "Bezig"
            case 2: return "Gepauzeerd"
            case 3: return "Storing"
            case 0x40: return "Zoekt dock"
            case 0x41: return "Laadt op"
            case 0x42: return "In dock"
            default: return s.hasOnOff ? (on ? "Aan" : "Uit") : "Bereikbaar"
            }
        case .energy:
            return s.powerW.map { "\(Int($0)) W" } ?? (on ? "Aan" : "Bereikbaar")
        case .valve: return on ? "Open" : "Dicht"
        default:
            if s.hasOnOff { return on ? "Aan" : "Uit" }
            return "Bereikbaar"
        }
    }

    func indicator(_ e: MatterEndpoint, _ s: MatterState) -> String? {
        let on = isOn(e, s)
        switch e.kind {
        case .light:
            guard on, let b = s.brightness, b < 100 else { return nil }
            return "\(Int(b))%"
        case .thermostat, .heaterCooler, .temperature: return s.temperature.map { "\($0.oneDecimal)°" }
        case .humidity: return s.humidity.map { "\(Int($0))%" }
        case .lux: return s.lux.map { "\(Int($0)) lx" }
        case .blinds:
            guard let p = s.openPercent, p > 0, p < 100 else { return nil }
            return "\(Int(p))%"
        case .outlet, .energy: return s.powerW.flatMap { $0 >= 1 ? "\(Int($0)) W" : nil }
        case .fan, .airPurifier:
            guard on, let p = s.fanPercent else { return nil }
            return "\(Int(p))%"
        case .airQuality, .vacuum, .appliance: return stateText(e, s)
        case .occupancy, .contact: return on ? stateText(e, s) : nil
        default: return nil
        }
    }

    // MARK: Bediening

    func toggle(_ e: MatterEndpoint) {
        let s = state(e)
        setOn(e, !isOn(e, s))
    }

    func setOn(_ e: MatterEndpoint, _ value: Bool) {
        guard let node = node(e.nodeID) else { return }
        let s = state(e)
        let ep = e.endpoint
        switch e.kind {
        case .lock:
            node.invoke(ep, MC.doorLock, value ? 0x00 : 0x01, timed: true, completion: reporter)
        case .blinds:
            node.invoke(ep, MC.windowCovering, value ? 0x00 : 0x01, completion: reporter)
        case .vacuum:
            // RVC: hervatten of pauzeren.
            node.invoke(ep, MC.rvcOpState, value ? 0x03 : 0x00, completion: reporter)
        case .thermostat, .heaterCooler:
            if s.hasOnOff {
                node.invoke(ep, MC.onOff, value ? 0x01 : 0x00, completion: reporter)
            } else {
                node.write(ep, MC.thermostat, 0x001C, MatterValue.uint(value ? 4 : 0))
            }
        case .fan, .airPurifier:
            if s.hasOnOff {
                node.invoke(ep, MC.onOff, value ? 0x01 : 0x00, completion: reporter)
            } else {
                node.write(ep, MC.fan, 0x0000, MatterValue.uint(value ? 4 : 0))
            }
        case .valve:
            if s.valveOpen != nil {
                node.invoke(ep, MC.valve, value ? 0x00 : 0x01, completion: reporter)
            } else {
                node.invoke(ep, MC.onOff, value ? 0x01 : 0x00, completion: reporter)
            }
        default:
            node.invoke(ep, MC.onOff, value ? 0x01 : 0x00, completion: reporter)
        }
        HistoryStore.shared.logMatter(name: e.name, room: e.room, text: value ? "Aangezet" : "Uitgezet")
    }

    func setBrightness(_ e: MatterEndpoint, _ percent: Double) {
        guard let node = node(e.nodeID) else { return }
        let level = UInt64(max(1, min(254, (percent / 100 * 254).rounded())))
        node.invoke(e.endpoint, MC.level, 0x04, fields: MatterValue.structure([
            (0, MatterValue.uint(level)), (1, MatterValue.uint(4)), (2, MatterValue.uint(0)), (3, MatterValue.uint(0))
        ]), completion: reporter)
    }

    func setColorTemperature(_ e: MatterEndpoint, mireds: Int) {
        guard let node = node(e.nodeID) else { return }
        node.invoke(e.endpoint, MC.color, 0x0A, fields: MatterValue.structure([
            (0, MatterValue.uint(UInt64(mireds))), (1, MatterValue.uint(4)), (2, MatterValue.uint(0)), (3, MatterValue.uint(0))
        ]), completion: reporter)
    }

    func setColor(_ e: MatterEndpoint, hue: Double, saturation: Double) {
        guard let node = node(e.nodeID) else { return }
        node.invoke(e.endpoint, MC.color, 0x06, fields: MatterValue.structure([
            (0, MatterValue.uint(UInt64(max(0, min(254, hue / 360 * 254))))),
            (1, MatterValue.uint(UInt64(max(0, min(254, saturation * 254))))),
            (2, MatterValue.uint(4)), (3, MatterValue.uint(0)), (4, MatterValue.uint(0))
        ]), completion: reporter)
    }

    /// 0 = dicht, 100 = open.
    func setOpen(_ e: MatterEndpoint, _ percent: Double) {
        guard let node = node(e.nodeID) else { return }
        let closed100ths = UInt64(max(0, min(10_000, (100 - percent) * 100)))
        node.invoke(e.endpoint, MC.windowCovering, 0x05,
                    fields: MatterValue.structure([(0, MatterValue.uint(closed100ths))]), completion: reporter)
    }

    func stopCovering(_ e: MatterEndpoint) {
        node(e.nodeID)?.invoke(e.endpoint, MC.windowCovering, 0x02, completion: reporter)
    }

    func setTarget(_ e: MatterEndpoint, celsius: Double) {
        node(e.nodeID)?.write(e.endpoint, MC.thermostat, 0x0012, MatterValue.int(Int64((celsius * 100).rounded())))
    }

    func setFan(_ e: MatterEndpoint, percent: Double) {
        node(e.nodeID)?.write(e.endpoint, MC.fan, 0x0002, MatterValue.uint(UInt64(max(0, min(100, percent)))))
    }

    /// Operationele status-commando's: 0 pauze, 1 stop, 2 start, 3 hervat, 0x80 naar dock (RVC).
    func operate(_ e: MatterEndpoint, command: UInt32) {
        let cluster = e.kind == .vacuum ? MC.rvcOpState : MC.opState
        node(e.nodeID)?.invoke(e.endpoint, cluster, command, completion: reporter)
    }

    /// Foutmelding van het apparaat tonen (komt terug op een willekeurige thread).
    private var reporter: (Error?) -> Void {
        { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.lastError = error.localizedDescription }
        }
    }
}
