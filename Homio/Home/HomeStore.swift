import HomeKit
import SwiftUI

/// Alles rond HomeKit en Matter. Matter-apparaten die aan Apple Woning zijn
/// toegevoegd, verschijnen hier vanzelf als gewone accessoires.
@MainActor
final class HomeStore: NSObject, ObservableObject {
    static let shared = HomeStore()

    @Published private(set) var homes: [HMHome] = []
    @Published private(set) var isReady = false
    @Published private(set) var authorization: HMHomeManagerAuthorizationStatus = []
    @Published private(set) var revision = 0
    @Published var lastError: String?
    @Published var selectedHomeID: UUID? {
        didSet { UserDefaults.standard.set(selectedHomeID?.uuidString, forKey: "homio.home") }
    }

    private var manager: HMHomeManager?
    private var feeds: [UUID: CameraFeed] = [:]
    private var observed = Set<UUID>()

    private override init() {
        super.init()
        selectedHomeID = UserDefaults.standard.string(forKey: "homio.home").flatMap(UUID.init(uuidString:))
    }

    /// Start HomeKit pas na het inloggen, zodat de toestemmingsvraag op het juiste moment komt.
    func start() {
        guard manager == nil else { return }
        let m = HMHomeManager()
        m.delegate = self
        manager = m
    }

    func bump() { revision &+= 1 }

    var isDenied: Bool {
        authorization.contains(.determined) && !authorization.contains(.authorized)
    }

    var home: HMHome? {
        homes.first { $0.uniqueIdentifier == selectedHomeID } ?? homes.first
    }

    fileprivate func reloadHomes() {
        guard let m = manager else { return }
        homes = m.homes
        authorization = m.authorizationStatus
        for home in homes {
            home.delegate = self
            for accessory in home.accessories { observe(accessory) }
        }
        if selectedHomeID == nil || !homes.contains(where: { $0.uniqueIdentifier == selectedHomeID }) {
            selectedHomeID = homes.first?.uniqueIdentifier
        }
        isReady = true
        bump()
    }

    private func observe(_ accessory: HMAccessory) {
        accessory.delegate = self
        guard !observed.contains(accessory.uniqueIdentifier) else { return }
        observed.insert(accessory.uniqueIdentifier)
        for service in accessory.services {
            for c in service.characteristics {
                if c.properties.contains(HMCharacteristicPropertySupportsEventNotification) {
                    c.enableNotification(true) { _ in }
                }
                if c.properties.contains(HMCharacteristicPropertyReadable) {
                    c.readValue { [weak self] _ in
                        Task { @MainActor in self?.bump() }
                    }
                }
            }
        }
    }

    // MARK: Inhoud van de woning

