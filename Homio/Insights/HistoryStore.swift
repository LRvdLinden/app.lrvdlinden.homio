import HomeKit
import SwiftUI

enum MetricKind: String, Codable, CaseIterable {
    case temperature, humidity, light, power

    var title: String {
        switch self {
        case .temperature: return "Temperatuur"
        case .humidity: return "Luchtvochtigheid"
        case .light: return "Verlichting"
        case .power: return "Schakelaars"
        }
    }

    var symbol: String {
        switch self {
        case .temperature: return "thermometer.medium"
        case .humidity: return "humidity.fill"
        case .light: return "lightbulb.fill"
        case .power: return "poweroutlet.type.f.fill"
        }
    }

    var color: Color {
        switch self {
        case .temperature: return IconPalette.orange
        case .humidity: return .cyan
        case .light: return IconPalette.yellow
        case .power: return IconPalette.blue
        }
    }

    /// Aan/uit-reeksen tekenen we als trap, de rest vloeiend.
    var isStep: Bool { self == .power }

    func format(_ value: Double) -> String {
        switch self {
        case .temperature: return "\(value.oneDecimal)°"
        case .humidity: return "\(Int(value.rounded()))%"
        case .light: return value > 0 ? "\(Int(value.rounded()))%" : "Uit"
        case .power: return value > 0 ? "Aan" : "Uit"
        }
    }
}

struct Metric: Codable, Hashable, Identifiable {
    let key: String
    let deviceID: UUID
    var name: String
    var room: String
    let kind: MetricKind
    var id: String { key }
}

struct Sample: Codable, Hashable {
    let t: Double
    let v: Double
    var date: Date { Date(timeIntervalSince1970: t) }
}

struct LogEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    let date: Date
    let title: String
    let detail: String
    let room: String
    let symbol: String
}

