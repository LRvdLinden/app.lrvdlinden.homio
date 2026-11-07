import HomeKit
import SwiftUI

/// Eigen lijn-icoon van een apparaat (vector uit de asset catalog).
struct DeviceIcon: View {
    let device: Device
    var size: CGFloat = 28

    var body: some View {
        Image(device.iconName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .contentTransition(.opacity)
            .accessibilityHidden(true)
    }
}

/// Apparaattegel zoals in Homey: tik = snelle actie, lang drukken = details,
/// contextmenu met extra snelle acties. Aan = de tegel licht op.
struct DeviceTile: View {
    let device: Device
    var minHeight: CGFloat = 118
    var fillsHeight = false

    @EnvironmentObject private var home: HomeStore
    @State private var showDetail = false
    @State private var pressing = false
    @State private var fired = 0

    private var lit: Bool { device.isOn && !device.kind.isSensor && device.isReachable }
    private var alarm: Bool { device.kind.isAlarm && device.isOn }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                DeviceIcon(device: device, size: 30)
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce, value: fired)
                Spacer(minLength: 0)
                badges
            }
            Spacer(minLength: Theme.su * 3)
            Text(device.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(lit || alarm ? Theme.tileOnText : Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Text(device.stateText)
                    .font(.system(size: 13))
                    .foregroundStyle(subColor)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Spacer(minLength: 0)
                if device.isToggleable && device.isReachable {
                    quickActionKnob
                }
            }
            .padding(.top, 2)
        }
        .padding(Theme.su * 3)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                .fill(alarm ? AnyShapeStyle(Theme.red.opacity(0.9)) : AnyShapeStyle(lit ? Theme.tileOn : Theme.tileOff))
                .shadow(color: .black.opacity(lit ? 0.12 : 0), radius: 10, y: 4)
        }
        .overlay {
            if !device.isReachable {
                RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                    .strokeBorder(Theme.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .opacity(device.isReachable ? 1 : 0.6)
        .scaleEffect(pressing ? 0.95 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressing)
        .animation(.easeInOut(duration: 0.25), value: lit)
        .contentShape(RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous))
        .onTapGesture { quickAction() }
        .onLongPressGesture(minimumDuration: 0.45, perform: {
            showDetail = true
        }, onPressingChanged: { isPressing in
            pressing = isPressing
        })
        .contextMenu { QuickActionsMenu(device: device, showDetail: $showDetail) }
        .sensoryFeedback(.impact(weight: .light), trigger: fired)
        .sheet(isPresented: $showDetail) {
            DeviceDetailSheet(deviceID: device.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(device.isToggleable ? "Tik om te schakelen, houd vast voor meer" : "Tik voor details")
    }

    // MARK: Onderdelen

    private var iconColor: Color {
        if alarm { return .white }
        if lit { return device.tint }
        return device.kind.isSensor && device.isOn ? device.tint : Theme.textLight
    }

    private var subColor: Color {
        if alarm { return .white.opacity(0.9) }
        return lit ? Theme.tileOnTextLight : Theme.textLight
    }

    /// Kleine schakelaar-knop rechtsonder, zoals de Homey snelle actie.
    private var quickActionKnob: some View {
        Image(systemName: quickSymbol)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(lit ? Color.white : Theme.textLight)
            .frame(width: 24, height: 24)
            .background(Circle().fill(lit ? device.tint : Theme.pill))
            .contentTransition(.symbolEffect(.replace))
    }

    private var quickSymbol: String {
        switch device.kind {
        case .lock: return lit ? "lock.fill" : "lock.open.fill"
        case .blinds, .window, .door, .garage: return lit ? "chevron.down" : "chevron.up"
        default: return "power"
        }
    }

    @ViewBuilder private var badges: some View {
        HStack(spacing: 4) {
            if device.lowBattery {
                Image(systemName: "battery.25percent")
                    .foregroundStyle(alarm ? Color.white : Theme.red)
            }
            if !device.isReachable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.orange)
            }
            if alarm {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)
            }
        }
        .font(.system(size: 13, weight: .semibold))
    }

    private func quickAction() {
        if device.isToggleable && device.isReachable {
            home.toggle(device)
            fired += 1
        } else {
            showDetail = true
        }
    }
}

/// Snelle acties in het contextmenu, afhankelijk van het apparaat.
struct QuickActionsMenu: View {
    let device: Device
    @Binding var showDetail: Bool
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        switch device.kind {
        case .light:
            Button { home.set(device, on: true) } label: { Label("Aan", systemImage: "lightbulb.fill") }
            Button { home.set(device, on: false) } label: { Label("Uit", systemImage: "lightbulb") }
            if device.characteristic(HMCharacteristicTypeBrightness) != nil {
                Divider()
                ForEach([25, 50, 75, 100], id: \.self) { level in
                    Button { home.setBrightness(device, percent: level) } label: {
                        Label("\(level)%", systemImage: "sun.max")
                    }
                }
            }
        case .blinds, .window, .door:
            Button { position(100) } label: { Label("Open", systemImage: "arrow.up") }
            Button { position(50) } label: { Label("Half", systemImage: "arrow.up.and.down") }
            Button { position(0) } label: { Label("Dicht", systemImage: "arrow.down") }
        case .lock:
            Button { lock(true) } label: { Label("Op slot", systemImage: "lock.fill") }
            Button { lock(false) } label: { Label("Ontgrendel", systemImage: "lock.open.fill") }
        case .thermostat, .heaterCooler:
            if let target = device.targetTemperature {
                Button { temperature(target + 0.5) } label: { Label("+0,5°", systemImage: "plus") }
                Button { temperature(target - 0.5) } label: { Label("−0,5°", systemImage: "minus") }
            }
            Button { home.toggle(device) } label: { Label(device.isOn ? "Uit" : "Aan", systemImage: "power") }
        default:
            if device.isToggleable {
                Button { home.toggle(device) } label: { Label(device.isOn ? "Uit" : "Aan", systemImage: "power") }
            }
        }
        Divider()
        Button { showDetail = true } label: { Label("Details", systemImage: "slider.horizontal.3") }
    }

    private func position(_ value: Int) {
        home.write(device.characteristic(HMCharacteristicTypeTargetPosition), value)
    }

    private func lock(_ locked: Bool) {
        home.write(device.characteristic(HMCharacteristicTypeTargetLockMechanismState), locked ? 1 : 0)
    }

    private func temperature(_ value: Double) {
        home.write(device.characteristic(HMCharacteristicTypeTargetTemperature), Float(value))
    }
}

/// Knop voor een scène.
struct SceneChip: View {
    let name: String
    let symbol: String
    let action: () -> Void
    @State private var fired = false

    var body: some View {
        Button {
            action()
            fired.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(Theme.amber)
                    .symbolEffect(.bounce, value: fired)
                Text(name).font(.headline).lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassCard()
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.primary)
        .sensoryFeedback(.success, trigger: fired)
    }
}
