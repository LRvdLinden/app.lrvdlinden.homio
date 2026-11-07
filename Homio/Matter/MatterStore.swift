import Combine
import HomeKit
import Foundation
@preconcurrency import Matter
import SwiftUI

/// Een via Homio gekoppeld Matter-apparaat (node), zoals bewaard en via iCloud gedeeld.
struct MatterRecord: Codable, Identifiable, Hashable {
    var nodeID: UInt64
    var name: String
    var room: String
    var info: MatterNodeInfo
    var certified: Bool
    var added: Date
    /// Eigen naam/kamer per eindpunt (bij bridges en meervoudige stekkers).
    var endpointNames: [String: String] = [:]
    var endpointRooms: [String: String] = [:]

    var id: UInt64 { nodeID }
}

/// Eén bedienbaar eindpunt van een Matter-apparaat; zo ziet Homio het als "apparaat".
struct MatterEndpoint: Identifiable, Hashable {
    let nodeID: UInt64
    let endpoint: UInt16
    let kind: DeviceKind
    let types: [UInt32]
    let name: String
    let room: String
    var id: String { "matter-\(nodeID)-\(endpoint)" }
}

private struct AttrKey: Hashable {
    let endpoint: UInt16
    let cluster: UInt32
    let attribute: UInt32
}

/// Live verbinding met één node: houdt de laatst bekende waarden bij.
final class MatterNode: NSObject, MTRDeviceDelegate {
    let nodeID: UInt64
    let device: MTRDevice
    private var cache: [AttrKey: Any] = [:]
    private let lock = NSLock()
    var onChange: (() -> Void)?
    private(set) var state: MTRDeviceState = .unknown

    init(nodeID: UInt64, controller: MTRDeviceController) {
        self.nodeID = nodeID
        device = MTRDevice(nodeID: NSNumber(value: nodeID), controller: controller)
        super.init()
        device.setDelegate(self, queue: .main)
    }

    func value(_ endpoint: UInt16, _ cluster: UInt32, _ attribute: UInt32) -> Any? {
        let key = AttrKey(endpoint: endpoint, cluster: cluster, attribute: attribute)
        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        // Uit de cache van MTRDevice (en meteen een leesopdracht als hij er nog niet is).
        let raw = device.readAttribute(withEndpointID: NSNumber(value: endpoint), clusterID: NSNumber(value: cluster),
                                       attributeID: NSNumber(value: attribute), params: nil)
        let decoded = MatterValue.decode(raw)
        if let decoded {
            lock.lock()
            cache[key] = decoded
            lock.unlock()
        }
        return decoded
    }

    func number(_ endpoint: UInt16, _ cluster: UInt32, _ attribute: UInt32) -> Double? {
        (value(endpoint, cluster, attribute) as? NSNumber)?.doubleValue
    }

    func has(_ endpoint: UInt16, _ cluster: UInt32, _ attribute: UInt32 = 0) -> Bool {
        value(endpoint, cluster, attribute) != nil
    }

    func invoke(_ endpoint: UInt16, _ cluster: UInt32, _ command: UInt32,
                fields: [String: Any] = MatterValue.structure(), timed: Bool = false,
                completion: ((Error?) -> Void)? = nil) {
        device.invokeCommand(withEndpointID: NSNumber(value: endpoint), clusterID: NSNumber(value: cluster),
                             commandID: NSNumber(value: command), commandFields: fields,
                             expectedValues: nil, expectedValueInterval: nil,
                             timedInvokeTimeout: timed ? NSNumber(value: 10_000) : nil, queue: .main) { _, error in
            completion?(error)
        }
    }

    func write(_ endpoint: UInt16, _ cluster: UInt32, _ attribute: UInt32, _ value: [String: Any]) {
        // Meteen lokaal tonen; het apparaat bevestigt met een rapport.
        lock.lock()
        cache[AttrKey(endpoint: endpoint, cluster: cluster, attribute: attribute)] = MatterValue.decode(value)
        lock.unlock()
        device.writeAttribute(withEndpointID: NSNumber(value: endpoint), clusterID: NSNumber(value: cluster),
                              attributeID: NSNumber(value: attribute), value: value,
                              expectedValueInterval: NSNumber(value: 3_000), timedWriteTimeout: nil)
        onChange?()
    }