/// HomeKit bewaart geen geschiedenis. Homio meet daarom zelf, elke 5 minuten zolang de app
/// open is (ideaal op een iPad aan de muur), en houdt een tijdlijn bij van wat er gebeurt.
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var metrics: [String: Metric] = [:]
    @Published private(set) var series: [String: [Sample]] = [:]
    @Published private(set) var log: [LogEntry] = []

    private let interval: TimeInterval = 300
    private let keepDays: Double = 7
    private var timer: Timer?
    private var saveTask: Task<Void, Never>?
    private var lastSample = Date.distantPast

    private struct Archive: Codable {
        var metrics: [String: Metric]
        var series: [String: [Sample]]
        var log: [LogEntry]
    }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.json")
    }

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let archive = try? JSONDecoder().decode(Archive.self, from: data) {
            metrics = archive.metrics
            series = archive.series
            log = archive.log
        }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        // Even wachten tot HomeKit de waarden heeft ingelezen.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            self?.sampleIfDue()
        }
    }

    private func sampleIfDue() {
        if Date().timeIntervalSince(lastSample) > interval * 0.8 { sample() }
    }

    func sample() {
        let home = HomeStore.shared
        guard home.isReady else { return }
        let now = Date()
        lastSample = now
        let stamp = now.timeIntervalSince1970
        let cutoff = stamp - keepDays * 86_400

        for device in home.devices where device.isReachable {
            var points: [(MetricKind, Double)] = []
            switch device.kind {
            case .temperature, .thermostat:
                if let t = device.currentTemperature { points.append((.temperature, t)) }
                if let h = device.number(HMCharacteristicTypeCurrentRelativeHumidity) { points.append((.humidity, h)) }
            case .humidity:
                if let h = device.number(HMCharacteristicTypeCurrentRelativeHumidity) { points.append((.humidity, h)) }
            case .light:
                points.append((.light, device.isOn ? (device.brightness ?? 100) : 0))
            case .outlet, .switchKind, .fan:
                points.append((.power, device.isOn ? 1 : 0))
            default:
                break
            }
            for (kind, value) in points {
                let key = "\(device.id.uuidString)|\(kind.rawValue)"
                metrics[key] = Metric(key: key, deviceID: device.id, name: device.name, room: device.roomName, kind: kind)
                var list = series[key] ?? []
                list.append(Sample(t: stamp, v: value))
                if let first = list.firstIndex(where: { $0.t >= cutoff }), first > 0 {
                    list.removeFirst(first)
                }
                series[key] = list
            }
        }
        scheduleSave()
    }

    // MARK: Opvragen

    var sortedMetrics: [Metric] {
        metrics.values.sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return (MetricKind.allCases.firstIndex(of: lhs.kind) ?? 0) < (MetricKind.allCases.firstIndex(of: rhs.kind) ?? 0)
            }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    func points(_ key: String, hours: Double) -> [Sample] {
        let cutoff = Date().timeIntervalSince1970 - hours * 3600
        return (series[key] ?? []).filter { $0.t >= cutoff }
    }

    func latest(_ key: String) -> Double? {
        series[key]?.last?.v
    }

    // MARK: Tijdlijn

    func logChange(_ characteristic: HMCharacteristic, value: Any?) {
        guard let service = characteristic.service, let accessory = service.accessory else { return }
        guard let number = (value as? NSNumber)?.doubleValue ?? (characteristic.value as? NSNumber)?.doubleValue else { return }

        let text: String
        let symbol: String
        switch characteristic.characteristicType {
        case HMCharacteristicTypePowerState, HMCharacteristicTypeActive:
            text = number != 0 ? "Aangezet" : "Uitgezet"
            symbol = number != 0 ? "power.circle.fill" : "power.circle"
        case HMCharacteristicTypeCurrentLockMechanismState:
            guard number == 0 || number == 1 else { return }
            text = number == 1 ? "Op slot gedaan" : "Van het slot gehaald"
            symbol = number == 1 ? "lock.fill" : "lock.open.fill"
        case HMCharacteristicTypeContactState:
            text = number == 1 ? "Geopend" : "Gesloten"
            symbol = number == 1 ? "door.left.hand.open" : "door.left.hand.closed"
        case HMCharacteristicTypeMotionDetected:
            guard number != 0 else { return }
            text = "Beweging gezien"
            symbol = "figure.walk.motion"
        case HMCharacteristicTypeSmokeDetected, HMCharacteristicTypeCarbonMonoxideDetected,
             HMCharacteristicTypeCarbonDioxideDetected, HMCharacteristicTypeLeakDetected:
            text = number != 0 ? "Alarm!" : "Weer veilig"
            symbol = number != 0 ? "exclamationmark.octagon.fill" : "checkmark.shield"
        case HMCharacteristicTypeOccupancyDetected:
            guard number != 0 else { return }
            text = "Aanwezigheid gezien"
            symbol = "person.fill"
        case HMCharacteristicTypeCurrentDoorState:
            guard number == 0 || number == 1 else { return }
            text = number == 0 ? "Geopend" : "Gesloten"
            symbol = number == 0 ? "door.garage.open" : "door.garage.closed"
        default:
            return
        }

        let name = service.name.isEmpty ? accessory.name : service.name
        if let last = log.first, last.title == name, last.detail == text, Date().timeIntervalSince(last.date) < 5 {
            return
        }
        let room = accessory.room?.name ?? ""
        log.insert(LogEntry(date: Date(), title: name, detail: text, room: room, symbol: symbol), at: 0)
        PushRelay.shared.handle(serviceID: service.uniqueIdentifier, title: name, detail: text, room: room)
        if log.count > 500 { log.removeLast(log.count - 500) }
        scheduleSave()
    }

    func clearAll() {
        metrics = [:]
        series = [:]
        log = []
        scheduleSave()
    }

    // MARK: Bewaren

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func saveNow() {
        let archive = Archive(metrics: metrics, series: series, log: log)
        guard let data = try? JSONEncoder().encode(archive) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
