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

/// Apparaattegel zoals in de Homey-app: vierkant, icoon linksboven (1/3 van de breedte),
/// waarde rechtsboven, naam linksonder. Tik = snelle actie (zacht tikje), lang drukken =
/// apparaat openen (stevige tik), contextmenu met extra snelle acties.
/// Uit = component_off met haarlijn, aan = component_on met lichte schaduw.
struct DeviceTile: View {
    let device: Device
    var minHeight: CGFloat = 0
    var fillsHeight = false

    @EnvironmentObject private var home: HomeStore
    @State private var showDetail = false
    @State private var pressing = false
    @State private var tapped = 0
    @State private var opened = 0

    /// Zonder snelle actie (sensoren) staat een tegel altijd "aan", net als in Homey.
    private var lit: Bool { device.isToggleable ? device.isOn : true }
    private var alarm: Bool { device.kind.isAlarm && device.isOn }

    var body: some View {
        GeometryReader { geo in
            let side = fillsHeight ? min(geo.size.width, geo.size.height) : geo.size.width
            let unit = max(0.8, min(1.4, side / 108))
            content(unit: unit, side: side)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .aspectRatio(fillsHeight ? nil : 1, contentMode: .fit)
        .frame(minHeight: minHeight > 0 ? minHeight : nil)
        .background {
            RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                .fill(lit ? Theme.tileOn : Theme.tileOff)
                .overlay {
                    if !lit {
                        RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                            .strokeBorder(Theme.tileBorder, lineWidth: 1 / UIScreen.main.scale)
                    }
                }
                .shadow(color: .black.opacity(lit ? 0.12 : 0), radius: 3, y: 2)
        }
        .opacity(device.isReachable ? 1 : 0.55)
        .scaleEffect(pressing ? 0.96 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressing)
        .animation(.easeInOut(duration: 0.2), value: lit)
        .contentShape(RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous))
        .onTapGesture { quickAction() }
        .onLongPressGesture(minimumDuration: 0.4, perform: {
            opened += 1
            showDetail = true
        }, onPressingChanged: { isPressing in
            pressing = isPressing
        })
        .contextMenu { QuickActionsMenu(device: device, showDetail: $showDetail) }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: tapped)
        .sensoryFeedback(.impact(weight: .medium), trigger: opened)
        .sheet(isPresented: $showDetail) {
            DeviceDetailSheet(deviceID: device.id)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(device.name), \(device.stateText)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(device.isToggleable ? "Tik om te schakelen, houd vast voor meer" : "Tik voor details")
    }

    private func content(unit: CGFloat, side: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                DeviceIcon(device: device, size: 36 * unit)
                    .foregroundStyle(iconColor)
                    .opacity(lit ? 1 : 0.7)
                    .symbolEffect(.bounce, value: tapped)
                Spacer(minLength: 0)
                indicator(unit: unit, side: side)
            }
            Spacer(minLength: 4)
            Text(device.name)
                .font(.system(size: (14 * unit).rounded(), weight: .medium))
                .lineSpacing(3 * unit)
                .foregroundStyle(lit ? Theme.text : Theme.textMedium)
                .lineLimit(fillsHeight && side > 160 ? 3 : 2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.85)
        }
        .padding(Theme.tilePadding * min(unit, 1.2))
    }

    private var iconColor: Color {
        if !device.isReachable { return Theme.textLight }
        if lit && device.kind == .light { return Theme.yellow }
        return lit ? Theme.text : Theme.textLight
    }

    /// Rechtsboven: alarm, batterij, geen reactie of de belangrijkste waarde.
    @ViewBuilder
    private func indicator(unit: CGFloat, side: CGFloat) -> some View {
        if alarm {
            Text(verbatim: "!")
                .font(.system(size: 15 * unit, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: side * 0.24, height: side * 0.24)
                .background(Circle().fill(Theme.red))
                .symbolEffect(.pulse)
        } else if !device.isReachable {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14 * unit, weight: .semibold))
                .foregroundStyle(Theme.orange)
        } else if device.lowBattery {
            Image(systemName: "battery.25percent")
                .font(.system(size: 15 * unit, weight: .semibold))
                .foregroundStyle(Theme.red)
        } else if let value = indicatorValue {
            Text(value)
                .font(.system(size: (13 * unit).rounded(), weight: .medium))
                .foregroundStyle(lit ? Theme.textMedium : Theme.textLight)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .contentTransition(.numericText())
                .frame(maxWidth: side * 0.56, alignment: .topTrailing)
        }
    }

    private var indicatorValue: String? {
        switch device.kind {
        case .light:
            guard device.isOn, let b = device.brightness, b < 100 else { return nil }
            return "\(Int(b))%"
        case .thermostat, .heaterCooler, .temperature:
            return device.currentTemperature.map { "\($0.oneDecimal)°" }
        case .humidity, .humidifier:
            return device.number(HMCharacteristicTypeCurrentRelativeHumidity).map { "\(Int($0))%" }
        case .lux:
            return device.number(HMCharacteristicTypeCurrentLightLevel).map { "\(Int($0)) lx" }
        case .blinds, .window, .door:
            guard let p = device.position, p > 0, p < 100 else { return nil }
            return "\(Int(p))%"
        case .fan:
            guard device.isOn, let speed = device.number(HMCharacteristicTypeRotationSpeed) else { return nil }
            return "\(Int(speed))%"
        case .airQuality, .security:
            return device.stateText
        case .motion, .occupancy, .contact:
            return device.isOn ? device.stateText : nil
        default:
            return nil
        }
    }

    private func quickAction() {
        if device.isToggleable && device.isReachable {
            home.toggle(device)
            tapped += 1
        } else {
            opened += 1
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
