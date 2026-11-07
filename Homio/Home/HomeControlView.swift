import HomeKit
import SwiftUI

/// De "Woning"-app: scènes en alle apparaten per kamer.
struct HomeControlView: View {
    @EnvironmentObject private var home: HomeStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(intensity: 0.45)
                HomeStateGate {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            SummaryRow()
                            if !home.scenes.isEmpty {
                                SectionTitle("Scènes")
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(home.scenes, id: \.uniqueIdentifier) { scene in
                                            SceneChip(name: scene.name, symbol: scene.symbol) { home.run(scene) }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            ForEach(home.rooms) { room in
                                SectionTitle(room.name)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .compact ? 150 : 175), spacing: 14)], spacing: 14) {
                                    ForEach(room.devices) { device in
                                        DeviceTile(device: device)
                                    }
                                }
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
                        }
                        .padding(sizeClass == .compact ? 16 : 28)
                    }
                }
            }
            .navigationTitle(home.home?.name ?? "Woning")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sluiten") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
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
                    Button { home.addAccessory() } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Apparaat toevoegen")
                }
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
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
    }
}

/// Bovenaan: hoeveel lampen aan, temperatuur, sloten, deuren/ramen.
private struct SummaryRow: View {
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        let s = home.summary
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let t = s.temperature {
                    chip("thermometer.medium", "\(t.oneDecimal)°", .orange)
                }
                chip("lightbulb.fill", s.lightsOn == 1 ? "1 lamp aan" : "\(s.lightsOn) lampen aan", Theme.amber)
                if s.openLocks > 0 {
                    chip("lock.open.fill", s.openLocks == 1 ? "1 slot open" : "\(s.openLocks) sloten open", .blue)
                }
                if s.openContacts > 0 {
                    chip("door.left.hand.open", "\(s.openContacts) open", .teal)
                }
            }
        }
    }

    private func chip(_ symbol: String, _ text: String, _ color: Color) -> some View {
        Label {
            Text(text).font(.subheadline.weight(.semibold))
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard()
    }
}

/// Toont toestemming, laden of "geen woning" voordat de inhoud verschijnt.
struct HomeStateGate<Content: View>: View {
    @EnvironmentObject private var home: HomeStore
    @ViewBuilder var content: () -> Content
    @State private var newHomeName = "Thuis"

    var body: some View {
        if home.isDenied {
            ContentUnavailableView {
                Label("Geen toegang tot Woning", systemImage: "house.slash")
            } description: {
                Text("Geef Homio toegang in Instellingen › Privacy en beveiliging › Woning-gegevens.")
            } actions: {
                Button("Open Instellingen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if !home.isReady {
            ProgressView("Woning laden…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if home.homes.isEmpty {
            ContentUnavailableView {
                Label("Nog geen woning", systemImage: "house")
            } description: {
                Text("Maak een woning aan om apparaten toe te voegen.")
            } actions: {
                TextField("Naam", text: $newHomeName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                Button("Woning aanmaken") { home.createHome(named: newHomeName) }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            content()
        }
    }
}

/// De "Camera's"-app: raster met tot negen camera's, tik voor live.
struct CamerasView: View {
    @EnvironmentObject private var home: HomeStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                HomeStateGate {
                    CameraGrid(maxCount: 9)
                        .padding(20)
                }
            }
            .navigationTitle("Camera's")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sluiten") { dismiss() }
                }
            }
        }
    }
}

struct CameraGrid: View {
    var maxCount: Int = 9
    @EnvironmentObject private var home: HomeStore
    @State private var live: CameraFeed?

    var body: some View {
        let cams = Array(home.cameras.prefix(maxCount))
        Group {
            if cams.isEmpty {
                ContentUnavailableView("Geen camera's",
                                       systemImage: "video.slash",
                                       description: Text("Camera's die in Apple Woning staan, verschijnen hier vanzelf."))
            } else {
                GeometryReader { geo in
                    let columns = cams.count == 1 ? 1 : (cams.count <= 4 ? 2 : 3)
                    let rows = Int(ceil(Double(cams.count) / Double(columns)))
                    let spacing: CGFloat = 12
                    let height = (geo.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                              spacing: spacing) {
                        ForEach(cams, id: \.uniqueIdentifier) { accessory in
                            let feed = home.feed(for: accessory)
                            CameraTile(feed: feed)
                                .frame(height: max(120, height))
                                .onTapGesture { live = feed }
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $live) { feed in
            CameraLiveView(feed: feed)
                .environment(\.colorScheme, .dark)
        }
    }
}

extension CameraFeed: Identifiable {
    var id: UUID { accessory.uniqueIdentifier }
}
