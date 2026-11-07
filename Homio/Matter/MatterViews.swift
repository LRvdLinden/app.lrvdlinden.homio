import SwiftUI
#if canImport(MatterSupport) && !targetEnvironment(macCatalyst)
import MatterSupport
#endif

// MARK: - Tegel

/// Tegel voor een Matter-apparaat, in exact dezelfde vorm als een HomeKit-tegel.
struct MatterTile: View {
    let endpoint: MatterEndpoint
    var minHeight: CGFloat = 0
    var fillsHeight = false

    @EnvironmentObject private var matter: MatterStore
    @State private var showDetail = false

    var body: some View {
        let s = matter.state(endpoint)
        let on = matter.isOn(endpoint, s)
        let model = TileModel(iconKey: endpoint.id, iconName: endpoint.kind.iconName(isOn: on), name: endpoint.name,
                              kind: endpoint.kind, isOn: on, isToggleable: matter.isToggleable(endpoint, s),
                              isReachable: s.reachable, lowBattery: s.lowBattery,
                              indicator: matter.indicator(endpoint, s),
                              accessibilityValue: matter.stateText(endpoint, s), viaMatter: true)
        TileFace(model: model, minHeight: minHeight, fillsHeight: fillsHeight,
                 onTap: { matter.toggle(endpoint) },
                 onOpen: { showDetail = true }) {
            MatterQuickMenu(endpoint: endpoint, showDetail: $showDetail)
        }
        .sheet(isPresented: $showDetail) {
            MatterDetailSheet(endpointID: endpoint.id)
        }
    }
}

private struct MatterQuickMenu: View {
    let endpoint: MatterEndpoint
    @Binding var showDetail: Bool
    @EnvironmentObject private var matter: MatterStore

    var body: some View {
        let s = matter.state(endpoint)
        switch endpoint.kind {
        case .light:
            Button { matter.setOn(endpoint, true) } label: { Label("Aan", systemImage: "lightbulb.fill") }
            Button { matter.setOn(endpoint, false) } label: { Label("Uit", systemImage: "lightbulb") }
            if s.brightness != nil {
                Divider()
                ForEach([25, 50, 75, 100], id: \.self) { level in
                    Button { matter.setBrightness(endpoint, Double(level)) } label: { Label("\(level)%", systemImage: "sun.max") }
                }
            }
        case .blinds:
            Button { matter.setOpen(endpoint, 100) } label: { Label("Open", systemImage: "arrow.up") }
            Button { matter.setOpen(endpoint, 50) } label: { Label("Half", systemImage: "arrow.up.and.down") }
            Button { matter.setOpen(endpoint, 0) } label: { Label("Dicht", systemImage: "arrow.down") }
            Button { matter.stopCovering(endpoint) } label: { Label("Stop", systemImage: "stop.fill") }
        case .lock:
            Button { matter.setOn(endpoint, true) } label: { Label("Op slot", systemImage: "lock.fill") }
            Button { matter.setOn(endpoint, false) } label: { Label("Ontgrendel", systemImage: "lock.open.fill") }
        case .vacuum:
            Button { matter.operate(endpoint, command: 0x03) } label: { Label("Hervat", systemImage: "play.fill") }
            Button { matter.operate(endpoint, command: 0x00) } label: { Label("Pauze", systemImage: "pause.fill") }
            Button { matter.operate(endpoint, command: 0x80) } label: { Label("Naar dock", systemImage: "house.fill") }
        default:
            if matter.isToggleable(endpoint, s) {
                Button { matter.toggle(endpoint) } label: {
                    Label(matter.isOn(endpoint, s) ? "Uit" : "Aan", systemImage: "power")
                }
            }
        }
        Divider()
        Button { showDetail = true } label: { Label("Details", systemImage: "slider.horizontal.3") }
    }
}

// MARK: - Detail

