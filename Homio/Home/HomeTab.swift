import HomeKit
import SwiftUI

/// Het Thuis-tabblad: begroeting, status, zones (favorieten, alles, kamers), sferen en apparaten.
struct HomeTab: View {
    let startDisplay: () -> Void

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var weather: WeatherService
    @EnvironmentObject private var matter: MatterStore
    @EnvironmentObject private var flows: FlowStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var zone: Zone = .favorites
    @State private var sceneEdit: SceneEditTarget?
    @State private var sceneToDelete: HMActionSet?
    @State private var showSearch = false
    @State private var showMatterAdd = false
    @State private var zoneSheet: ZoneControlKind?
    @EnvironmentObject private var history: HistoryStore

    enum Zone: Hashable {
        case favorites, all
        case room(String)
    }

    private var compact: Bool { sizeClass == .compact }

    var body: some View {
        NavigationStack {
            HomeStateGate {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        AttentionSection()
                        zonePicker
                        zoneControls
                        scenesRow
                        if zone == .favorites || zone == .all {
                            GroupsSection(columns: columns)
                        }
                        zoneContent
                    }
                    .padding(.horizontal, compact ? Theme.edge : Theme.edgeTablet)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle(home.home?.name ?? "Thuis")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: startDisplay) {
                        Image(systemName: "play.rectangle.fill")
                    }
                    .accessibilityLabel("Weergavemodus")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Zoeken")
                    if home.homes.count > 1 {
                        Menu {
                            Picker("Woning", selection: Binding(
                                get: { home.home?.uniqueIdentifier },
                                set: { home.selectedHomeID = $0 }
                            )) {
                                ForEach(home.homes, id: \.uniqueIdentifier) { h in
                                    Text(h.name).tag(Optional(h.uniqueIdentifier))
                                }
                            }
                        } label: {
                            Image(systemName: "house.circle")
                        }
                    }
                    Menu {
                        Button { home.addAccessory() } label: {
                            Label("Apparaat toevoegen (Apple Woning)", systemImage: "plus.circle")
                        }
                        Button { showMatterAdd = true } label: {
                            Label("Matter-apparaat toevoegen (Homio)", systemImage: "dot.radiowaves.left.and.right")
                        }
                        Button { sceneEdit = SceneEditTarget(scene: nil) } label: {
                            Label("Nieuwe sfeer", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Toevoegen")
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchSheet()
            }
            .sheet(isPresented: $showMatterAdd) {
                MatterAddView()
            }
            .sheet(item: $zoneSheet) { kind in
                ZoneControlSheet(kind: kind, devices: zoneDevices, zoneName: zoneTitle)
            }
            .sheet(item: $sceneEdit) { target in
                SceneEditorView(scene: target.scene)
            }
            .confirmationDialog("Sfeer verwijderen?",
                                isPresented: Binding(get: { sceneToDelete != nil },
                                                     set: { if !$0 { sceneToDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Verwijderen", role: .destructive) {
                    if let scene = sceneToDelete {
                        Task { await FlowStore.shared.deleteScene(scene) }
                    }
                    sceneToDelete = nil
                }
            }
            .alert("Er ging iets mis", isPresented: Binding(
                get: { home.lastError != nil },
                set: { if !$0 { home.lastError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(home.lastError ?? "")
            }
        }
        .onAppear { weather.start() }
    }

    // MARK: Kop

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 6..<12: base = "Goedemorgen"
        case 12..<18: base = "Goedemiddag"
        case 18..<24: base = "Goedenavond"
        default: base = "Goedenacht"
        }
        if let name = settings.activeProfile?.name, !name.isEmpty { return "\(base), \(name)" }
        return base
    }

    /// Kop zoals Homey: begroeting en een zin over het weer en het huis.
    private var header: some View {
        let s = home.summary
        var parts: [String] = []
        if let current = weather.current {
            parts.append("Het is \(Int(current.temperature.rounded()))° en \(WeatherService.description(for: current.code).lowercased())")
        }
        if let t = s.temperature { parts.append("binnen \(t.oneDecimal)°") }
        let sentence = parts.isEmpty ? "Welkom thuis" : parts.joined(separator: ", ") + "."
        return VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(HomeyFont.xlarge)
                .foregroundStyle(Theme.text)
            HStack(spacing: 6) {
                if let current = weather.current {
                    Image(systemName: WeatherService.symbol(for: current.code, isDay: current.isDay))
                        .symbolRenderingMode(.multicolor)
                }
                Text(sentence)
            }
            .font(HomeyFont.body)
            .foregroundStyle(Theme.textLight)
        }
    }

    // MARK: Zonebediening (Verlichting, Klimaat, Activiteit)

    private var zoneDevices: [Device] {
        switch zone {
        case .room(let name): return home.devices.filter { $0.roomName == name }
        default: return home.devices
        }
    }

    private var zoneControls: some View {
        let devices = zoneDevices
        let lights = devices.filter { $0.kind == .light }
        let lightsOn = lights.filter(\.isOn).count
        let temps = devices.compactMap { [.temperature, .thermostat, .heaterCooler].contains($0.kind) ? $0.currentTemperature : nil }
        let avg = temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)
        let lastActivity = history.log.first { entry in
            if case .room(let name) = zone { return entry.room == name }
            return true
        }
        return HStack(spacing: 10) {
            ZoneControlTile(title: "Verlichting", symbol: "lightbulb.fill", color: Theme.yellow,
                            value: lights.isEmpty ? "Geen lampen" : (lightsOn == 0 ? "Alles uit" : "\(lightsOn) aan")) {
                zoneSheet = .lights
            }
            ZoneControlTile(title: "Klimaat", symbol: "thermometer.medium", color: Theme.orange,
                            value: avg.map { "\($0.oneDecimal)°" } ?? "–") {
                zoneSheet = .climate
            }
            ZoneControlTile(title: "Activiteit", symbol: "waveform.path.ecg", color: Theme.accent,
                            value: lastActivity.map { $0.date.formatted(.relative(presentation: .named)) } ?? "Rustig") {
                zoneSheet = .activity
            }
        }
    }

    // MARK: Zones

    private var zonePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ZoneChip(title: "Favorieten", symbol: "star.fill", selected: zone == .favorites) { zone = .favorites }
                ZoneChip(title: "Alles", symbol: "house.fill", selected: zone == .all) { zone = .all }
                ForEach(home.rooms) { room in
                    ZoneChip(title: room.name, symbol: nil, selected: zone == .room(room.name)) {
                        zone = .room(room.name)
                    }
                }
                ForEach(matterOnlyRooms, id: \.self) { name in
                    ZoneChip(title: name, symbol: nil, selected: zone == .room(name)) {
                        zone = .room(name)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: zone)
    }

    // MARK: Sferen

    private var scenesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Sferen", subtitle: nil)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(home.scenes, id: \.uniqueIdentifier) { scene in
                        SceneChip(name: scene.name, symbol: scene.symbol) { home.run(scene) }
                            .contextMenu {
                                Button { home.run(scene) } label: { Label("Starten", systemImage: "play.fill") }
                                if !scene.isBuiltIn || !scene.actions.isEmpty {
                                    Button { sceneEdit = SceneEditTarget(scene: scene) } label: {
                                        Label("Bewerken", systemImage: "pencil")
                                    }
                                }
                                if !scene.isBuiltIn {
                                    Button(role: .destructive) { sceneToDelete = scene } label: {
                                        Label("Verwijderen", systemImage: "trash")
                                    }
                                }
                            }
                    }
                    Button { sceneEdit = SceneEditTarget(scene: nil) } label: {
                        Label("Nieuwe sfeer", systemImage: "plus")
                            .font(HomeyFont.smallMedium)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(Capsule().fill(Theme.accent.opacity(0.08)))
                            .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    }
                    .buttonStyle(PressableStyle())
                    .foregroundStyle(Theme.accent)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            let favoriteFlows = home.triggers.filter { flows.isFavorite($0) }
            if !favoriteFlows.isEmpty {
                SectionHeading(title: "Favoriete flows", subtitle: nil)
                    .padding(.top, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(favoriteFlows, id: \.uniqueIdentifier) { trigger in
                            HStack(spacing: 8) {
                                FlowRunButton(trigger: trigger, size: 32)
                                Text(trigger.name).font(HomeyFont.smallMedium).foregroundStyle(Theme.text).lineLimit(1)
                            }
                            .padding(4)
                            .padding(.trailing, 10)
                            .frame(height: 40)
                            .background(Capsule().fill(Theme.card).shadow(color: .black.opacity(0.12), radius: 3, y: 2))
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: Inhoud per zone

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 96 : 124, maximum: 160), spacing: Theme.gutter)]
    }

