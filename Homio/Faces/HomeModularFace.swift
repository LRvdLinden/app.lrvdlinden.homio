import SwiftUI

/// Je woning in één oogopslag: klok, weer, favoriete apparaten, scènes en een camera.
struct HomeModularFace: View {
    let openPanel: (AppPanel) -> Void

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var weather: WeatherService
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var compact: Bool { sizeClass == .compact }

    private var favorites: [Device] {
        let all = home.devices
        let ids = settings.activeProfile?.favoriteDeviceIDs ?? []
        let picked = ids.compactMap { id in all.first { $0.id == id } }
        return picked.isEmpty ? Array(all.prefix(6)) : picked
    }

    var body: some View {
        ZStack {
            AmbientBackground(intensity: 0.4)
            HomeStateGate {
                if compact { phoneLayout } else { padLayout }
            }
        }
        .foregroundStyle(.white)
        .onAppear { weather.start() }
    }

    // MARK: iPad: klokkolom links, apparaten rechts

    private var padLayout: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 18) {
                    AnalogClockView()
                        .padding(22)
                        .frame(maxWidth: .infinity)
                        .glassCard()
                    WeatherCard()
                    if let camera = home.cameras.first {
                        CameraTile(feed: home.feed(for: camera))
                            .frame(maxHeight: .infinity)
                            .onTapGesture { openPanel(.cameras) }
                    }
                }
                .frame(width: min(340, geo.size.width * 0.32))

                ScrollView {
                    deviceColumn
                }
                .scrollIndicators(.hidden)
            }
            .facePadding(false)
        }
    }

    // MARK: iPhone: alles onder elkaar

    private var phoneLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    AnalogClockView()
                        .padding(12)
                        .frame(width: 130, height: 130)
                        .glassCard()
                    WeatherCard(minHeight: 130)
                }
                deviceColumn
                if let camera = home.cameras.first {
                    CameraTile(feed: home.feed(for: camera))
                        .frame(height: 210)
                        .onTapGesture { openPanel(.cameras) }
                }
            }
            .facePadding(true)
        }
        .scrollIndicators(.hidden)
    }

    private var deviceColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(home.home?.name ?? "Woning")
                    .font(compact ? .title.bold() : .largeTitle.bold())
                    .lineLimit(1)
                Spacer()
                Button { openPanel(.home) } label: {
                    Label("Alles", systemImage: "square.grid.2x2")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
            }
            if !home.scenes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(home.scenes.prefix(6), id: \.uniqueIdentifier) { scene in
                            SceneChip(name: scene.name, symbol: scene.symbol) { home.run(scene) }
                        }
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 150 : 170), spacing: 14)], spacing: 14) {
                ForEach(favorites) { device in
                    DeviceTile(device: device, minHeight: compact ? 124 : 140)
                }
            }
            if favorites.isEmpty {
                Text("Voeg apparaten toe in Woning. Lang drukken op een apparaat en op de ster tikken maakt het een favoriet.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WeatherCard: View {
    var minHeight: CGFloat? = nil
    @EnvironmentObject private var weather: WeatherService

    var body: some View {
        HStack(spacing: 14) {
            if let current = weather.current {
                Image(systemName: WeatherService.symbol(for: current.code, isDay: current.isDay))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(current.temperature.rounded()))°")
                        .font(.system(size: 38, weight: .medium, design: .rounded))
                    Text(weather.place.isEmpty ? WeatherService.description(for: current.code) : weather.place)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "cloud.sun").font(.largeTitle)
                Text(weather.problem ?? "Weer laden…").font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .glassCard()
    }
}