struct MatterDetailSheet: View {
    let endpointID: String
    @EnvironmentObject private var matter: MatterStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let e = matter.endpoint(id: endpointID) {
                    MatterControls(endpoint: e)
                        .navigationTitle(e.name)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                NavigationLink {
                                    MatterManageView(endpointID: endpointID)
                                } label: {
                                    Image(systemName: "gearshape")
                                }
                                .accessibilityLabel("Beheren")
                            }
                        }
                } else {
                    ContentUnavailableView("Apparaat niet gevonden", systemImage: "questionmark.circle")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gereed") { dismiss() }
                }
            }
            .background(Theme.background)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct MatterControls: View {
    let endpoint: MatterEndpoint
    @EnvironmentObject private var matter: MatterStore

    @State private var level: Double = 0
    @State private var open: Double = 0
    @State private var target: Double = 20
    @State private var fan: Double = 0
    @State private var mireds: Double = 300
    @State private var hue: Double = 30
    @State private var saturation: Double = 60

    var body: some View {
        let s = matter.state(endpoint)
        let on = matter.isOn(endpoint, s)
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    DeviceIcon(key: endpoint.id, fallback: endpoint.kind.iconName(isOn: on), size: 52)
                        .foregroundStyle(on ? endpoint.kind.tint : Theme.textLight)
                    Text(matter.stateText(endpoint, s)).font(HomeyFont.xlarge)
                    Text("\(endpoint.room) · Matter").foregroundStyle(Theme.textLight)
                }
                .padding(.top, 16)

                switch endpoint.kind {
                case .light:
                    if s.brightness != nil {
                        VerticalSlider(value: $level, tint: Theme.yellow, symbol: "sun.max.fill") { v in
                            matter.setBrightness(endpoint, v * 100)
                        }
                        .frame(height: 260)
                    } else {
                        powerButton(on)
                    }
                    if s.hue != nil {
                        ColorWheel(hue: $hue, saturation: $saturation) {
                            matter.setColor(endpoint, hue: hue, saturation: saturation / 100)
                        }
                        .frame(width: 220, height: 220)
                    }
                    if s.colorTempMireds != nil {
                        ColorTemperatureSlider(mireds: $mireds, range: 153...500) {
                            matter.setColorTemperature(endpoint, mireds: Int(mireds))
                        }
                        .padding(.horizontal)
                    }
                case .blinds:
                    VerticalSlider(value: $open, tint: .teal, symbol: "blinds.horizontal.open") { v in
                        matter.setOpen(endpoint, v * 100)
                    }
                    .frame(height: 260)
                    HStack(spacing: 12) {
                        Button { matter.setOpen(endpoint, 100) } label: { Label("Open", systemImage: "arrow.up") }
                        Button { matter.stopCovering(endpoint) } label: { Label("Stop", systemImage: "stop.fill") }
                        Button { matter.setOpen(endpoint, 0) } label: { Label("Dicht", systemImage: "arrow.down") }
                    }
                    .buttonStyle(.bordered)
                case .thermostat, .heaterCooler:
                    VStack(spacing: 12) {
                        Text("\(target.oneDecimal)°").font(.system(size: 56, weight: .light, design: .rounded))
                        HStack(spacing: 24) {
                            Button { setTarget(target - 0.5) } label: { Image(systemName: "minus") }
                            Button { setTarget(target + 0.5) } label: { Image(systemName: "plus") }
                        }
                        .font(.title2.weight(.semibold))
                        .buttonStyle(.bordered)
                        if matter.isToggleable(endpoint, s) { powerButton(on) }
                    }
                case .fan, .airPurifier:
                    powerButton(on)
                    if s.fanPercent != nil {
                        VerticalSlider(value: $fan, tint: .cyan, symbol: "fan.fill") { v in
                            matter.setFan(endpoint, percent: v * 100)
                        }
                        .frame(height: 220)
                    }
                case .vacuum, .appliance:
                    HStack(spacing: 12) {
                        Button { matter.operate(endpoint, command: endpoint.kind == .vacuum ? 0x03 : 0x02) } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        Button { matter.operate(endpoint, command: 0x00) } label: { Label("Pauze", systemImage: "pause.fill") }
                        if endpoint.kind == .vacuum {
                            Button { matter.operate(endpoint, command: 0x80) } label: { Label("Naar dock", systemImage: "house.fill") }
                        } else {
                            Button { matter.operate(endpoint, command: 0x01) } label: { Label("Stop", systemImage: "stop.fill") }
                        }
                    }
                    .buttonStyle(.bordered)
                default:
                    if matter.isToggleable(endpoint, s) {
                        powerButton(on)
                    } else {
                        Text(matter.stateText(endpoint, s))
                            .font(.system(size: 64, weight: .thin, design: .rounded))
                    }
                }

                readings(s)
            }
            .padding()
        }
        .onAppear { sync(s) }
        .onChange(of: matter.revision) { _, _ in sync(matter.state(endpoint)) }
    }

    private func sync(_ s: MatterState) {
        level = (s.brightness ?? 0) / 100
        open = (s.openPercent ?? 0) / 100
        target = s.targetTemperature ?? target
        fan = (s.fanPercent ?? 0) / 100
        mireds = s.colorTempMireds ?? mireds
        if let h = s.hue { hue = h }
        if let sat = s.saturation { saturation = sat * 100 }
    }

    private func setTarget(_ value: Double) {
        target = max(5, min(32, value))
        matter.setTarget(endpoint, celsius: target)
    }

    private func powerButton(_ on: Bool) -> some View {
        Button { matter.toggle(endpoint) } label: {
            Image(systemName: endpoint.kind == .lock ? (on ? "lock.fill" : "lock.open.fill") : "power")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(on ? Color.white : Theme.text)
                .frame(width: 140, height: 140)
                .background(Circle().fill(on ? AnyShapeStyle(endpoint.kind.tint) : AnyShapeStyle(Theme.tileOff)))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: on)
    }

    @ViewBuilder
    private func readings(_ s: MatterState) -> some View {
        let rows: [(String, String, String)] = [
            s.temperature.map { ("thermometer.medium", "Temperatuur", "\($0.oneDecimal)°") },
            s.humidity.map { ("humidity.fill", "Vochtigheid", "\(Int($0))%") },
            s.lux.map { ("sun.max.fill", "Licht", "\(Int($0)) lux") },
            s.powerW.map { ("bolt.fill", "Vermogen", "\(Int($0)) W") },
            s.batteryPercent.map { ("battery.75percent", "Batterij", "\(Int($0))%") }
        ].compactMap { $0 }
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { i in
                    let row = rows[i]
                    HStack {
                        Label(row.1, systemImage: row.0)
                        Spacer()
                        Text(row.2).foregroundStyle(Theme.textLight)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    if i < rows.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.card))
        }
    }
}

