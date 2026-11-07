import HomeKit
import SwiftUI

/// Zoek door apparaten, groepen, sferen en flows, en bedien ze meteen.
struct SearchSheet: View {
    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var groups: GroupStore
    @EnvironmentObject private var flows: FlowStore
    @EnvironmentObject private var matter: MatterStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var detail: UUID?
    @State private var matterDetail: String?

    private func matches(_ texts: String...) -> Bool {
        query.isEmpty || texts.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                let devices = home.devices.filter { matches($0.name, $0.roomName) }
                if !devices.isEmpty {
                    Section("Apparaten") {
                        ForEach(devices) { device in
                            HStack(spacing: 12) {
                                Button { detail = device.id } label: {
                                    HStack(spacing: 12) {
                                        DeviceIcon(device: device, size: 22)
                                            .foregroundStyle(device.isOn ? device.tint : Color.secondary)
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(device.name).foregroundStyle(.primary)
                                            Text("\(device.roomName) · \(device.stateText)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                if device.isToggleable {
                                    Toggle(device.name, isOn: Binding(
                                        get: { device.isOn },
                                        set: { home.set(device, on: $0) }
                                    ))
                                    .labelsHidden()
                                    .tint(IconPalette.orange)
                                }
                            }
                        }
                    }
                }

                let matterMatches = matter.visibleEndpoints(home: home).filter { matches($0.name, $0.room) }
                if !matterMatches.isEmpty {
                    Section("Matter (Homio)") {
                        ForEach(matterMatches) { e in
                            let st = matter.state(e)
                            let on = matter.isOn(e, st)
                            HStack(spacing: 12) {
                                Button { matterDetail = e.id } label: {
                                    HStack(spacing: 12) {
                                        DeviceIcon(key: e.id, fallback: e.kind.iconName(isOn: on), size: 22)
                                            .foregroundStyle(on ? e.kind.tint : Color.secondary)
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(e.name).foregroundStyle(.primary)
                                            Text("\(e.room) · \(matter.stateText(e, st))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                if matter.isToggleable(e, st) {
                                    Toggle(e.name, isOn: Binding(get: { on }, set: { matter.setOn(e, $0) }))
                                        .labelsHidden()
                                        .tint(IconPalette.orange)
                                }
                            }
                        }
                    }
                }

                let groupMatches = groups.groups.filter { matches($0.name) }
                if !groupMatches.isEmpty {
                    Section("Groepen") {
                        ForEach(groupMatches) { group in
                            let state = GroupState(group: group, home: home)
                            Button { state.toggle(home) } label: {
                                Label {
                                    HStack {
                                        Text(group.name).foregroundStyle(.primary)
                                        Spacer()
                                        Text(state.stateText).font(.caption).foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: group.symbol).foregroundStyle(IconPalette.orange)
                                }
                            }
                        }
                    }
                }

                let scenes = home.scenes.filter { matches($0.name) }
                if !scenes.isEmpty {
                    Section("Sferen") {
                        ForEach(scenes, id: \.uniqueIdentifier) { scene in
                            Button { home.run(scene) } label: {
                                Label(scene.name, systemImage: scene.symbol)
                            }
                        }
                    }
                }

                let triggers = home.triggers.filter { matches($0.name) }
                if !triggers.isEmpty {
                    Section("Flows") {
                        ForEach(triggers, id: \.uniqueIdentifier) { trigger in
                            Button { flows.run(trigger) } label: {
                                Label {
                                    HStack {
                                        Text(trigger.name).foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "play.fill").foregroundStyle(IconPalette.blue)
                                    }
                                } icon: {
                                    Image(systemName: "arrow.triangle.branch").foregroundStyle(IconPalette.blue)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Zoek in je huis")
            .navigationTitle("Zoeken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gereed") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { detail.map { IdentifiedUUID(id: $0) } },
                set: { detail = $0?.id }
            )) { item in
                DeviceDetailSheet(deviceID: item.id)
            }
            .sheet(item: Binding(
                get: { matterDetail.map { IdentifiedString(id: $0) } },
                set: { matterDetail = $0?.id }
            )) { item in
                MatterDetailSheet(endpointID: item.id)
            }
        }
    }
}

struct IdentifiedUUID: Identifiable {
    let id: UUID
}

struct IdentifiedString: Identifiable {
    let id: String
}