    @ViewBuilder
    private var zoneContent: some View {
        switch zone {
        case .favorites:
            let favorites = favoriteDevices
            if favorites.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nog geen favorieten")
                        .font(.title3.weight(.semibold))
                    Text("Houd een apparaat ingedrukt en tik op de ster om het hier te zetten. Zo heeft elk gezinslid zijn eigen favorieten.")
                        .foregroundStyle(Theme.textLight)
                    Button("Bekijk alle apparaten") { zone = .all }
                        .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            } else {
                LazyVGrid(columns: columns, spacing: Theme.gutter) {
                    ForEach(favorites) { DeviceTile(device: $0) }
                }
            }
            if !home.cameras.isEmpty { cameraStrip }

        case .all:
            ForEach(home.rooms) { room in
                RoomSection(room: room, columns: columns) { zone = .room(room.name) }
            }
            ForEach(matterOnlyRooms, id: \.self) { name in
                RoomSection(room: RoomGroup(name: name, devices: []), columns: columns) { zone = .room(name) }
            }
            if home.devices.isEmpty && matter.visibleEndpoints(home: home).isEmpty {
                ContentUnavailableView {
                    Label("Nog geen apparaten", systemImage: "lightbulb.slash")
                } description: {
                    Text("Voeg een HomeKit- of Matter-apparaat toe met de plusknop.")
                } actions: {
                    Button("Apparaat toevoegen") { home.addAccessory() }
                        .buttonStyle(.borderedProminent)
                }
            }
            if !home.cameras.isEmpty { cameraStrip }

        case .room(let name):
            if let room = home.rooms.first(where: { $0.name == name }) {
                RoomSection(room: room, columns: columns, onOpen: nil)
            } else if matterOnlyRooms.contains(name) {
                RoomSection(room: RoomGroup(name: name, devices: []), columns: columns, onOpen: nil)
            } else {
                Text("Deze kamer heeft geen apparaten.").foregroundStyle(Theme.textLight)
            }
        }
    }

    private var zoneTitle: String {
        switch zone {
        case .favorites, .all: return home.home?.name ?? "Thuis"
        case .room(let name): return name
        }
    }

    /// Kamers die alleen Matter-apparaten van Homio hebben (niet in Apple Woning).
    private var matterOnlyRooms: [String] {
        _ = matter.revision
        let homeKit = Set(home.rooms.map(\.name))
        return Array(Set(matter.visibleEndpoints(home: home).map(\.room)).subtracting(homeKit)).sorted()
    }

    private var favoriteDevices: [Device] {
        let ids = settings.activeProfile?.favoriteDeviceIDs ?? []
        return ids.compactMap { home.device(id: $0) }
    }

    private var cameraStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Camera's").font(.headline).foregroundStyle(Color.primary.opacity(0.7))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(home.cameras, id: \.uniqueIdentifier) { camera in
                        CameraStripItem(feed: home.feed(for: camera))
                    }
                }
            }
        }
    }
}

