import SwiftUI

/// Kies een widget om aan het dashboard toe te voegen.
struct WidgetPickerSheet: View {
    let onPick: (DashWidget) -> Void

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var groups: GroupStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private func matches(_ text: String) -> Bool {
        search.isEmpty || text.localizedCaseInsensitiveContains(search)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Algemeen") {
                    ForEach([WidgetKind.clock, .weather, .timers, .calendar, .flows, .note], id: \.self) { kind in
                        if matches(kind.title) {
                            row(kind.title, kind.symbol) { DashWidget(kind: kind, size: kind.defaultSize) }
                        }
                    }
                }

                Section("Kamers") {
                    if matches("Hele huis") {
                        row("Hele huis", "house.fill") { DashWidget(kind: .room, size: .wide) }
                    }
                    ForEach(home.rooms) { room in
                        if matches(room.name) {
                            row(room.name, "square.split.bottomrightquarter.fill") {
                                DashWidget(kind: .room, size: .wide, roomName: room.name)
                            }
                        }
                    }
                }

                if !groups.groups.isEmpty {
                    Section("Groepen") {
                        ForEach(groups.groups) { group in
                            if matches(group.name) {
                                row(group.name, group.symbol) {
                                    DashWidget(kind: .group, size: .small, groupID: group.id)
                                }
                            }
                        }
                    }
                }

                if !home.scenes.isEmpty {
                    Section("Sferen") {
                        ForEach(home.scenes, id: \.uniqueIdentifier) { scene in
                            if matches(scene.name) {
                                row(scene.name, scene.symbol) {
                                    DashWidget(kind: .scene, size: .small, sceneID: scene.uniqueIdentifier)
                                }
                            }
                        }
                    }
                }

                Section("Apparaten") {
                    ForEach(home.devices) { device in
                        if matches(device.name) || matches(device.roomName) {
                            row(device.name, device.symbol, subtitle: device.roomName) {
                                DashWidget(kind: .device, size: .small, deviceID: device.id)
                            }
                        }
                    }
                }

                if !home.cameras.isEmpty {
                    Section("Camera's") {
                        ForEach(home.cameras, id: \.uniqueIdentifier) { camera in
                            if matches(camera.name) {
                                row(camera.name, "video.fill") {
                                    DashWidget(kind: .camera, size: .large, cameraID: camera.uniqueIdentifier)
                                }
                            }
                        }
                    }
                }

                Section {
                    if history.sortedMetrics.isEmpty {
                        Text("Grafieken verschijnen zodra Homio de eerste metingen heeft verzameld.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(history.sortedMetrics) { metric in
                        if matches(metric.name) {
                            row(metric.name, metric.kind.symbol, subtitle: "\(metric.kind.title) · \(metric.room)") {
                                DashWidget(kind: .chart, size: .wide, metricKey: metric.key)
                            }
                        }
                    }
                } header: {
                    Text("Grafieken")
                }
            }
            .searchable(text: $search, prompt: "Zoek widgets")
            .navigationTitle("Widget toevoegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ symbol: String, subtitle: String? = nil,
                     make: @escaping () -> DashWidget) -> some View {
        Button {
            onPick(make())
            dismiss()
        } label: {
            HStack(spacing: 14) {
                GradientIcon(symbol: symbol, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle.fill").foregroundStyle(IconPalette.orange)
            }
        }
    }
}