// MARK: - Beheer

struct MatterManageView: View {
    let endpointID: String
    @EnvironmentObject private var matter: MatterStore
    @EnvironmentObject private var home: HomeStore
    @ObservedObject private var icons = DeviceIconStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var newRoom = ""
    @State private var pickIcon = false
    @State private var shareCode: String?
    @State private var sharing = false
    @State private var confirmRemove = false

    var body: some View {
        Form {
            if let e = matter.endpoint(id: endpointID), let record = matter.record(e.nodeID) {
                Section("Naam") {
                    TextField("Naam", text: $name)
                        .onAppear { name = e.name }
                        .onSubmit { matter.rename(e, to: name) }
                    if name != e.name && !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Naam bewaren") { matter.rename(e, to: name) }
                    }
                }
                Section("Icoon") {
                    Button { pickIcon = true } label: {
                        HStack(spacing: 14) {
                            DeviceIcon(key: e.id, fallback: e.kind.iconName(isOn: false), size: 30)
                                .foregroundStyle(Theme.text)
                                .frame(width: 48, height: 48)
                                .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.tileOff))
                            Text("Kies een icoon")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textLight)
                        }
                    }
                    .foregroundStyle(Theme.text)
                    .sheet(isPresented: $pickIcon) {
                        IconPickerView(title: e.name, current: icons.icon(for: e.id) ?? e.kind.iconName(isOn: false)) {
                            icons.set($0, for: e.id)
                        }
                    }
                }
                Section("Kamer") {
                    Picker("Kamer", selection: Binding(get: { e.room }, set: { matter.move(e, to: $0) })) {
                        ForEach(roomNames(including: e.room), id: \.self) { Text($0).tag($0) }
                    }
                    HStack {
                        TextField("Nieuwe kamer", text: $newRoom)
                        Button("Voeg toe") {
                            let trimmed = newRoom.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            matter.move(e, to: trimmed)
                            newRoom = ""
                        }
                        .disabled(newRoom.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("Info") {
                    LabeledContent("Soort", value: MatterDeviceTypes.label(for: e.types))
                    if !record.info.vendorName.isEmpty { LabeledContent("Merk", value: record.info.vendorName) }
                    if !record.info.productName.isEmpty { LabeledContent("Model", value: record.info.productName) }
                    if !record.info.serialNumber.isEmpty { LabeledContent("Serienummer", value: record.info.serialNumber) }
                    LabeledContent("Node", value: String(format: "0x%llX", record.nodeID))
                    LabeledContent("Eindpunt", value: "\(e.endpoint)")
                    LabeledContent("Gecertificeerd", value: record.certified ? "Ja" : "Nee")
                }
                Section {
                    Button {
                        sharing = true
                        Task {
                            do { shareCode = try await matter.shareCode(record.nodeID) }
                            catch { matter.lastError = error.localizedDescription }
                            sharing = false
                        }
                    } label: {
                        HStack {
                            Label("Koppelcode voor een andere app", systemImage: "square.and.arrow.up")
                            if sharing { Spacer(); ProgressView() }
                        }
                    }
                    if let shareCode {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(shareCode)
                                .font(.system(.title2, design: .monospaced).weight(.semibold))
                                .textSelection(.enabled)
                            Text("Geldig voor 15 minuten. Vul deze code in bij Google Home, Alexa, SmartThings of Homey.")
                                .font(HomeyFont.tiny)
                                .foregroundStyle(Theme.textLight)
                        }
                    }
                } footer: {
                    Text("Zo bedien je hetzelfde apparaat ook vanuit een andere app (Matter multi-admin).")
                }
                Section {
                    Button("Verwijderen uit Homio", role: .destructive) { confirmRemove = true }
                }
                .confirmationDialog("\(record.name) verwijderen?", isPresented: $confirmRemove, titleVisibility: .visible) {
                    Button("Verwijderen", role: .destructive) {
                        Task {
                            await matter.remove(record.nodeID)
                            dismiss()
                        }
                    }
                    Button("Alleen uit Homio vergeten") {
                        Task {
                            await matter.remove(record.nodeID, forgetOnly: true)
                            dismiss()
                        }
                    }
                } message: {
                    Text("Homio haalt zijn netwerk van het apparaat af. Andere apps die het apparaat ook bedienen, blijven werken.")
                }
            }
        }
        .navigationTitle("Beheren")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func roomNames(including current: String) -> [String] {
        var names = home.allRooms.map(\.name)
        names.append(contentsOf: matter.records.map(\.room))
        names.append(current)
        return Array(Set(names)).sorted()
    }
}

