import SwiftUI

/// Zonekaart zoals in Homey: gekleurd glyph-icoon, titel vet, waarde grijs.
struct ZoneCard: View {
    let title: String
    let symbol: String
    let color: Color
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.text)
                    Text(value).font(.system(size: 12.5)).foregroundStyle(Theme.textLight).lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.card)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(title), \(value)")
    }
}

/// Mood (sfeer) zoals in Homey: rond warm verloop, naam vet, aantal apparaten grijs.
struct MoodCard: View {
    let name: String
    let detail: String
    let action: () -> Void
    @State private var fired = 0

    var body: some View {
        Button {
            action()
            fired += 1
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.93, blue: 0.62), Color(red: 0.98, green: 0.78, blue: 0.27)],
                                         center: .topLeading, startRadius: 2, endRadius: 40))
                    .frame(width: 26, height: 26)
                    .symbolEffect(.bounce, value: fired)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text(detail).font(.system(size: 11)).foregroundStyle(Theme.textLight).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.card)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.success, trigger: fired)
    }
}

/// Icoon bij een kamernaam (op basis van woorden in de naam).
enum RoomIcon {
    static func symbol(for name: String) -> String {
        let n = name.lowercased()
        let map: [(String, String)] = [
            ("woon", "sofa.fill"), ("living", "sofa.fill"), ("keuken", "frying.pan.fill"), ("kitchen", "frying.pan.fill"),
            ("slaap", "bed.double.fill"), ("bed", "bed.double.fill"), ("bad", "bathtub.fill"), ("douche", "shower.fill"),
            ("toilet", "toilet.fill"), ("wc", "toilet.fill"), ("hal", "door.left.hand.closed"), ("entree", "door.left.hand.closed"),
            ("gang", "door.left.hand.closed"), ("tuin", "tree.fill"), ("garden", "tree.fill"), ("garage", "car.fill"),
            ("oprit", "car.fill"), ("kantoor", "desktopcomputer"), ("werk", "desktopcomputer"), ("office", "desktopcomputer"),
            ("zolder", "house.lodge.fill"), ("berging", "shippingbox.fill"), ("schuur", "shippingbox.fill"),
            ("meterkast", "bolt.fill"), ("was", "washer.fill"), ("kinder", "teddybear.fill"), ("speel", "gamecontroller.fill"),
            ("eet", "fork.knife"), ("terras", "sun.max.fill"), ("balkon", "sun.max.fill")
        ]
        return map.first { n.contains($0.0) }?.1 ?? "square.split.bottomrightquarter.fill"
    }
}