    // MARK: MTRDeviceDelegate

    func device(_ device: MTRDevice, stateChanged state: MTRDeviceState) {
        self.state = state
        onChange?()
    }

    func device(_ device: MTRDevice, receivedAttributeReport attributeReport: [[String: Any]]) {
        lock.lock()
        for item in attributeReport {
            guard let path = item[MTRAttributePathKey] as? MTRAttributePath else { continue }
            let key = AttrKey(endpoint: path.endpoint.uint16Value, cluster: path.cluster.uint32Value,
                              attribute: path.attribute.uint32Value)
            cache[key] = MatterValue.decode(item[MTRDataKey])
        }
        lock.unlock()
        onChange?()
    }

    func device(_ device: MTRDevice, receivedEventReport eventReport: [[String: Any]]) {}
}

/// Alle Matter-apparaten die Homio zelf beheert (naast HomeKit).
@MainActor
final class MatterStore: ObservableObject {
    static let shared = MatterStore()

    enum Status: Equatable {
        case idle, starting, ready
        case failed(String)
    }

    @Published private(set) var records: [MatterRecord] = []
    @Published private(set) var status: Status = .idle
    /// Wordt opgehoogd bij elke statuswijziging, zodat tegels opnieuw tekenen.
    @Published private(set) var revision = 0
    @Published var lastError: String?

    private(set) var controller: MTRDeviceController?
    private var nodes: [UInt64: MatterNode] = [:]
    private var pendingBump = false

