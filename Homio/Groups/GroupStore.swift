import SwiftUI

/// Een eigen groep apparaten, bijv. "Alle plafondlampen" of "Buiten", over kamers heen.
struct DeviceGroup: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var deviceIDs: [UUID]

    static let symbols = ["lightbulb.2.fill", "lamp.floor.fill", "lamp.ceiling.fill", "light.strip.2.fill",
                          "sun.max.fill", "moon.fill", "tree.fill", "poweroutlet.type.f.fill",
                          "blinds.horizontal.closed", "fan.fill", "bed.double.fill", "sofa.fill"]
}

@MainActor
final class GroupStore: ObservableObject {
    @Published var groups: [DeviceGroup] = [] { didSet { save() } }

    private let key = "homio.groups.v1"
    private let cloudKey = "groups"
    private var applyingRemote = false

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([DeviceGroup].self, from: data) {
            groups = saved
        }
        CloudSync.shared.register(cloudKey, apply: { [weak self] data in
            guard let self, let remote = try? JSONDecoder().decode([DeviceGroup].self, from: data) else { return }
            self.applyingRemote = true
            self.groups = remote
            self.applyingRemote = false
        }, current: { [weak self] in
            guard let self else { return nil }
            return try? JSONEncoder().encode(self.groups)
        })
    }

    private func save() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: key)
            if !applyingRemote { CloudSync.shared.push(cloudKey, payload: data) }
        }
    }

    func group(id: UUID?) -> DeviceGroup? {
        guard let id else { return nil }
        return groups.first { $0.id == id }
    }

    func upsert(_ group: DeviceGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
    }

    func delete(_ id: UUID) {
        groups.removeAll { $0.id == id }
    }
}

/// Toestand en bediening van een groep, uitgerekend uit de leden.
@MainActor
struct GroupState {
    let group: DeviceGroup
    let members: [Device]

    init(group: DeviceGroup, home: HomeStore) {
        self.group = group
        members = group.deviceIDs.compactMap { home.device(id: $0) }
    }

    var onCount: Int { members.filter { $0.isToggleable && $0.isOn }.count }
    var isOn: Bool { onCount > 0 }
    var lights: [Device] { members.filter { $0.kind == .light } }

    var averageBrightness: Double? {
        let values = lights.filter(\.isOn).map { $0.brightness ?? 100 }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    var stateText: String {
        if members.isEmpty { return "Geen apparaten" }
        if onCount == 0 { return "Alles uit" }
        if onCount == members.filter(\.isToggleable).count { return "Alles aan" }
        return "\(onCount) van \(members.filter(\.isToggleable).count) aan"
    }

    /// Iets aan → alles uit; alles uit → alles aan.
    func toggle(_ home: HomeStore) {
        let target = !isOn
        for device in members { home.set(device, on: target) }
    }

    func setBrightness(_ percent: Int, _ home: HomeStore) {
        for light in lights { home.setBrightness(light, percent: percent) }
    }
}