// MARK: - Toevoegen

struct MatterAddView: View {
    @EnvironmentObject private var matter: MatterStore
    @EnvironmentObject private var home: HomeStore
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var name = ""
    @State private var room = ""
    @State private var busy = false
    @State private var error: String?
    @State private var added: MatterRecord?
    @State private var pickIconFor: MatterEndpoint?
    @ObservedObject private var icons = DeviceIconStore.shared

    var body: some View {
        NavigationStack {
            Form {
                if let added {
                    successSection(added)
                } else {
                    #if canImport(MatterSupport) && !targetEnvironment(macCatalyst)
                    Section {
                        Button {
                            Task { await addWithApple() }
                        } label: {
                            Label("Nieuw apparaat koppelen", systemImage: "qrcode.viewfinder")
                                .font(HomeyFont.bodyMedium)
                        }
                        .disabled(busy)
                    } footer: {
                        Text("Scan de Matter-QR-code op het apparaat of de verpakking. iOS regelt Bluetooth, wifi en Thread; daarna komt het apparaat in Homio.")
                    }
                    #endif

                    Section {
                        TextField("Koppelcode (11 of 21 cijfers, of MT:…)", text: $code)
                            .keyboardType(.asciiCapable)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                        TextField("Naam (optioneel)", text: $name)
                        Picker("Kamer", selection: $room) {
                            ForEach(roomNames, id: \.self) { Text($0).tag($0) }
                        }
                        Button {
                            Task { await addWithCode() }
                        } label: {
                            HStack {
                                Text("Koppelen")
                                if busy { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(busy || code.trimmingCharacters(in: .whitespaces).count < 11)
                    } header: {
                        Text("Zit het al in een andere app?")
                    } footer: {
                        Text("Zet in Google Home, Alexa, SmartThings, Homey of de app van de fabrikant de koppelmodus aan (\"Deel apparaat\" of \"Koppel met andere app\") en vul de code hier in. Apparaten die al in Apple Woning zitten, staan vanzelf in Homio.")
                    }

                    if let error {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.red)
                        }
                    }
                }
            }
            .navigationTitle("Matter-apparaat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(added == nil ? "Annuleer" : "Gereed") { dismiss() }
                }
            }
            .onAppear {
                if room.isEmpty { room = roomNames.first ?? "Standaardkamer" }
                matter.publishRooms(home.allRooms.map(\.name))
            }
            .sheet(item: $pickIconFor) { e in
                IconPickerView(title: e.name, current: icons.icon(for: e.id) ?? e.kind.iconName(isOn: false)) {
                    icons.set($0, for: e.id)
                }
            }
        }
    }

