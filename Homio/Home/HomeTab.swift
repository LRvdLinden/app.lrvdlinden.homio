import HomeKit
import SwiftUI

/// Het Thuis-tabblad: begroeting, status, zones (favorieten, alles, kamers), sferen en apparaten.
struct HomeTab: View {
    let startDisplay: () -> Void

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var weather: WeatherService
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var zone: Zone = .favorites
    @State private var sceneEdit: SceneEditTarget?
    @State private var sceneToDelete: HMActionSet?
    @State private var showSearch = false

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
                        scenesRow
                        if zone == .favorites || zone == .all {
                            GroupsSection(columns: columns)
                        }
                        zoneContent
                    }
                    .padding(.horizontal, compact ? 16 : 28)
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
                            Label("Apparaat toevoegen", systemImage: "plus.circle")
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

    private var header: some View {
        let s = home.summary
        return VStack(alignment: .leading, spacing: 12) {
            Text(greeting)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.85))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let current = weather.current {
                        StatusChip(symbol: WeatherService.symbol(for: current.code, isDay: current.isDay),
                                   text: "\(Int(current.temperature.rounded()))° buiten",
                                   color: .white, multicolor: true)
                    }
                    if let t = s.temperature {
                        StatusChip(symbol: "thermometer.medium", text: "\(t.oneDecimal)° binnen", color: IconPalette.orange)
                    }
                    StatusChip(symbol: "lightbulb.fill",
                               text: s.lightsOn == 1 ? "1 lamp aan" : "\(s.lightsOn) lampen aan",
                               color: IconPalette.yellow)
                    if s.openLocks > 0 {
                        StatusChip(symbol: "lock.open.fill",
                                   text: s.openLocks == 1 ? "1 slot open" : "\(s.openLocks) sloten open",
                                   color: IconPalette.blue)
                    }
                    if s.openContacts > 0 {
                        StatusChip(symbol: "door.left.hand.open", text: "\(s.openContacts) open", color: .teal)
                    }
                }
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
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: zone)
    }

    // MARK: Sferen

    private var scenesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sferen").font(.headline).foregroundStyle(Color.primary.opacity(0.7))
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
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            )
                    }
                    .buttonStyle(PressableStyle())
                    .foregroundStyle(Color.primary.opacity(0.8))
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Inhoud per zone

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 104 : 150), spacing: compact ? 10 : 12)]
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
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(favorites) { DeviceTile(device: $0) }
                }
            }
            if !home.cameras.isEmpty { cameraStrip }

        case .all:
            ForEach(home.rooms) { room in
                RoomSection(room: room, columns: columns) { zone = .room(room.name) }
            }
            if home.devices.isEmpty {
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
            } else {
                Text("Deze kamer heeft geen apparaten.").foregroundStyle(Theme.textLight)
            }
        }
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
                        Text(room.name).font(.title2.weight(.bold))
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
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(room.devices) { DeviceTile(device: $0) }
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
