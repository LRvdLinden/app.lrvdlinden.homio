import SwiftUI

/// Soorten zonebediening zoals in Homey (Verlichting, Klimaat, Activiteit).
enum ZoneControlKind: String, Identifiable {
    case lights, climate, activity
    var id: String { rawValue }

    var title: String {
        switch self {
        case .lights: return "Verlichting"
        case .climate: return "Klimaat"
        case .activity: return "Activiteit"
        }
    }
}

/// Tegel bovenaan Thuis: gekleurd rondje met icoon, titel en waarde.
struct ZoneControlTile: View {
    let title: String
    let symbol: String
    let color: Color
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(color))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(HomeyFont.smallMedium).foregroundStyle(Theme.text).lineLimit(1)
                    Text(value).font(HomeyFont.tiny).foregroundStyle(Theme.textLight).lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(Theme.tilePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous).fill(Theme.card)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(title), \(value)")
    }
}

/// Blad met alle apparaten van één soort in de gekozen zone, zoals Homey's zonebediening.
struct ZoneControlSheet: View {
    let kind: ZoneControlKind
    let devices: [Device]
    let zoneName: String

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 74, maximum: 140), spacing: Theme.gutter)]

    private var matching: [Device] {
        switch kind {
        case .lights: return devices.filter { $0.kind == .light }
        case .climate: return devices.filter { [.thermostat, .heaterCooler, .temperature, .humidity, .fan, .airPurifier, .humidifier, .airQuality].contains($0.kind) }
        case .activity: return devices.filter { [.motion, .occupancy, .contact, .lock, .garage, .door, .window].contains($0.kind) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if kind == .lights, !matching.isEmpty {
                        let anyOn = matching.contains(where: \.isOn)
                        Button {
                            for light in matching { home.set(light, on: !anyOn) }
                        } label: {
                            Label(anyOn ? "Alle lampen uit" : "Alle lampen aan", systemImage: anyOn ? "lightbulb.slash" : "lightbulb.fill")
                                .font(HomeyFont.bodyMedium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Capsule().fill(anyOn ? AnyShapeStyle(Theme.card) : AnyShapeStyle(Theme.yellow)))
                                .foregroundStyle(anyOn ? Theme.text : Color.black)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    if matching.isEmpty {
                        Text("Geen apparaten voor \(kind.title.lowercased()) in \(zoneName).")
                            .foregroundStyle(Theme.textLight)
                    } else {
                        LazyVGrid(columns: columns, spacing: Theme.gutter) {
                            ForEach(matching) { DeviceTile(device: $0) }
                        }
                    }
                    if kind == .activity {
                        SectionHeading(title: "Laatst gebeurd", subtitle: nil)
                        let entries = history.log.filter { zoneName == (home.home?.name ?? "Thuis") || $0.room == zoneName }.prefix(15)
                        if entries.isEmpty {
                            Text("Nog niets gebeurd.").foregroundStyle(Theme.textLight)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(entries)) { entry in
                                HStack(spacing: 12) {
                                    Image(systemName: entry.symbol)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Theme.accent))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.title).font(HomeyFont.smallMedium).foregroundStyle(Theme.text)
                                        Text(entry.detail).font(HomeyFont.tiny).foregroundStyle(Theme.textLight)
                                    }
                                    Spacer()
                                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                                        .font(HomeyFont.tiny.monospacedDigit())
                                        .foregroundStyle(Theme.textLight)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.card))
                    }
                }
                .padding(Theme.edge)
            }
            .background(Theme.background)
            .navigationTitle("\(kind.title) · \(zoneName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Gereed") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
