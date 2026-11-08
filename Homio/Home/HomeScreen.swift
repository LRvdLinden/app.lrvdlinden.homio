import HomeKit
import SwiftUI

/// Thuis zoals in de Homey-app: begroeting met het weer, meldingen, favoriete apparaten,
/// sferen (moods), favoriete flows en een tijdlijn van wat er laatst gebeurde.
struct HomeTab: View {
    let startDisplay: () -> Void

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var weather: WeatherService
    @EnvironmentObject private var flows: FlowStore
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showSearch = false
    @State private var sceneEdit: SceneEditTarget?
    @State private var sceneToDelete: HMActionSet?
    @State private var showTimeline = false

    private var compact: Bool { sizeClass == .compact }
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 74 : 104, maximum: 140), spacing: Theme.gutter)]
    }

    var body: some View {
        NavigationStack {
            HomeStateGate {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        AttentionSection()
                        favoritesSection
                        moodsSection
                        favoriteFlowsSection
                        timelineSection
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
                    Button(action: startDisplay) { Image(systemName: "play.rectangle.fill") }
                        .accessibilityLabel("Weergavemodus")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSearch = true } label: { Image(systemName: "magnifyingglass") }
                        .accessibilityLabel("Zoeken")
                }
            }
            .sheet(isPresented: $showSearch) { SearchSheet() }
            .sheet(item: $sceneEdit) { target in SceneEditorView(scene: target.scene) }
            .sheet(isPresented: $showTimeline) {
                NavigationStack {
                    InsightsTab(embedded: true)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Gereed") { showTimeline = false } }
                        }
                }
            }
            .confirmationDialog("Sfeer verwijderen?",
                                isPresented: Binding(get: { sceneToDelete != nil }, set: { if !$0 { sceneToDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Verwijderen", role: .destructive) {
                    if let scene = sceneToDelete { Task { await FlowStore.shared.deleteScene(scene) } }
                    sceneToDelete = nil
                }
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
        var parts: [String] = []
        if let current = weather.current {
            parts.append("Het is \(Int(current.temperature.rounded()))° en \(WeatherService.description(for: current.code).lowercased())")
        }
        if let t = s.temperature { parts.append("binnen \(t.oneDecimal)°") }
        if s.lightsOn > 0 { parts.append(s.lightsOn == 1 ? "1 lamp aan" : "\(s.lightsOn) lampen aan") }
        let sentence = parts.isEmpty ? "Welkom thuis." : parts.joined(separator: ", ") + "."
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                ProfileAvatar(profile: settings.activeProfile, size: 40)
                Text(greeting).font(HomeyFont.xlarge).foregroundStyle(Theme.text)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
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

    // MARK: Favoriete apparaten

    private var favoritesSection: some View {
        let ids = settings.activeProfile?.favoriteDeviceIDs ?? []
        let favorites = ids.compactMap { home.device(id: $0) }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Favoriete apparaten", subtitle: nil)
            if favorites.isEmpty {
                Text("Houd een apparaat ingedrukt en kies Details › ster om het hier te zetten. Elk gezinslid heeft zijn eigen favorieten.")
                    .font(HomeyFont.small)
                    .foregroundStyle(Theme.textLight)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                LazyVGrid(columns: columns, spacing: Theme.gutter) {
                    ForEach(favorites) { DeviceTile(device: $0) }
                }
            }
        }
    }

    // MARK: Sferen (moods)

    private var moodsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Favoriete moods", subtitle: nil)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(home.scenes, id: \.uniqueIdentifier) { scene in
                    MoodCard(name: scene.name, detail: home.home?.name ?? "Thuis") { home.run(scene) }
                        .contextMenu {
                            Button { home.run(scene) } label: { Label("Starten", systemImage: "play.fill") }
                            Button { sceneEdit = SceneEditTarget(scene: scene) } label: { Label("Bewerken", systemImage: "pencil") }
                            if !scene.isBuiltIn {
                                Button(role: .destructive) { sceneToDelete = scene } label: { Label("Verwijderen", systemImage: "trash") }
                            }
                        }
                }
                Button { sceneEdit = SceneEditTarget(scene: nil) } label: {
                    Label("Nieuwe mood", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.addCardFill))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    // MARK: Favoriete flows

    @ViewBuilder
    private var favoriteFlowsSection: some View {
        let favorites = home.triggers.filter { flows.isFavorite($0) }
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Favoriete flows", subtitle: nil)
            if favorites.isEmpty {
                Text("Houd in Flows een flow ingedrukt en kies \"Aan favorieten\".")
                    .font(HomeyFont.small)
                    .foregroundStyle(Theme.textLight)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(favorites, id: \.uniqueIdentifier) { trigger in
                        HStack(spacing: 10) {
                            FlowRunButton(trigger: trigger, size: 30)
                            Text(trigger.name).font(.system(size: 15)).foregroundStyle(Theme.text).lineLimit(1)
                            Spacer(minLength: 4)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card)
                            .shadow(color: .black.opacity(0.06), radius: 2, y: 1))
                        .opacity(trigger.isEnabled ? 1 : 0.45)
                    }
                }
            }
        }
    }

    // MARK: Tijdlijn

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeading(title: "Tijdlijn", subtitle: nil)
                Spacer()
                Button("Alles bekijken") { showTimeline = true }
                    .font(HomeyFont.smallMedium)
                    .foregroundStyle(Theme.accent)
            }
            let entries = Array(history.log.prefix(6))
            if entries.isEmpty {
                Text("Hier zie je wat er in huis gebeurt: lampen, deuren, sloten en beweging.")
                    .font(HomeyFont.small)
                    .foregroundStyle(Theme.textLight)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entries.indices, id: \.self) { i in
                        let entry = entries[i]
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 0) {
                                Image(systemName: entry.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .background(Circle().fill(Theme.green))
                                if i < entries.count - 1 {
                                    Rectangle().fill(Theme.green.opacity(0.35)).frame(width: 2).frame(maxHeight: .infinity)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                (Text(entry.title).fontWeight(.bold) + Text(" " + entry.detail.lowercased())
                                    + Text(entry.room.isEmpty ? "" : " in \(entry.room)"))
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.text)
                                Text(entry.date.formatted(.relative(presentation: .named)))
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textLight)
                            }
                            .padding(.bottom, 18)
                        }
                    }
                }
            }
        }
    }
}