    private let key = "homio.matter.v1"
    private let cloudKey = "matter"
    private var applyingRemote = false

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([MatterRecord].self, from: data) {
            records = saved
        }
        CloudSync.shared.register(cloudKey, apply: { [weak self] data in
            guard let self, let remote = try? JSONDecoder().decode([MatterRecord].self, from: data) else { return }
            self.applyingRemote = true
            self.records = remote
            self.save()
            self.applyingRemote = false
            self.attachNodes()
        }, current: { [weak self] in
            guard let self else { return nil }
            return try? JSONEncoder().encode(self.records)
        })
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
        if !applyingRemote { CloudSync.shared.push(cloudKey, payload: data) }
    }

    // MARK: Starten

    /// Start Homio's Matter-netwerk als er apparaten zijn (of als `force`, bij toevoegen).
    func start(force: Bool = false) {
        importPending()
        guard controller == nil, force || !records.isEmpty else { return }
        status = .starting
        Task.detached(priority: .userInitiated) {
            do {
                let controller = try MatterControllerFactory.shared(prefix: "app")
                await MainActor.run {
                    self.controller = controller
                    self.status = .ready
                    self.attachNodes()
                }
            } catch {
                await MainActor.run {
                    self.status = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func attachNodes() {
        guard let controller else { return }
        for record in records where nodes[record.nodeID] == nil {
            let node = MatterNode(nodeID: record.nodeID, controller: controller)
            node.onChange = { [weak self] in
                Task { @MainActor in self?.scheduleBump() }
            }
            nodes[record.nodeID] = node
        }
        let known = Set(records.map(\.nodeID))
        nodes = nodes.filter { known.contains($0.key) }
        revision += 1
    }

    /// Bundel snelle rapporten tot één verversing per 150 ms.
    private func scheduleBump() {
        guard !pendingBump else { return }
        pendingBump = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.pendingBump = false
            self?.revision += 1
        }
    }

    func node(_ id: UInt64) -> MatterNode? { nodes[id] }

    // MARK: Gekoppeld via het koppelscherm van Apple

    /// Neemt apparaten over die de koppel-extensie heeft toegevoegd.
    func importPending() {
        let defaults = MatterShared.defaults
        guard let data = defaults.data(forKey: MatterShared.pendingKey),
              let pending = try? JSONDecoder().decode([PendingMatterDevice].self, from: data),
              !pending.isEmpty else { return }
        defaults.removeObject(forKey: MatterShared.pendingKey)
        for p in pending where !records.contains(where: { $0.nodeID == p.nodeID }) {
            records.append(MatterRecord(nodeID: p.nodeID, name: p.name, room: p.room ?? "Standaardkamer",
                                        info: p.info, certified: p.certified, added: Date()))
        }
        save()
        attachNodes()
    }

    /// Geef de kamernamen door aan de extensie (voor het koppelscherm van Apple).
    func publishRooms(_ names: [String]) {
        let all = Array(Set(names + records.map(\.room))).sorted()
        MatterShared.defaults.set(all, forKey: MatterShared.roomsKey)
    }

    // MARK: Koppelen met een code (apparaat zit al in een andere app)

    func commission(code: String, name: String, room: String) async throws -> MatterRecord {
        let controller: MTRDeviceController
        if let existing = self.controller {
            controller = existing
        } else {
            controller = try await Task.detached { try MatterControllerFactory.shared(prefix: "app") }.value
            self.controller = controller
            status = .ready
        }
        let commissioner = MatterCommissioner(controller: controller)
        let nodeID = try await commissioner.commission(code: code)
        let info = await MatterInspector.readInfo(nodeID: nodeID, controller: controller)
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty
            ? ([info.nodeLabel, info.productName].first { !$0.isEmpty } ?? "Matter-apparaat")
            : name
        let record = MatterRecord(nodeID: nodeID, name: finalName, room: room, info: info,
                                  certified: !commissioner.attestationFailed, added: Date())
        records.append(record)
        save()
        attachNodes()
        return record
    }

    // MARK: Lijst van eindpunten

    func endpoints(of record: MatterRecord) -> [MatterEndpoint] {
        let usable = record.info.endpoints
            .filter { $0.key != 0 }
            .compactMap { ep, types -> (UInt16, DeviceKind, [UInt32])? in
                guard let kind = MatterDeviceTypes.kind(for: types) else { return nil }
                return (ep, kind, types)
            }
            .sorted { $0.0 < $1.0 }
        return usable.enumerated().map { index, item in
            let (ep, kind, types) = item
            let key = String(ep)
            let name = record.endpointNames[key]
                ?? record.info.endpointLabels[ep]
                ?? (usable.count > 1 ? "\(record.name) \(index + 1)" : record.name)
            return MatterEndpoint(nodeID: record.nodeID, endpoint: ep, kind: kind, types: types,
                                  name: name, room: record.endpointRooms[key] ?? record.room)
        }
    }

    /// Alle eindpunten, zonder apparaten die al via Apple Woning (HomeKit) in Homio staan.
    func visibleEndpoints(home: HomeStore) -> [MatterEndpoint] {
        records.filter { !isDuplicate($0, home: home) }.flatMap { endpoints(of: $0) }
    }

    func endpoints(inRoom room: String, home: HomeStore) -> [MatterEndpoint] {
        visibleEndpoints(home: home).filter { $0.room == room }
    }

    func endpoint(id: String) -> MatterEndpoint? {
        records.lazy.flatMap { self.endpoints(of: $0) }.first { $0.id == id }
    }

    func record(_ nodeID: UInt64) -> MatterRecord? {
        records.first { $0.nodeID == nodeID }
    }

    // MARK: Geen dubbelingen met HomeKit

    /// Zit dit apparaat ook in Apple Woning? Dan toont Homio de HomeKit-versie.
    func isDuplicate(_ record: MatterRecord, home: HomeStore) -> Bool {
        let fingerprints = home.accessoryFingerprints
        let serial = record.info.serialNumber.normalizedSerial
        if !serial.isEmpty, fingerprints.serials.contains(serial) { return true }
        let combo = [record.info.vendorName, record.info.productName, record.name]
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }.joined(separator: "|")
        return fingerprints.combos.contains(combo)
    }

    // MARK: Beheer

    func rename(_ endpoint: MatterEndpoint, to name: String) {
        guard let i = records.firstIndex(where: { $0.nodeID == endpoint.nodeID }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if endpoints(of: records[i]).count > 1 {
            records[i].endpointNames[String(endpoint.endpoint)] = trimmed
        } else {
            records[i].name = trimmed
        }
        save()
    }

    func move(_ endpoint: MatterEndpoint, to room: String) {
        guard let i = records.firstIndex(where: { $0.nodeID == endpoint.nodeID }) else { return }
        if endpoints(of: records[i]).count > 1 {
            records[i].endpointRooms[String(endpoint.endpoint)] = room
        } else {
            records[i].room = room
        }
        save()
    }

    /// Haalt Homio's netwerk van het apparaat af en vergeet het.
    func remove(_ nodeID: UInt64, forgetOnly: Bool = false) async {
        if !forgetOnly, let node = nodes[nodeID],
           let index = node.number(0, MC.opCredentials, 0x0005) {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                node.invoke(0, MC.opCredentials, 0x0A,
                            fields: MatterValue.structure([(0, MatterValue.uint(UInt64(index)))])) { _ in
                    cont.resume()
                }
            }
        }
        records.removeAll { $0.nodeID == nodeID }
        nodes[nodeID] = nil
        DeviceIconStore.shared.icons.keys.filter { $0.hasPrefix("matter-\(nodeID)-") }
            .forEach { DeviceIconStore.shared.set(nil, for: $0) }
        save()
    }

    /// Opent een koppelvenster zodat een andere app (Apple Woning, Google, Homey …) het
    /// apparaat ook kan toevoegen. Geeft de handmatige koppelcode terug.
    func shareCode(_ nodeID: UInt64) async throws -> String {
        guard let node = nodes[nodeID] else { throw MatterControllerError.noController }
        var passcode: UInt32 = 0
        let invalid: Set<UInt32> = [0, 11111111, 22222222, 33333333, 44444444, 55555555,
                                    66666666, 77777777, 88888888, 99999999, 12345678, 87654321]
        repeat { passcode = UInt32.random(in: 1...99_999_998) } while invalid.contains(passcode)
        let discriminator = UInt16.random(in: 0...0xFFF)
        return try await withCheckedThrowingContinuation { cont in
            node.device.openCommissioningWindow(withSetupPasscode: NSNumber(value: passcode),
                                                discriminator: NSNumber(value: discriminator),
                                                duration: 900, queue: .main) { payload, error in
                if let code = payload?.manualEntryCode() {
                    cont.resume(returning: code)
                } else {
                    cont.resume(throwing: error ?? MatterControllerError.commissioningFailed("geen code ontvangen"))
                }
            }
        }
    }
}

private extension String {
    var normalizedSerial: String {
        let s = trimmingCharacters(in: .whitespaces).lowercased()
        return ["", "0", "unknown", "n/a", "none", "default", "1234567890"].contains(s) ? "" : s
    }
}

extension HomeStore {
    struct Fingerprints {
        var serials: Set<String> = []
        var combos: Set<String> = []
    }

    /// Serienummers en merk|model|naam van alle HomeKit-accessoires (voor ontdubbelen).
    var accessoryFingerprints: Fingerprints {
        var out = Fingerprints()
        for accessory in home?.accessories ?? [] {
            for service in accessory.services {
                for c in service.characteristics where c.characteristicType == HMCharacteristicTypeSerialNumber {
                    if let serial = (c.value as? String)?.normalizedSerial, !serial.isEmpty { out.serials.insert(serial) }
                }
            }
            let combo = [accessory.manufacturer ?? "", accessory.model ?? "", accessory.name]
                .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }.joined(separator: "|")
            out.combos.insert(combo)
        }
        return out
    }
}