    private func successSection(_ record: MatterRecord) -> some View {
        Section {
            Label("\(record.name) is gekoppeld", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.green)
                .font(HomeyFont.bodyMedium)
            ForEach(matter.endpoints(of: record)) { e in
                Button { pickIconFor = e } label: {
                    HStack(spacing: 12) {
                        DeviceIcon(key: e.id, fallback: e.kind.iconName(isOn: false), size: 26)
                            .foregroundStyle(Theme.text)
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.tileOff))
                        VStack(alignment: .leading) {
                            Text(e.name).foregroundStyle(Theme.text)
                            Text("Tik om een icoon te kiezen").font(HomeyFont.tiny).foregroundStyle(Theme.textLight)
                        }
                    }
                }
            }
            if matter.isDuplicate(record, home: home) {
                Text("Dit apparaat zit ook in Apple Woning. Homio toont het één keer, via Apple Woning.")
                    .font(HomeyFont.tiny)
                    .foregroundStyle(Theme.textLight)
            }
        }
    }

    private var roomNames: [String] {
        let names = home.allRooms.map(\.name) + matter.records.map(\.room)
        let unique = Array(Set(names)).sorted()
        return unique.isEmpty ? ["Standaardkamer"] : unique
    }

    private func addWithCode() async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            added = try await matter.commission(code: code, name: name, room: room)
        } catch {
            self.error = error.localizedDescription
        }
    }

    #if canImport(MatterSupport) && !targetEnvironment(macCatalyst)
    private func addWithApple() async {
        busy = true
        error = nil
        defer { busy = false }
        matter.publishRooms(home.allRooms.map(\.name))
        let before = Set(matter.records.map(\.nodeID))
        do {
            let topology = MatterAddDeviceRequest.Topology(
                ecosystemName: "Homio",
                homes: [MatterAddDeviceRequest.Home(displayName: home.home?.name ?? "Thuis")])
            let request = MatterAddDeviceRequest(topology: topology)
            try await request.perform()
            matter.start(force: true)
            matter.importPending()
            added = matter.records.first { !before.contains($0.nodeID) }
        } catch {
            // Annuleren door de gebruiker is geen fout.
            if (error as NSError).code != NSUserCancelledError {
                self.error = error.localizedDescription
            }
        }
    }
    #endif
}

// MARK: - Overzicht in Meer

struct MatterSettingsView: View {
    @EnvironmentObject private var matter: MatterStore
    @EnvironmentObject private var home: HomeStore
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                LabeledContent("Netwerk") {
                    switch matter.status {
                    case .idle: Text(matter.records.isEmpty ? "Nog niet gestart" : "Wacht")
                    case .starting: ProgressView()
                    case .ready: Label("Actief", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.green)
                    case .failed(let reason): Text(reason).foregroundStyle(Theme.red)
                    }
                }
                Button { showAdd = true } label: { Label("Matter-apparaat toevoegen", systemImage: "plus.circle") }
            } footer: {
                Text("Homio heeft een eigen Matter-netwerk naast Apple Woning. De sleutels staan in je iCloud-sleutelhanger, zodat al je Apple-apparaten meedoen.")
            }

            Section("Apparaten") {
                if matter.records.isEmpty {
                    Text("Nog geen apparaten via Homio's Matter-netwerk.").foregroundStyle(Theme.textLight)
                }
                ForEach(matter.records) { record in
                    let duplicate = matter.isDuplicate(record, home: home)
                    let endpoints = matter.endpoints(of: record)
                    NavigationLink {
                        if let first = endpoints.first {
                            MatterManageView(endpointID: first.id)
                        } else {
                            Text("Geen bedienbare onderdelen gevonden.")
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.name)
                            Text([record.info.vendorName, record.room, "\(endpoints.count) onderdeel/onderdelen"]
                                .filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(HomeyFont.tiny)
                                .foregroundStyle(Theme.textLight)
                            if duplicate {
                                Label("Ook in Apple Woning: getoond via HomeKit", systemImage: "rectangle.on.rectangle")
                                    .font(HomeyFont.tiny)
                                    .foregroundStyle(Theme.orange)
                            }
                        }
                    }
                }
            }

            Section("Goed om te weten") {
                Label("Matter-apparaten van Homio werken lokaal, zonder cloud. Ze reageren zolang er een iPhone, iPad of Mac met Homio in je netwerk is.", systemImage: "wifi")
                Label("Automatiseringen (flows) draaien op je woninghub en werken alleen met apparaten in Apple Woning.", systemImage: "arrow.triangle.branch")
                Label("Thread-apparaten hebben een Thread-router nodig, zoals een HomePod mini of Apple TV 4K.", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .font(HomeyFont.small)
            .foregroundStyle(Theme.textMedium)
        }
        .navigationTitle("Matter")
        .sheet(isPresented: $showAdd) { MatterAddView() }
        .onAppear { matter.start() }
    }
}
