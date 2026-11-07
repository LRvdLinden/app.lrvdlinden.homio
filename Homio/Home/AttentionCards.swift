import HomeKit
import SwiftUI

/// Iets in huis dat aandacht vraagt, met waar mogelijk één tik om het op te lossen.
struct AttentionItem: Identifiable {
    let id: String
    let symbol: String
    let color: Color
    let title: String
    let detail: String
    var actionTitle: String?
    var action: (@MainActor () -> Void)?
}

@MainActor
enum AttentionBuilder {
    static func items(home: HomeStore, now: Date = Date()) -> [AttentionItem] {
        var items: [AttentionItem] = []
        let devices = home.devices
        let hour = Calendar.current.component(.hour, from: now)
        let isNight = hour >= 23 || hour < 6

        for d in devices where d.kind == .contact && d.isOn {
            items.append(AttentionItem(id: "open-\(d.id)", symbol: "door.left.hand.open", color: .teal,
                                       title: "\(d.name) staat open", detail: d.roomName))
        }
        for d in devices where d.kind == .garage && d.isOn {
            items.append(AttentionItem(id: "garage-\(d.id)", symbol: "door.garage.open", color: .indigo,
                                       title: "\(d.name) staat open", detail: d.roomName,
                                       actionTitle: "Sluiten", action: { home.set(d, on: false) }))
        }
        for d in devices where d.kind == .lock && !d.isOn && d.isReachable {
            items.append(AttentionItem(id: "lock-\(d.id)", symbol: "lock.open.fill", color: IconPalette.blue,
                                       title: "\(d.name) is niet op slot",
                                       detail: isNight ? "Het is nacht" : d.roomName,
                                       actionTitle: "Op slot", action: { home.set(d, on: true) }))
        }

        let lightsOn = devices.filter { $0.kind == .light && $0.isOn }
        if isNight && !lightsOn.isEmpty {
            let rooms = Set(lightsOn.map(\.roomName)).sorted().prefix(3).joined(separator: ", ")
            items.append(AttentionItem(id: "night-lights", symbol: "lightbulb.fill", color: IconPalette.yellow,
                                       title: lightsOn.count == 1 ? "Er brandt nog 1 lamp" : "Er branden nog \(lightsOn.count) lampen",
                                       detail: rooms,
                                       actionTitle: "Alles uit", action: { home.setLights(on: false, room: nil) }))
        }

        for d in devices where d.kind == .humidity {
            if let h = d.number(HMCharacteristicTypeCurrentRelativeHumidity), h >= 70 {
                items.append(AttentionItem(id: "humid-\(d.id)", symbol: "humidity.fill", color: .cyan,
                                           title: "Vochtig in \(d.roomName): \(Int(h))%",
                                           detail: "Even ventileren helpt tegen schimmel."))
            }
        }

        let health = home.health
        for h in health where h.lowBattery {
            items.append(AttentionItem(id: "battery-\(h.id)", symbol: "battery.25percent", color: .red,
                                       title: "Batterij bijna leeg: \(h.name)",
                                       detail: h.battery.map { "\(Int($0))% · \(h.room)" } ?? h.room))
        }
        let unreachable = health.filter { !$0.reachable }
        if !unreachable.isEmpty {
            items.append(AttentionItem(id: "unreachable", symbol: "wifi.exclamationmark", color: IconPalette.orange,
                                       title: unreachable.count == 1 ? "1 apparaat reageert niet" : "\(unreachable.count) apparaten reageren niet",
                                       detail: unreachable.prefix(3).map(\.name).joined(separator: ", ")))
        }
        return items
    }
}

/// Kaarten bovenaan Thuis. Wegvegen verbergt een kaart tot de situatie verandert.
struct AttentionSection: View {
    @EnvironmentObject private var home: HomeStore
    @State private var hidden: Set<String> = []

    var body: some View {
        let items = AttentionBuilder.items(home: home).filter { !hidden.contains($0.id) }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Aandacht").font(.headline).foregroundStyle(.white.opacity(0.7))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            AttentionCard(item: item) {
                                withAnimation(.spring(response: 0.35)) { _ = hidden.insert(item.id) }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct AttentionCard: View {
    let item: AttentionItem
    let onHide: () -> Void
    @State private var done = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: item.symbol)
                    .font(.title3)
                    .foregroundStyle(item.color)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(item.color.opacity(0.18)))
                Spacer()
                Button(action: onHide) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Verberg")
            }
            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Spacer(minLength: 0)
            if let title = item.actionTitle, let action = item.action {
                Button {
                    action()
                    done.toggle()
                } label: {
                    Text(title).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(item.color)
                .sensoryFeedback(.success, trigger: done)
            }
        }
        .padding(14)
        .frame(width: 220, height: 170, alignment: .topLeading)
        .card()
        .foregroundStyle(.white)
    }
}
