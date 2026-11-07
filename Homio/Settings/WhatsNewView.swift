import SwiftUI

/// Wat is er nieuw in deze versie.
struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    private let items: [(String, Color, LocalizedStringKey, LocalizedStringKey)] = [
        ("paintpalette.fill", Theme.accent, "Nieuw uiterlijk", "Rustige kaarten, heldere kleuren en een licht en donker thema."),
        ("sparkles", Theme.orange, "Welkomstschermen", "Een korte rondleiding langs alles wat Homio kan."),
        ("arrow.triangle.branch", IconPalette.orange, "Flows", "Als, En, Dan: met aanwezigheid, donker en een timer om weer uit te zetten."),
        ("square.grid.2x2.fill", Theme.green, "Groepen en dashboards", "Bundel lampen in groepen en zet ze op je eigen dashboards."),
        ("icloud.fill", Color.teal, "iCloud-sync", "Dashboards, flows, groepen en meldingen op al je apparaten.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(items.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: items[i].0)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(items[i].1))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(items[i].2).font(HomeyFont.bodyBold)
                                Text(items[i].3).font(HomeyFont.small).foregroundStyle(Theme.textLight)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Theme.background)
            .navigationTitle("Wat is nieuw")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gereed") { dismiss() }
                }
            }
        }
    }
}
