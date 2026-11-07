import HomeKit
import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject private var home: WatchHome
    @State private var splashDone = false

    var body: some View {
        ZStack {
            if splashDone {
                content.transition(.opacity)
            } else {
                WatchSplash { withAnimation(.easeInOut(duration: 0.4)) { splashDone = true } }
            }
        }
        .alert("Er ging iets mis", isPresented: Binding(
            get: { home.lastError != nil },
            set: { if !$0 { home.lastError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(home.lastError ?? "")
        }
    }

    private var content: some View {
        NavigationStack {
            List {
                if !home.isReady {
                    ProgressView()
                } else if home.home == nil {
                    Text("Maak eerst een woning aan in Homio op je iPhone.")
                        .font(.footnote)
                } else {
                    Section {
                        HStack {
                            if let t = home.indoorTemperature {
                                Label(String(format: "%.1f°", t), systemImage: "thermometer.medium")
                                    .foregroundStyle(WatchPalette.orange)
                            }
                            Spacer()
                            Label("\(home.lightsOn)", systemImage: "lightbulb.fill")
                                .foregroundStyle(WatchPalette.yellow)
                        }
                        .font(.footnote.weight(.semibold))
                    }

                    if !home.scenes.isEmpty {
                        Section("Sferen") {
                            ForEach(home.scenes, id: \.uniqueIdentifier) { scene in
                                WatchSceneRow(scene: scene)
                            }
                        }
                    }

                    Section("Kamers") {
                        ForEach(home.rooms, id: \.self) { room in
                            NavigationLink(value: room) {
                                HStack {
                                    Text(room)
                                    Spacer()
                                    let on = home.devices(in: room).filter { $0.isToggleable && $0.isOn }.count
                                    if on > 0 {
                                        Text("\(on)").font(.footnote).foregroundStyle(WatchPalette.yellow)
                                    }
                                }
                            }
                        }
                    }

                    if !home.triggers.isEmpty {
                        Section("Flows") {
                            ForEach(home.triggers, id: \.uniqueIdentifier) { trigger in
                                // Aan/uit zetten kan watchOS niet; dat doe je op iPhone of iPad.
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(trigger.isEnabled ? Color.green : Color.gray)
                                        .frame(width: 8, height: 8)
                                    Text(trigger.name).lineLimit(2)
                                    Spacer()
                                    Text(trigger.isEnabled ? "Aan" : "Uit")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

            }
            .navigationTitle(home.home?.name ?? "Homio")
            .navigationDestination(for: String.self) { room in
                WatchRoomView(room: room)
            }
            .navigationDestination(for: UUID.self) { id in
                WatchDeviceDetail(deviceID: id)
            }
        }
    }
}

private struct WatchSceneRow: View {
    let scene: HMActionSet
    @EnvironmentObject private var home: WatchHome
    @State private var fired = false

    var body: some View {
        Button {
            home.run(scene)
            fired.toggle()
        } label: {
            Label(scene.name, systemImage: "sparkles")
                .symbolEffect(.bounce, value: fired)
        }
        .listItemTint(WatchPalette.orange)
        .sensoryFeedback(.success, trigger: fired)
    }
}

struct WatchRoomView: View {
    let room: String
    @EnvironmentObject private var home: WatchHome

    var body: some View {
        List {
            ForEach(home.devices(in: room)) { device in
                if device.hasDetail {
                    NavigationLink(value: device.id) {
                        WatchDeviceLabel(device: device)
                    }
                } else if device.isToggleable {
                    Button { home.toggle(device) } label: {
                        WatchDeviceLabel(device: device)
                    }
                } else {
                    WatchDeviceLabel(device: device)
                }
            }
        }
        .navigationTitle(room)
    }
}

private struct WatchDeviceLabel: View {
    let device: WatchDevice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.symbol)
                .foregroundStyle(device.isOn ? device.tint : Color.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name).lineLimit(1)
                Text(device.stateText).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

struct WatchDeviceDetail: View {
    let deviceID: UUID
    @EnvironmentObject private var home: WatchHome
    @State private var value: Double = 0
    @State private var loaded = false

    var body: some View {
        if let device = home.device(id: deviceID) {
            ScrollView {
                VStack(spacing: 12) {
                    Button { home.toggle(device) } label: {
                        Image(systemName: device.kind == .thermostat ? "power" : device.symbol)
                            .font(.title2)
                            .foregroundStyle(device.isOn ? Color.black : Color.white)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(device.isOn ? AnyShapeStyle(device.tint) : AnyShapeStyle(Color.white.opacity(0.15))))
                    }
                    .buttonStyle(.plain)

                    Text(device.stateText).font(.headline)

                    switch device.kind {
                    case .light:
                        Slider(value: $value, in: 0...100, step: 10) { Text("Helderheid") }
                            .tint(WatchPalette.yellow)
                    case .blinds:
                        Slider(value: $value, in: 0...100, step: 10) { Text("Positie") }
                    case .thermostat:
                        Stepper(value: $value, in: 10...30, step: 0.5) {
                            Text(String(format: "%.1f°", value)).font(.title3)
                        }
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle(device.name)
            .onAppear {
                value = current(device)
                loaded = true
            }
            .onChange(of: value) { _, newValue in
                guard loaded, newValue != current(device) else { return }
                commit(device, newValue)
            }
        } else {
            Text("Niet gevonden")
        }
    }

    private func current(_ device: WatchDevice) -> Double {
        switch device.kind {
        case .light: return device.isOn ? (device.number(HMCharacteristicTypeBrightness) ?? 100) : 0
        case .blinds: return device.number(HMCharacteristicTypeCurrentPosition) ?? 0
        case .thermostat: return device.number(HMCharacteristicTypeTargetTemperature) ?? 20
        default: return 0
        }
    }

    private func commit(_ device: WatchDevice, _ value: Double) {
        switch device.kind {
        case .light:
            if value <= 0 {
                home.write(device.characteristic(HMCharacteristicTypePowerState), false)
            } else {
                if !device.isOn { home.write(device.characteristic(HMCharacteristicTypePowerState), true) }
                home.write(device.characteristic(HMCharacteristicTypeBrightness), Int(value))
            }
        case .blinds:
            home.write(device.characteristic(HMCharacteristicTypeTargetPosition), Int(value))
        case .thermostat:
            home.write(device.characteristic(HMCharacteristicTypeTargetTemperature), NSNumber(value: value))
        default:
            break
        }
    }
}

/// Korte opening met de vier tegels van het icoon.
private struct WatchSplash: View {
    let onFinish: () -> Void
    @State private var shown = [false, false, false, false]

    private let colors: [Color] = [Color(white: 0.96), Color(white: 0.18), WatchPalette.yellow, WatchPalette.blue]
    private let symbols = ["clock.fill", "thermometer.medium", "lightbulb.fill", "lock.fill"]
    private let symbolColors: [Color] = [.black, WatchPalette.orange, .black, .white]

    var body: some View {
        VStack(spacing: 10) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow { tile(0); tile(1) }
                GridRow { tile(2); tile(3) }
            }
            Text("Homio").font(.title3.weight(.bold))
                .opacity(shown[3] ? 1 : 0)
        }
        .task {
            for i in 0..<4 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { shown[i] = true }
                try? await Task.sleep(nanoseconds: 110_000_000)
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            onFinish()
        }
    }

    private func tile(_ i: Int) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(colors[i])
            .frame(width: 42, height: 42)
            .overlay(Image(systemName: symbols[i]).foregroundStyle(symbolColors[i]))
            .scaleEffect(shown[i] ? 1 : 0.2)
            .opacity(shown[i] ? 1 : 0)
    }
}
