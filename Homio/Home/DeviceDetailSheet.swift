import HomeKit
import SwiftUI

struct DeviceDetailSheet: View {
    let deviceID: UUID

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let device = home.device(id: deviceID) {
                    ScrollView {
                        DeviceControls(device: device)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    ContentUnavailableView("Apparaat niet gevonden", systemImage: "questionmark.circle")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle(home.device(id: deviceID)?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        settings.toggleFavorite(deviceID)
                    } label: {
                        Image(systemName: settings.isFavorite(deviceID) ? "star.fill" : "star")
                    }
                    .accessibilityLabel(settings.isFavorite(deviceID) ? "Uit favorieten" : "Aan favorieten")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gereed") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        DeviceManageView(deviceID: deviceID)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Beheren")
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.background)
    }
}

private struct DeviceControls: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        VStack(spacing: 28) {
            // Kop zoals het apparaatscherm van Homey.
            VStack(spacing: 10) {
                DeviceIcon(device: device, size: 40)
                    .foregroundStyle(device.isOn && device.kind == .light ? Theme.yellow : Theme.text)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(device.isOn ? Theme.tileOn : Theme.tileOff)
                        .shadow(color: .black.opacity(device.isOn ? 0.12 : 0), radius: 3, y: 2))
                Text(device.name).font(HomeyFont.xlarge).foregroundStyle(Theme.text).multilineTextAlignment(.center)
                Text("\(device.roomName) · \(device.stateText)")
                    .font(HomeyFont.body)
                    .foregroundStyle(Theme.textLight)
                    .contentTransition(.numericText())
            }
            .padding(.top, 16)

            switch device.kind {
            case .light:
                LightControls(device: device)
            case .blinds, .window, .door:
                PercentSlider(device: device,
                              type: HMCharacteristicTypeTargetPosition,
                              current: device.position ?? 0)
            case .fan:
                VStack(spacing: 24) {
                    PowerButton(device: device)
                    if device.characteristic(HMCharacteristicTypeRotationSpeed) != nil {
                        PercentSlider(device: device,
                                      type: HMCharacteristicTypeRotationSpeed,
                                      current: device.number(HMCharacteristicTypeRotationSpeed) ?? 0)
                    }
                }
            case .thermostat:
                ThermostatControls(device: device)
            case .lock, .outlet, .switchKind, .garage, .airPurifier, .heaterCooler, .humidifier, .valve:
                PowerButton(device: device)
            case .security, .temperature, .humidity, .contact, .motion, .occupancy, .smoke, .carbonMonoxide, .leak, .lux, .airQuality,
                 .speaker, .tv, .vacuum, .appliance, .energy, .sensor:
                Text(device.stateText)
                    .font(.system(size: 72, weight: .thin, design: .rounded))
            }
            Spacer()
        }
        .padding()
    }
}

private struct PowerButton: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        Button {
            home.toggle(device)
        } label: {
            Image(systemName: device.kind == .lock ? (device.isOn ? "lock.fill" : "lock.open.fill") : "power")
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(device.isOn ? Color.white : Theme.textLight)
                .frame(width: 160, height: 160)
                .background(Circle().fill(device.isOn ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(Theme.card))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: device.isOn)
    }
}

/// Grote verticale schuif zoals in de Woning-app.
struct VerticalSlider: View {
    @Binding var value: Double          // 0...1
    var tint: Color
    var symbol: String
    var onCommit: (Double) -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Rectangle().fill(Theme.tileOff)
                Rectangle().fill(tint.gradient).frame(height: geo.size.height * value)
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(value > 0.15 ? Color.white : Theme.textLight)
                    .padding(.bottom, 22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.tileBorder, lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        value = min(1, max(0, 1 - g.location.y / geo.size.height))
                    }
                    .onEnded { _ in onCommit(value) }
            )
        }
        .frame(width: sizeClass == .compact ? 110 : 130, height: sizeClass == .compact ? 250 : 340)
        .accessibilityElement()
        .accessibilityValue("\(Int(value * 100)) procent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.1)
            case .decrement: value = max(0, value - 0.1)
            @unknown default: break
            }
            onCommit(value)
        }
    }
}

private struct PercentSlider: View {
    let device: Device
    let type: String
    let current: Double
    @EnvironmentObject private var home: HomeStore
    @State private var value: Double = 0

    var body: some View {
        VStack(spacing: 14) {
            Text("\(Int(value * 100))%").font(.title.monospacedDigit())
            VerticalSlider(value: $value, tint: device.tint, symbol: device.symbol) { v in
                home.write(device.characteristic(type), Int((v * 100).rounded()))
            }
        }
        .onAppear { value = current / 100 }
    }
}

