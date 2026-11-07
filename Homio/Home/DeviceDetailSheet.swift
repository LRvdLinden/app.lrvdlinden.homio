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
            VStack(spacing: 6) {
                Image(systemName: device.symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(device.isOn ? device.tint : Color.primary.opacity(0.7))
                Text(device.stateText).font(.title2.weight(.semibold))
                Text(device.roomName).foregroundStyle(Theme.textLight)
            }
            .padding(.top, 24)

            switch device.kind {
            case .light:
                LightControls(device: device)
            case .blinds:
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
            case .lock, .outlet, .switchKind, .garage:
                PowerButton(device: device)
            case .temperature, .humidity, .contact, .motion:
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
                .foregroundStyle(device.isOn ? Color.black : Color.primary)
                .frame(width: 160, height: 160)
                .background(Circle().fill(device.isOn ? AnyShapeStyle(device.tint) : AnyShapeStyle(Color.primary.opacity(0.12))))
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
                Rectangle().fill(Color.primary.opacity(0.12))
                Rectangle().fill(tint).frame(height: geo.size.height * value)
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(value > 0.15 ? Color.black.opacity(0.6) : Color.primary.opacity(0.8))
                    .padding(.bottom, 22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
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

private struct LightControls: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore
    @State private var level: Double = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        AdaptiveStack(spacing: sizeClass == .compact ? 24 : 40) {
            VStack(spacing: 14) {
                Text(level > 0 ? "\(Int(level * 100))%" : "Uit").font(.title.monospacedDigit())
                VerticalSlider(value: $level, tint: Theme.amber, symbol: "lightbulb.fill") { v in
                    let percent = Int((v * 100).rounded())
                    if percent == 0 {
                        home.write(device.characteristic(HMCharacteristicTypePowerState), false)
                    } else {
                        if !device.isOn { home.write(device.characteristic(HMCharacteristicTypePowerState), true) }
                        home.write(device.characteristic(HMCharacteristicTypeBrightness), percent)
                    }
                }
            }

            LightColorPanel(device: device)
        }
        .onAppear {
            if device.isOn {
                level = (device.brightness ?? 100) / 100
            } else {
                level = 0
            }
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
                    .stroke(Color.primary.opacity(0.1), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .rotationEffect(.degrees(90))
                Circle()
                    .trim(from: 0.12, to: 0.12 + 0.76 * fraction)
                    .stroke(LinearGradient(colors: [.blue, .orange], startPoint: .leading, endPoint: .trailing),
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
                .background(Circle().fill(Color.primary.opacity(0.12)))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.primary)
        .sensoryFeedback(.selection, trigger: target)
    }
}
