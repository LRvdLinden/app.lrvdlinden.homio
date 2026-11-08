import SwiftUI

enum FaceKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case clock, home, dashboard, cameras, photos, weather, calendar, flow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: return "Klok"
        case .home: return "Woning"
        case .dashboard: return "Dashboard"
        case .cameras: return "Camera's"
        case .photos: return "Foto's"
        case .weather: return "Weer"
        case .calendar: return "Agenda"
        case .flow: return "Flow"
        }
    }

    var symbol: String {
        switch self {
        case .clock: return "clock.fill"
        case .home: return "square.grid.2x2.fill"
        case .dashboard: return "square.grid.3x2.fill"
        case .cameras: return "video.fill"
        case .photos: return "photo.fill"
        case .weather: return "cloud.sun.fill"
        case .calendar: return "calendar"
        case .flow: return "sparkles"
        }
    }
}

struct FaceSetting: Codable, Identifiable, Hashable {
    var kind: FaceKind
    var enabled: Bool
    var id: FaceKind { kind }
}

struct Profile: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorIndex: Int
    var favoriteDeviceIDs: [UUID] = []
    /// Profielfoto als kleine JPEG (± 240 px), zodat hij via iCloud mee kan.
    var photo: Data?

    static let palette: [Color] = [Theme.amber, .pink, .mint, .cyan, .purple, .orange]
    var color: Color { Profile.palette[abs(colorIndex) % Profile.palette.count] }
    var initial: String { String(name.prefix(1)).uppercased() }
}

/// Instellingen en profielen, bewaard als JSON in UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    private struct Stored: Codable {
        var profiles: [Profile]
        var activeProfileID: UUID?
        var faces: [FaceSetting]
        var proximityEnabled: Bool
        var nightDimming: Bool
        var keepAwake: Bool
        var startInDisplayMode: Bool?
    }

    @Published var profiles: [Profile] { didSet { save(); pushSynced() } }
    @Published var activeProfileID: UUID? { didSet { save() } }
    @Published var faces: [FaceSetting] { didSet { save(); pushSynced() } }
    @Published var proximityEnabled: Bool { didSet { save() } }
    @Published var nightDimming: Bool { didSet { save() } }
    @Published var keepAwake: Bool { didSet { save(); applyKeepAwake() } }
    @Published var startInDisplayMode: Bool { didSet { save() } }

    private let key = "homio.settings.v1"
    private let cloudKey = "profiles"
    private var applyingRemote = false

    /// Wat er via iCloud meegaat: profielen (met favorieten) en faces.
    private struct Synced: Codable {
        var profiles: [Profile]
        var faces: [FaceSetting]
    }

    init() {
        let stored = UserDefaults.standard.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        profiles = stored?.profiles ?? []
        activeProfileID = stored?.activeProfileID
        proximityEnabled = stored?.proximityEnabled ?? false
        nightDimming = stored?.nightDimming ?? true
        keepAwake = stored?.keepAwake ?? (UIDevice.current.userInterfaceIdiom == .pad)
        startInDisplayMode = stored?.startInDisplayMode ?? false

        // Nieuwe faces uit latere versies achteraan toevoegen.
        var list = stored?.faces ?? FaceKind.allCases.map { FaceSetting(kind: $0, enabled: true) }
        for kind in FaceKind.allCases where !list.contains(where: { $0.kind == kind }) {
            list.append(FaceSetting(kind: kind, enabled: true))
        }
        faces = list

        CloudSync.shared.register(cloudKey, apply: { [weak self] data in
            guard let self, let remote = try? JSONDecoder().decode(Synced.self, from: data) else { return }
            self.applyingRemote = true
            self.profiles = remote.profiles
            var faces = remote.faces
            for kind in FaceKind.allCases where !faces.contains(where: { $0.kind == kind }) {
                faces.append(FaceSetting(kind: kind, enabled: true))
            }
            self.faces = faces
            if !self.profiles.contains(where: { $0.id == self.activeProfileID }) {
                self.activeProfileID = self.profiles.first?.id
            }
            self.applyingRemote = false
        }, current: { [weak self] in
            guard let self else { return nil }
            return try? JSONEncoder().encode(Synced(profiles: self.profiles, faces: self.faces))
        })
    }

    private func save() {
        let stored = Stored(profiles: profiles, activeProfileID: activeProfileID, faces: faces,
                            proximityEnabled: proximityEnabled, nightDimming: nightDimming,
                            keepAwake: keepAwake, startInDisplayMode: startInDisplayMode)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func pushSynced() {
        guard !applyingRemote, let data = try? JSONEncoder().encode(Synced(profiles: profiles, faces: faces)) else { return }
        CloudSync.shared.push(cloudKey, payload: data)
    }

    func applyKeepAwake() {
        UIApplication.shared.isIdleTimerDisabled = keepAwake
    }

    // MARK: Faces

    var enabledFaces: [FaceKind] {
        let list = faces.filter(\.enabled).map(\.kind)
        return list.isEmpty ? [.clock] : list
    }

    // MARK: Profielen

    var activeProfile: Profile? {
        profiles.first { $0.id == activeProfileID } ?? profiles.first
    }

    func ensureProfile(named name: String) {
        if profiles.isEmpty {
            let profile = Profile(name: name.isEmpty ? "Ik" : name, colorIndex: 0)
            profiles = [profile]
            activeProfileID = profile.id
        }
    }

    func addProfile(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let profile = Profile(name: trimmed, colorIndex: profiles.count)
        profiles.append(profile)
        activeProfileID = profile.id
    }

    /// Naam en/of foto van een profiel aanpassen.
    func updateProfile(_ id: UUID, name: String? = nil, photo: Data?? = nil) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { profiles[index].name = trimmed }
        }
        if let photo { profiles[index].photo = photo }
    }

    func removeProfiles(at offsets: IndexSet) {
        profiles.remove(atOffsets: offsets)
        if !profiles.contains(where: { $0.id == activeProfileID }) {
            activeProfileID = profiles.first?.id
        }
    }

    func isFavorite(_ id: UUID) -> Bool {
        activeProfile?.favoriteDeviceIDs.contains(id) ?? false
    }

    func toggleFavorite(_ id: UUID) {
        guard let profileID = activeProfile?.id,
              let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        if let existing = profiles[index].favoriteDeviceIDs.firstIndex(of: id) {
            profiles[index].favoriteDeviceIDs.remove(at: existing)
        } else {
            profiles[index].favoriteDeviceIDs.append(id)
        }
    }
}