struct SceneEditTarget: Identifiable {
    let id = UUID()
    let scene: HMActionSet?
}

private struct CameraStripItem: View {
    let feed: CameraFeed
    @State private var live = false

    var body: some View {
        CameraTile(feed: feed)
            .frame(width: 280, height: 170)
            .onTapGesture { live = true }
            .fullScreenCover(isPresented: $live) { CameraLiveView(feed: feed).environment(\.colorScheme, .dark) }
    }
}

/// Kamer met kop (temperatuur, vocht, lampen) en een raster met apparaten.
private struct RoomSection: View {
    let room: RoomGroup
    let columns: [GridItem]
    let onOpen: (() -> Void)?

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var matter: MatterStore

    private var matterDevices: [MatterEndpoint] { matter.endpoints(inRoom: room.name, home: home) }

    private var temperature: Double? {
        let temps = room.devices.compactMap { $0.kind == .temperature || $0.kind == .thermostat ? $0.currentTemperature : nil }
        return temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)
    }

    private var humidity: Double? {
        room.devices.first { $0.kind == .humidity }?.number(HMCharacteristicTypeCurrentRelativeHumidity)
    }

    private var lightsOn: Int { room.devices.filter { $0.kind == .light && $0.isOn }.count }
    private var hasLights: Bool { room.devices.contains { $0.kind == .light } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Button {
                    onOpen?()
                } label: {
                    HStack(spacing: 6) {
                        Text(room.name).font(HomeyFont.large.weight(.bold))
                        if onOpen != nil {
                            Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textLight)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(onOpen == nil)

                if let t = temperature {
                    Label("\(t.oneDecimal)°", systemImage: "thermometer.medium")
                        .font(.subheadline)
                        .foregroundStyle(IconPalette.orange)
                }
                if let h = humidity {
                    Label("\(Int(h))%", systemImage: "humidity.fill")
                        .font(.subheadline)
                        .foregroundStyle(.cyan)
                }
                Spacer()
                if hasLights {
                    Button {
                        home.setLights(on: lightsOn == 0, room: room.name)
                    } label: {
                        Label(lightsOn == 0 ? "Lampen aan" : "Lampen uit",
                              systemImage: lightsOn == 0 ? "lightbulb.fill" : "lightbulb.slash")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(IconPalette.yellow)
                }
            }
            LazyVGrid(columns: columns, spacing: Theme.gutter) {
                ForEach(room.devices) { DeviceTile(device: $0) }
                ForEach(matterDevices) { MatterTile(endpoint: $0) }
            }
        }
    }
}

struct StatusChip: View {
    let symbol: String
    let text: String
    var color: Color = .white
    var multicolor = false

    var body: some View {
        Label {
            Text(text).font(.subheadline.weight(.semibold)).lineLimit(1)
        } icon: {
            if multicolor {
                Image(systemName: symbol).symbolRenderingMode(.multicolor)
            } else {
                Image(systemName: symbol).foregroundStyle(color)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .card()
    }
}

struct ZoneChip: View {
    let title: String
    let symbol: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(Capsule().fill(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.pill)))
        }
        .buttonStyle(PressableStyle())
    }
}
