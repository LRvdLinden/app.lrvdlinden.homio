import HomeKit
import SwiftUI

/// Naam, kamer, info en verwijderen van een apparaat.
struct DeviceManageView: View {
    let deviceID: UUID

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var loaded = false
    @State private var newRoom = ""
    @State private var showNewRoom = false
    @State private var confirmRemove = false

    var body: some View {
        Group {
            if let device = home.device(id: deviceID) {
                form(device)
            } else {
                ContentUnavailableView("Apparaat niet gevonden", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle("Beheren")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func form(_ device: Device) -> some View {
        let health = home.health.first { $0.id == device.accessory.uniqueIdentifier }
        return Form {
            Section("Naam") {
                TextField("Naam", text: $name)
                    .submitLabel(.done)
                    .onSubmit { home.rename(device, to: name) }
                if name != device.name && !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Naam bewaren") { home.rename(device, to: name) }
                }
            }

            Section("Kamer") {
                Picker("Kamer", selection: Binding(
                    get: { device.accessory.room?.uniqueIdentifier },
                    set: { id in
                        if let room = home.allRooms.first(where: { $0.uniqueIdentifier == id }) {
                            home.move(device, to: room)
                        }
                    }
                )) {
                    ForEach(home.allRooms, id: \.uniqueIdentifier) { room in
                        Text(room.name).tag(Optional(room.uniqueIdentifier))
                    }
                }
                Button {
                    newRoom = ""
                    showNewRoom = true
                } label: {
                    Label("Nieuwe kamer…", systemImage: "plus")
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { settings.isFavorite(deviceID) },
                    set: { _ in settings.toggleFavorite(deviceID) }
                )) {
                    Label("Favoriet", systemImage: "star.fill")
                }
            }

            Section("Info") {
                LabeledContent("Status", value: device.isReachable ? "Bereikbaar" : "Reageert niet")
                if let health, let battery = health.battery {
                    LabeledContent("Batterij") {
                        Label("\(Int(battery))%", systemImage: health.batterySymbol)
                            .foregroundStyle(health.lowBattery ? Color.red : Color.secondary)
                    }
                } else if health?.lowBattery == true {
                    LabeledContent("Batterij", value: "Bijna leeg")
                }
                if let m = device.accessory.manufacturer { LabeledContent("Fabrikant", value: m) }
                if let m = device.accessory.model { LabeledContent("Model", value: m) }
                if let f = device.accessory.firmwareVersion { LabeledContent("Firmware", value: f) }
                if device.accessory.isBridged { LabeledContent("Verbonden via", value: "Bridge") }
            }

            Section {
                Button("Verwijder uit woning", role: .destructive) { confirmRemove = true }
            } footer: {
                Text("Het apparaat verdwijnt uit Apple Woning op al je apparaten. Je kunt het later opnieuw toevoegen.")
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            name = device.name
        }
        .alert("Nieuwe kamer", isPresented: $showNewRoom) {
            TextField("Naam", text: $newRoom)
            Button("Annuleer", role: .cancel) {}
            Button("Maak en verplaats") {
                home.addRoom(named: newRoom) { room in home.move(device, to: room) }
            }
        }
        .confirmationDialog("\(device.accessory.name) verwijderen?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Verwijderen", role: .destructive) {
                home.remove(device.accessory)
                dismiss()
            }
        }
    }
}

/// Kamers toevoegen, hernoemen en verwijderen.
struct RoomsManageView: View {
    @EnvironmentObject private var home: HomeStore

    @State private var editing: HMRoom?
    @State private var nameField = ""
    @State private var showNew = false
    @State private var toDelete: HMRoom?

    var body: some View {
        List {
            Section {
                ForEach(home.home?.rooms ?? [], id: \.uniqueIdentifier) { room in
                    Button {
                        nameField = room.name
                        editing = room
                    } label: {
                        HStack {
                            Text(room.name).foregroundStyle(.primary)
                            Spacer()
                            Text("\(room.accessories.count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .swipeActions {
                        Button("Verwijder", role: .destructive) { toDelete = room }
                    }
                }
                Button {
                    nameField = ""
                    showNew = true
                } label: {
                    Label("Kamer toevoegen", systemImage: "plus")
                }
            } footer: {
                Text("Tik op een kamer om de naam te wijzigen. Veeg naar links om te verwijderen; de apparaten gaan dan naar de standaardkamer.")
            }
        }
        .navigationTitle("Kamers")
        .alert("Kamer hernoemen", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("Naam", text: $nameField)
            Button("Annuleer", role: .cancel) {}
            Button("Bewaar") { if let room = editing { home.rename(room, to: nameField) } }
        }
        .alert("Nieuwe kamer", isPresented: $showNew) {
            TextField("Naam", text: $nameField)
            Button("Annuleer", role: .cancel) {}
            Button("Voeg toe") { home.addRoom(named: nameField) }
        }
        .confirmationDialog("Kamer verwijderen?",
                            isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Verwijderen", role: .destructive) {
                if let room = toDelete { home.remove(room) }
                toDelete = nil
            }
        }
    }
}

/// Huiscontrole: welke apparaten reageren niet of hebben een lege batterij.
struct HealthView: View {
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        let items = home.health
        let problems = items.filter(\.needsAttention)
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: problems.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(problems.isEmpty ? Color.green : IconPalette.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(problems.isEmpty ? "Alles werkt" : "\(problems.count) aandachtspunt(en)")
                            .font(.headline)
                        Text("\(items.count) accessoires gecontroleerd")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            Section("Accessoires") {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.reachable ? "checkmark.circle.fill" : "wifi.exclamationmark")
                            .foregroundStyle(item.reachable ? Color.green : Color.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                            Text([item.room, item.manufacturer, item.firmware.map { "fw \($0)" }]
                                    .compactMap { $0 }
                                    .joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if item.battery != nil || item.lowBattery {
                            Label(item.battery.map { "\(Int($0))%" } ?? "Laag", systemImage: item.batterySymbol)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(item.lowBattery ? Color.red : Color.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Huiscontrole")
    }
}