/// Lamp zoals in Homey: één grote bediening tegelijk, onderaan een rij om te wisselen
/// tussen helderheid, kleur en aan/uit.
private struct LightControls: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore
    @State private var level: Double = 0
    @State private var tab = 0

    private var hasDim: Bool { device.characteristic(HMCharacteristicTypeBrightness) != nil }
    private var hasColor: Bool {
        device.characteristic(HMCharacteristicTypeHue) != nil || device.characteristic(HMCharacteristicTypeColorTemperature) != nil
    }

    private var tabs: [(Int, String, String)] {
        var list: [(Int, String, String)] = []
        if hasDim { list.append((0, "sun.max.fill", "Helderheid")) }
        if hasColor { list.append((1, "paintpalette.fill", "Kleur")) }
        list.append((2, "power", "Aan/uit"))
        return list
    }

    var body: some View {
        VStack(spacing: 28) {
            Group {
                switch tab {
                case 0 where hasDim:
                    VStack(spacing: 14) {
                        Text(level > 0 ? "\(Int(level * 100))%" : "Uit")
                            .font(.system(size: 34, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.text)
                            .contentTransition(.numericText())
                        VerticalSlider(value: $level, tint: Theme.yellow, symbol: "lightbulb.fill") { v in
                            let percent = Int((v * 100).rounded())
                            if percent == 0 {
                                home.write(device.characteristic(HMCharacteristicTypePowerState), false)
                            } else {
                                if !device.isOn { home.write(device.characteristic(HMCharacteristicTypePowerState), true) }
                                home.write(device.characteristic(HMCharacteristicTypeBrightness), percent)
                            }
                        }
                    }
                case 1 where hasColor:
                    LightColorPanel(device: device)
                default:
                    PowerButton(device: device)
                }
            }
            .frame(minHeight: 330)
            .animation(.easeInOut(duration: 0.2), value: tab)

            if tabs.count > 1 {
                HStack(spacing: 12) {
                    ForEach(tabs.indices, id: \.self) { i in
                        let item = tabs[i]
                        Button { tab = item.0 } label: {
                            Image(systemName: item.1)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(tab == item.0 ? Color.white : Theme.textLight)
                                .frame(width: 52, height: 52)
                                .background(Circle().fill(tab == item.0 ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.card))
                                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(item.2)
                    }
                }
                .sensoryFeedback(.selection, trigger: tab)
            }
        }
        .onAppear {
            level = device.isOn ? (device.brightness ?? 100) / 100 : 0
            tab = hasDim ? 0 : 2
        }
    }
}

private struct ThermostatControls: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore
    @State private var target: Double = 20

    private var range: ClosedRange<Double> {
        let meta = device.characteristic(HMCharacteristicTypeTargetTemperature)?.metadata
        let low = meta?.minimumValue?.doubleValue ?? 10
        let high = meta?.maximumValue?.doubleValue ?? 30
        return low...max(low + 1, high)
    }

    private let modes: [(String, Int)] = [("Uit", 0), ("Verwarmen", 1), ("Koelen", 2), ("Auto", 3)]

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .trim(from: 0.12, to: 0.88)
                    .stroke(Theme.tileOff, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .rotationEffect(.degrees(90))
                Circle()
                    .trim(from: 0.12, to: 0.12 + 0.76 * fraction)
                    .stroke(LinearGradient(colors: [Theme.accent, Theme.orange], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .rotationEffect(.degrees(90))
                VStack(spacing: 4) {
                    Text("\(target.oneDecimal)°")
                        .font(.system(size: 72, weight: .light, design: .rounded))
                        .contentTransition(.numericText())
                    if let current = device.currentTemperature {
                        Text("Nu \(current.oneDecimal)°").foregroundStyle(Theme.textLight)
                    }
                }
            }
            .frame(width: 300, height: 300)
            .animation(.spring, value: target)

            HStack(spacing: 30) {
                stepButton("minus", delta: -0.5)
                stepButton("plus", delta: 0.5)
            }

            if device.characteristic(HMCharacteristicTypeTargetHeatingCooling) != nil {
                Picker("Stand", selection: Binding(
                    get: { Int(device.number(HMCharacteristicTypeTargetHeatingCooling) ?? 0) },
                    set: { home.write(device.characteristic(HMCharacteristicTypeTargetHeatingCooling), $0) }
                )) {
                    ForEach(modes.indices, id: \.self) { i in Text(modes[i].0).tag(modes[i].1) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 460)
            }
        }
        .onAppear { target = device.targetTemperature ?? device.currentTemperature ?? 20 }
    }

    private var fraction: Double {
        (target - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private func stepButton(_ symbol: String, delta: Double) -> some View {
        Button {
            target = min(range.upperBound, max(range.lowerBound, target + delta))
            home.write(device.characteristic(HMCharacteristicTypeTargetTemperature), NSNumber(value: target))
        } label: {
            Image(systemName: symbol)
                .font(.title.weight(.semibold))
                .frame(width: 76, height: 76)
                .background(Circle().fill(Theme.card).shadow(color: .black.opacity(0.12), radius: 3, y: 2))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.primary)
        .sensoryFeedback(.selection, trigger: target)
    }
}
