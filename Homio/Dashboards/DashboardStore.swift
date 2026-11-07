import SwiftUI

enum WidgetKind: String, Codable, CaseIterable {
    case device, group, scene, room, clock, weather, camera, chart, timers, calendar, flows, note

    var title: String {
        switch self {
        case .device: return "Apparaat"
        case .group: return "Groep"
        case .scene: return "Sfeer"
        case .room: return "Kamer"
        case .clock: return "Klok"
        case .weather: return "Weer"
        case .camera: return "Camera"
        case .chart: return "Grafiek"
        case .timers: return "Timers"
        case .calendar: return "Agenda"
        case .flows: return "Flows"
        case .note: return "Notitie"
        }
    }

    var symbol: String {
        switch self {
        case .device: return "lightbulb.fill"
        case .group: return "lightbulb.2.fill"
        case .scene: return "sparkles"
        case .room: return "square.split.bottomrightquarter.fill"
        case .clock: return "clock.fill"
        case .weather: return "cloud.sun.fill"
        case .camera: return "video.fill"
        case .chart: return "chart.xyaxis.line"
        case .timers: return "timer"
        case .calendar: return "calendar"
        case .flows: return "arrow.triangle.branch"
        case .note: return "note.text"
        }
    }

    var defaultSize: WidgetSize {
        switch self {
        case .device, .group, .scene, .clock: return .small
        case .camera: return .large
        default: return .wide
        }
    }
}

/// Formaat in rastercellen: klein 1×1, breed 2×1, groot 2×2.
enum WidgetSize: String, Codable, CaseIterable {
    case small, wide, large

    var columns: Int { self == .small ? 1 : 2 }
    var rows: Int { self == .large ? 2 : 1 }

    var title: String {
        switch self {
        case .small: return "Klein"
        case .wide: return "Breed"
        case .large: return "Groot"
        }
    }

    var symbol: String {
        switch self {
        case .small: return "square"
        case .wide: return "rectangle"
        case .large: return "square.grid.2x2"
        }
    }
}

struct DashWidget: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: WidgetKind
    var size: WidgetSize
    var deviceID: UUID? = nil
    var sceneID: UUID? = nil
    var roomName: String? = nil
    var cameraID: UUID? = nil
    var metricKey: String? = nil
    var text: String = ""
    var groupID: UUID? = nil
}

struct Dashboard: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var widgets: [DashWidget]
}

/// Alle dashboards van deze iPad of iPhone, bewaard als JSON.
@MainActor
final class DashboardStore: ObservableObject {
    @Published var dashboards: [Dashboard] = [] { didSet { save(); pushDashboards() } }
    @Published var selectedID: UUID? { didSet { save() } }

    private let key = "homio.dashboards.v1"
    private let cloudKey = "dashboards"
    private var applyingRemote = false

    private struct Stored: Codable {
        var dashboards: [Dashboard]
        var selectedID: UUID?
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            dashboards = stored.dashboards
            selectedID = stored.selectedID
        }
        CloudSync.shared.register(cloudKey, apply: { [weak self] data in
            self?.applyRemote(data)
        }, current: { [weak self] in
            guard let self else { return nil }
            return try? JSONEncoder().encode(self.dashboards)
        })
    }

    private func applyRemote(_ data: Data) {
        guard let remote = try? JSONDecoder().decode([Dashboard].self, from: data) else { return }
        applyingRemote = true
        dashboards = remote
        if !dashboards.contains(where: { $0.id == selectedID }) { selectedID = dashboards.first?.id }
        applyingRemote = false
    }

    private func save() {
        let stored = Stored(dashboards: dashboards, selectedID: selectedID)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func pushDashboards() {
        guard !applyingRemote, let data = try? JSONEncoder().encode(dashboards) else { return }
        CloudSync.shared.push(cloudKey, payload: data)
    }

    var selected: Dashboard? {
        dashboards.first { $0.id == selectedID } ?? dashboards.first
    }

    func dashboard(id: UUID) -> Dashboard? {
        dashboards.first { $0.id == id }
    }

    /// Maakt bij de eerste keer een dashboard met wat er in huis is.
    func ensureDefault(home: HomeStore) {
        guard dashboards.isEmpty else { return }
        var widgets: [DashWidget] = [
            DashWidget(kind: .clock, size: .small),
            DashWidget(kind: .weather, size: .wide)
        ]
        for device in home.devices.filter({ !$0.kind.isSensor }).prefix(4) {
            widgets.append(DashWidget(kind: .device, size: .small, deviceID: device.id))
        }
        if let scene = home.scenes.first {
            widgets.append(DashWidget(kind: .scene, size: .small, sceneID: scene.uniqueIdentifier))
        }
        widgets.append(DashWidget(kind: .room, size: .wide))
        if let camera = home.cameras.first {
            widgets.append(DashWidget(kind: .camera, size: .large, cameraID: camera.uniqueIdentifier))
        }
        widgets.append(DashWidget(kind: .timers, size: .wide))
        let dashboard = Dashboard(name: "Thuis", symbol: "house.fill", widgets: widgets)
        dashboards = [dashboard]
        selectedID = dashboard.id
    }

    // MARK: Dashboards

    func addDashboard(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let dashboard = Dashboard(name: trimmed.isEmpty ? "Dashboard" : trimmed,
                                  symbol: "square.grid.2x2.fill",
                                  widgets: [DashWidget(kind: .clock, size: .small)])
        dashboards.append(dashboard)
        selectedID = dashboard.id
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = dashboards.firstIndex(where: { $0.id == id }) else { return }
        dashboards[index].name = trimmed
    }

    func deleteDashboard(_ id: UUID) {
        dashboards.removeAll { $0.id == id }
        if selectedID == id { selectedID = dashboards.first?.id }
    }

    // MARK: Widgets

    private func update(_ dashboardID: UUID, _ change: (inout Dashboard) -> Void) {
        guard let index = dashboards.firstIndex(where: { $0.id == dashboardID }) else { return }
        change(&dashboards[index])
    }

    func add(_ widget: DashWidget, to dashboardID: UUID) {
        update(dashboardID) { $0.widgets.append(widget) }
    }

    func remove(_ widgetID: UUID, from dashboardID: UUID) {
        update(dashboardID) { $0.widgets.removeAll { $0.id == widgetID } }
    }

    func resize(_ widgetID: UUID, to size: WidgetSize, in dashboardID: UUID) {
        update(dashboardID) { dash in
            if let i = dash.widgets.firstIndex(where: { $0.id == widgetID }) { dash.widgets[i].size = size }
        }
    }

    func setText(_ text: String, for widgetID: UUID, in dashboardID: UUID) {
        update(dashboardID) { dash in
            if let i = dash.widgets.firstIndex(where: { $0.id == widgetID }) { dash.widgets[i].text = text }
        }
    }

    /// Versleept widget `moving` naar de plek van `target`.
    func move(_ moving: UUID, onto target: UUID, in dashboardID: UUID) {
        guard moving != target else { return }
        update(dashboardID) { dash in
            guard let from = dash.widgets.firstIndex(where: { $0.id == moving }),
                  let to = dash.widgets.firstIndex(where: { $0.id == target }) else { return }
            let item = dash.widgets.remove(at: from)
            dash.widgets.insert(item, at: to)
        }
    }
}
