import SwiftUI

/// Tegel voor een groep. Tik = alles aan/uit, lang drukken = details.
struct GroupTile: View {
    let group: DeviceGroup
    var minHeight: CGFloat = 132
    var fillsHeight = false

    @EnvironmentObject private var home: HomeStore
    @State private var showDetail = false
    @State private var pressing = false

    var body: some View {
        let state = GroupState(group: group, home: home)
        let on = state.isOn
        VStack(alignment: .leading, spacing: Theme.su * 1.5) {
            HStack(alignment: .top) {
                Image(systemName: group.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(on ? Color.white : Color.secondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(on ? AnyShapeStyle(Theme.orange.gradient) : AnyShapeStyle(Theme.pill)))
                Spacer()
                Text("\(state.members.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textLight)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.pill))
            }
            Spacer(minLength: Theme.su)
            Text(group.name).font(HomeyFont.bodyMedium).lineLimit(2)
            Text(state.stateText)
                .font(HomeyFont.small)
                .foregroundStyle(on ? Theme.orange : Color.secondary)
                .lineLimit(1)
        }
        .foregroundStyle(.primary)
        .padding(Theme.su * 4)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                    .fill(Theme.orange.opacity(on ? 0.12 : 0)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                .strokeBorder(on ? Theme.orange.opacity(0.5) : Theme.line, lineWidth: 1)
        }
        .scaleEffect(pressing ? 0.95 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressing)
        .animation(.easeInOut(duration: 0.25), value: on)
        .contentShape(RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous))
        .onTapGesture { state.toggle(home) }
        .onLongPressGesture(minimumDuration: 0.4, perform: {
            showDetail = true
        }, onPressingChanged: { pressing = $0 })
        .sensoryFeedback(.impact(weight: .light), trigger: on)
        .sheet(isPresented: $showDetail) {
            GroupDetailSheet(groupID: group.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Groep bedienen: alles aan/uit, helderheid voor alle lampen, en elk lid apart.
struct GroupDetailSheet: View {
    let groupID: UUID

    @EnvironmentObject private var groups: GroupStore
    @EnvironmentObject private var home: HomeStore
    @Environment(\.dismiss) private var dismiss
    @State private var level: Double = 0
    @State private var editing = false

    var body: some View {
        NavigationStack {
            Group {
                if let group = groups.group(id: groupID) {
                    content(group)
                } else {
                    ContentUnavailableView("Groep niet gevonden", systemImage: "questionmark.circle")
                }
            }
            .background(Theme.background)
            .navigationTitle(groups.group(id: groupID)?.name ?? "Groep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Bewerk") { editing = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gereed") { dismiss() }
                }
            }
            .sheet(isPresented: $editing) {
                if let group = groups.group(id: groupID) {
                    GroupEditorView(initial: group)
                }
            }
        }
        .presentationBackground(Theme.background)
    }

    private func content(_ group: DeviceGroup) -> some View {
        let state = GroupState(group: group, home: home)
        return ScrollView {
            VStack(spacing: 26) {
                Button { state.toggle(home) } label: {
                    Image(systemName: "power")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(state.isOn ? Color.white : Color.primary)
                        .frame(width: 150, height: 150)
                        .background(Circle().fill(state.isOn ? AnyShapeStyle(IconPalette.orange) : AnyShapeStyle(Color.primary.opacity(0.12))))
                }
                .buttonStyle(PressableStyle())
                .sensoryFeedback(.impact(weight: .medium), trigger: state.isOn)

                Text(state.stateText).font(.title3.weight(.semibold))

                if !state.lights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Helderheid van alle lampen", systemImage: "sun.max.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(IconPalette.yellow)
                        Slider(value: $level, in: 0...100, step: 1) { editing in
                            if !editing { state.setBrightness(Int(level), home) }
                        }
                        .tint(IconPalette.yellow)
                        Text(level > 0 ? "\(Int(level))%" : "Uit")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textLight)
                    }
                    .padding(16)
                    .card()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(state.members) { DeviceTile(device: $0, minHeight: 120) }
                }
            }
            .padding(20)
        }
        .onAppear { level = state.averageBrightness ?? 0 }
    }
}

/// Groep maken of bewerken.
struct GroupEditorView: View {
    @EnvironmentObject private var groups: GroupStore
    @EnvironmentObject private var home: HomeStore
    @Environment(\.dismiss) private var dismiss

    @State private var group: DeviceGroup
    @State private var search = ""
    private let isNew: Bool

    init(initial: DeviceGroup?) {
        isNew = initial == nil
        _group = State(initialValue: initial ?? DeviceGroup(name: "", symbol: DeviceGroup.symbols[0], deviceIDs: []))
    }

    private var candidates: [Device] {
        home.devices.filter { $0.isToggleable && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.roomName.localizedCaseInsensitiveContains(search)) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Naam (bijv. Plafondlampen)", text: $group.name)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(DeviceGroup.symbols, id: \.self) { symbol in
                                Button { group.symbol = symbol } label: {
                                    Image(systemName: symbol)
                                        .font(.title3)
                                        .frame(width: 44, height: 44)
                                        .background(Circle().fill(group.symbol == symbol ? IconPalette.orange : Color.primary.opacity(0.1)))
                                        .foregroundStyle(group.symbol == symbol ? Color.white : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    ForEach(candidates) { device in
                        let selected = group.deviceIDs.contains(device.id)
                        Button {
                            if selected {
                                group.deviceIDs.removeAll { $0 == device.id }
                            } else {
                                group.deviceIDs.append(device.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: device.symbol)
                                    .foregroundStyle(device.tint)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(device.name).foregroundStyle(.primary)
                                    Text(device.roomName).font(.caption).foregroundStyle(Theme.textLight)
                                }
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected ? IconPalette.orange : Color.secondary)
                                    .font(.title3)
                            }
                        }
                    }
                } header: {
                    Text("Apparaten (\(group.deviceIDs.count))")
                }

                if !isNew {
                    Section {
                        Button("Groep verwijderen", role: .destructive) {
                            groups.delete(group.id)
                            dismiss()
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Zoek apparaat of kamer")
            .navigationTitle(isNew ? "Nieuwe groep" : "Groep bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        var saved = group
                        if saved.name.trimmingCharacters(in: .whitespaces).isEmpty { saved.name = "Groep" }
                        groups.upsert(saved)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(group.deviceIDs.isEmpty)
                }
            }
        }
    }
}

/// Groepen-sectie op het Thuis-tabblad.
struct GroupsSection: View {
    let columns: [GridItem]
    @EnvironmentObject private var groups: GroupStore
    @State private var creating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Groepen").font(.headline).foregroundStyle(Color.primary.opacity(0.7))
                Spacer()
                Button { creating = true } label: {
                    Label("Nieuwe groep", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
            if groups.groups.isEmpty {
                Text("Bundel lampen of stekkers uit verschillende kamers tot één knop, bijv. \"Alle buitenlampen\".")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textLight)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(groups.groups) { GroupTile(group: $0) }
                }
            }
        }
        .sheet(isPresented: $creating) {
            GroupEditorView(initial: nil)
        }
    }
}