    var devices: [Device] {
        guard let home else { return [] }
        var result: [Device] = []
        for accessory in home.accessories {
            for service in accessory.services where service.isUserInteractive {
                if let kind = DeviceKind(serviceType: service.serviceType) {
                    result.append(Device(service: service, accessory: accessory, kind: kind))
                }
            }
        }
        return result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func device(id: UUID) -> Device? {
        devices.first { $0.id == id }
    }

    var rooms: [RoomGroup] {
        let order = home?.rooms.map(\.name) ?? []
        let grouped = Dictionary(grouping: devices, by: \.roomName)
        return grouped
            .map { RoomGroup(name: $0.key, devices: $0.value) }
            .sorted { (order.firstIndex(of: $0.name) ?? Int.max) < (order.firstIndex(of: $1.name) ?? Int.max) }
    }

    /// Sferen: zonder de actiegroepen die bij automatiseringen horen.
    var scenes: [HMActionSet] {
        let owned = FlowStore.shared.ownedActionSetIDs
        return (home?.actionSets ?? [])
            .filter { $0.actionSetType != HMActionSetTypeTriggerOwned && !owned.contains($0.uniqueIdentifier.uuidString) }
            .sorted { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    var triggers: [HMTrigger] {
        (home?.triggers ?? []).sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func scene(id: UUID?) -> HMActionSet? {
        guard let id else { return nil }
        return home?.actionSets.first { $0.uniqueIdentifier == id }
    }

    func devices(inRoom room: String?) -> [Device] {
        guard let room else { return devices }
        return devices.filter { $0.roomName == room }
    }

    func setLights(on: Bool, room: String?) {
        for d in devices(inRoom: room) where d.kind == .light && d.isOn != on {
            write(d.characteristic(HMCharacteristicTypePowerState), on)
        }
    }

    var cameras: [HMAccessory] {
        (home?.accessories ?? []).filter { !($0.cameraProfiles ?? []).isEmpty }
    }

    func feed(for accessory: HMAccessory) -> CameraFeed {
        if let existing = feeds[accessory.uniqueIdentifier] { return existing }
        let feed = CameraFeed(accessory: accessory)
        feeds[accessory.uniqueIdentifier] = feed
        return feed
    }

    struct Summary {
        var lightsOn = 0
        var openLocks = 0
        var openContacts = 0
        var temperature: Double?
    }

    var summary: Summary {
        var s = Summary()
        var temps: [Double] = []
        for d in devices {
            switch d.kind {
            case .light where d.isOn: s.lightsOn += 1
            case .lock where !d.isOn: s.openLocks += 1
            case .contact where d.isOn: s.openContacts += 1
            case .temperature, .thermostat:
                if let t = d.currentTemperature { temps.append(t) }
            default: break
            }
        }
        if !temps.isEmpty { s.temperature = temps.reduce(0, +) / Double(temps.count) }
        return s
    }

    // MARK: Bedienen

    func toggle(_ d: Device) {
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
                if let error {
                    self?.lastError = error.localizedDescription
                } else {
                    HistoryStore.shared.logChange(characteristic, value: value)
                }
                self?.bump()
            }
        }
    }

    func run(_ scene: HMActionSet) {
        home?.executeActionSet(scene) { [weak self] error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                self?.bump()
            }
        }
    }

    /// Voor Siri en Opdrachten.
    func runScene(named name: String) async -> Bool {
        start()
        var waited = 0
        while !isReady && waited < 60 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }
        let wanted = name.trimmingCharacters(in: .whitespaces)
        guard let scene = scenes.first(where: {
            $0.name.compare(wanted, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else { return false }
        run(scene)
        return true
    }

    /// Opent Apples eigen koppelscherm, voor HomeKit- én Matter-apparaten.
    func addAccessory() {
        #if targetEnvironment(macCatalyst)
        lastError = "Apparaten toevoegen kan op je iPhone of iPad. Ze verschijnen daarna vanzelf op de Mac."
        #else
        home?.addAndSetupAccessories { [weak self] error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                self?.reloadHomes()
            }
        }
        #endif
    }

    func createHome(named name: String) {
        manager?.addHome(withName: name) { [weak self] _, error in
            Task { @MainActor in
                if let error { self?.lastError = error.localizedDescription }
                self?.reloadHomes()
            }
        }
    }
}

extension HomeStore: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in self.reloadHomes() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        Task { @MainActor in self.reloadHomes() }
    }
}

extension HomeStore: HMHomeDelegate {
    nonisolated func homeDidUpdateName(_ home: HMHome) {
        Task { @MainActor in self.bump() }
    }

    nonisolated func home(_ home: HMHome, didAdd accessory: HMAccessory) {
        Task { @MainActor in self.reloadHomes() }
    }

    nonisolated func home(_ home: HMHome, didRemove accessory: HMAccessory) {
        Task { @MainActor in self.reloadHomes() }
    }

    nonisolated func home(_ home: HMHome, didUpdate room: HMRoom, for accessory: HMAccessory) {
        Task { @MainActor in self.bump() }
    }

    nonisolated func home(_ home: HMHome, didAdd actionSet: HMActionSet) {
        Task { @MainActor in self.bump() }
    }

    nonisolated func home(_ home: HMHome, didRemove actionSet: HMActionSet) {
        Task { @MainActor in self.bump() }
    }

    nonisolated func home(_ home: HMHome, didAdd trigger: HMTrigger) {
        Task { @MainActor in self.bump() }
    }

    nonisolated func home(_ home: HMHome, didRemove trigger: HMTrigger) {
        Task { @MainActor in self.bump() }
    }

    nonisolated func home(_ home: HMHome, didUpdate trigger: HMTrigger) {
        Task { @MainActor in self.bump() }
    }
}

extension HomeStore: HMAccessoryDelegate {
    nonisolated func accessory(_ accessory: HMAccessory, service: HMService,
                               didUpdateValueFor characteristic: HMCharacteristic) {
        Task { @MainActor in
            HistoryStore.shared.logChange(characteristic, value: characteristic.value)
            self.bump()
        }
    }

    nonisolated func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        Task { @MainActor in self.bump() }
    }

    nonisolated func accessoryDidUpdateName(_ accessory: HMAccessory) {
        Task { @MainActor in self.bump() }
    }
}
