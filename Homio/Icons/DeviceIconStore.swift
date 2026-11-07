import SwiftUI

/// Eigen icoon per apparaat (HomeKit-dienst of Matter-eindpunt), gesynchroniseerd via iCloud.
@MainActor
final class DeviceIconStore: ObservableObject {
    static let shared = DeviceIconStore()

    /// Sleutel = apparaat-ID als tekst, waarde = asset-naam ("dev-…" of "cbi-…").
    @Published private(set) var icons: [String: String] = [:]

    private let key = "homio.icons.v1"
    private let cloudKey = "icons"
    private var applyingRemote = false

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: key) as? [String: String] {
            icons = saved
        }
        CloudSync.shared.register(cloudKey, apply: { [weak self] data in
            guard let self, let remote = try? JSONDecoder().decode([String: String].self, from: data) else { return }
            self.applyingRemote = true
            self.icons = remote
            self.save()
            self.applyingRemote = false
        }, current: { [weak self] in
            guard let self else { return nil }
            return try? JSONEncoder().encode(self.icons)
        })
    }

    func icon(for id: String) -> String? { icons[id] }

    func set(_ icon: String?, for id: String) {
        icons[id] = icon
        save()
    }

    private func save() {
        UserDefaults.standard.set(icons, forKey: key)
        if !applyingRemote, let data = try? JSONEncoder().encode(icons) {
            CloudSync.shared.push(cloudKey, payload: data)
        }
    }
}

/// Alle kiesbare iconen: Homio's eigen set en de merk-iconen (custom-brand-icons, MIT).
enum IconCatalog {
    struct Item: Identifiable, Hashable {
        let asset: String
        let label: String
        var id: String { asset }
    }

    static let homio: [Item] = [
        ("light", "Lamp"), ("light-on", "Lamp aan"), ("plug", "Stekker"), ("switch", "Schakelaar"),
        ("thermostat", "Thermostaat"), ("lock-closed", "Slot"), ("blinds-closed", "Gordijn"),
        ("fan", "Ventilator"), ("garage-closed", "Garage"), ("window", "Raam"), ("door-closed", "Deur"),
        ("purifier", "Luchtreiniger"), ("heater", "Verwarming"), ("humidifier", "Bevochtiger"),
        ("valve", "Kraan"), ("security", "Beveiliging"), ("thermometer", "Temperatuur"),
        ("humidity", "Vochtigheid"), ("motion", "Beweging"), ("occupancy", "Aanwezigheid"),
        ("smoke", "Rook"), ("co", "CO"), ("leak", "Lekkage"), ("lux", "Licht"), ("air", "Lucht"),
        ("speaker", "Speaker"), ("tv", "Tv"), ("vacuum", "Robotstofzuiger"), ("appliance", "Apparaat"),
        ("energy", "Energie"), ("sensor", "Sensor"), ("device", "Overig")
    ].map { Item(asset: "dev-" + $0.0, label: $0.1) }

    static let brands: [Item] = {
        guard let url = Bundle.main.url(forResource: "BrandIcons", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([[String]].self, from: data) else { return [] }
        return rows.compactMap { $0.count == 2 ? Item(asset: $0[0], label: $0[1]) : nil }
    }()
}

/// Icoonkiezer met zoeken: eerst Homio's eigen iconen, daarna alle merk-iconen.
struct IconPickerView: View {
    let title: String
    let current: String
    let onPick: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 12)]

    private func filter(_ items: [IconCatalog.Item]) -> [IconCatalog.Item] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { $0.label.lowercased().contains(q) || $0.asset.contains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                    let own = filter(IconCatalog.homio)
                    if !own.isEmpty {
                        section("Homio", own)
                    }
                    let brands = filter(IconCatalog.brands)
                    if !brands.isEmpty {
                        section("Merken en apparaten", brands)
                        Text("Merk-iconen: custom-brand-icons door elax46 (MIT). Merknamen en logo's zijn van hun eigenaars.")
                            .font(HomeyFont.extraTiny)
                            .foregroundStyle(Theme.textLight)
                    }
                    if own.isEmpty && brands.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .padding(Theme.edge)
            }
            .background(Theme.background)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Zoek een icoon")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Standaard") {
                        onPick(nil)
                        dismiss()
                    }
                }
            }
        }
    }

    private func section(_ title: LocalizedStringKey, _ items: [IconCatalog.Item]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(HomeyFont.smallMedium).foregroundStyle(Theme.textLight)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    Button {
                        onPick(item.asset)
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Image(item.asset)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(item.asset == current ? Color.white : Theme.text)
                                .frame(width: 56, height: 56)
                                .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                                    .fill(item.asset == current ? Theme.accent : Theme.card))
                            Text(item.label)
                                .font(HomeyFont.extraTiny)
                                .foregroundStyle(Theme.textLight)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.label)
                }
            }
        }
    }
}
