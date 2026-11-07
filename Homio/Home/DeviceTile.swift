import HomeKit
import SwiftUI

/// Icoon van een apparaat: het gekozen icoon (eigen of merk), anders het standaardicoon
/// dat met de stand meewisselt.
struct DeviceIcon: View {
    let key: String
    let fallback: String
    var size: CGFloat = 28
    @ObservedObject private var store = DeviceIconStore.shared

    init(device: Device, size: CGFloat = 28) {
        key = device.id.uuidString
        fallback = device.iconName
        self.size = size
    }

    init(key: String, fallback: String, size: CGFloat = 28) {
        self.key = key
        self.fallback = fallback
        self.size = size
    }

    var body: some View {
        Image(store.icon(for: key) ?? fallback)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .contentTransition(.opacity)
            .accessibilityHidden(true)
    }
}

/// Wat een tegel toont, los van waar het apparaat vandaan komt (HomeKit of Matter).
struct TileModel {
    var iconKey: String
    var iconName: String
    var name: String
    var kind: DeviceKind
    var isOn: Bool
    var isToggleable: Bool
    var isReachable: Bool
    var lowBattery: Bool
    var indicator: String?
    var accessibilityValue: String
    /// Klein "M"-label voor apparaten die via Homio's eigen Matter-netwerk lopen.
    var viaMatter = false

    /// Zonder snelle actie (sensoren) staat een tegel altijd "aan", net als in Homey.
    var lit: Bool { isToggleable ? isOn : true }
    var alarm: Bool { kind.isAlarm && isOn }
}

/// Apparaattegel zoals in de Homey-app: vierkant, icoon linksboven (1/3 van de breedte),
/// waarde rechtsboven, naam linksonder. Tik = snelle actie (zacht tikje), lang drukken =
/// apparaat openen (stevige tik), contextmenu met extra snelle acties.
/// Uit = component_off met haarlijn, aan = component_on met lichte schaduw.
struct TileFace<Menu: View>: View {
    let model: TileModel
    var minHeight: CGFloat = 0
    var fillsHeight = false
    let onTap: () -> Void
    let onOpen: () -> Void
    @ViewBuilder let menu: () -> Menu

    @State private var pressing = false
    @State private var tapped = 0
    @State private var opened = 0

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
                .fill(model.lit ? Theme.tileOn : Theme.tileOff)
                .overlay {
                    if !model.lit {
                        RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                            .strokeBorder(Theme.tileBorder, lineWidth: 1 / UIScreen.main.scale)
                    }
                }
                .shadow(color: .black.opacity(model.lit ? 0.12 : 0), radius: 3, y: 2)
        }
        .opacity(model.isReachable ? 1 : 0.55)
        .scaleEffect(pressing ? 0.96 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressing)
        .animation(.easeInOut(duration: 0.2), value: model.lit)
        .contentShape(RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous))
        .onTapGesture {
            if model.isToggleable && model.isReachable {
                tapped += 1
                onTap()
            } else {
                opened += 1
                onOpen()
            }
        }
        .onLongPressGesture(minimumDuration: 0.4, perform: {
            opened += 1
            onOpen()
        }, onPressingChanged: { isPressing in
            pressing = isPressing
        })
        .contextMenu { menu() }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: tapped)
        .sensoryFeedback(.impact(weight: .medium), trigger: opened)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.name), \(model.accessibilityValue)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(model.isToggleable ? "Tik om te schakelen, houd vast voor meer" : "Tik voor details")
    }

    private func content(unit: CGFloat, side: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                DeviceIcon(key: model.iconKey, fallback: model.iconName, size: 36 * unit)
                    .foregroundStyle(iconColor)
                    .opacity(model.lit ? 1 : 0.7)
                    .symbolEffect(.bounce, value: tapped)
                Spacer(minLength: 0)
                indicator(unit: unit, side: side)
            }
            Spacer(minLength: 4)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(model.name)
                    .font(.system(size: (14 * unit).rounded(), weight: .medium))
                    .lineSpacing(3 * unit)
                    .foregroundStyle(model.lit ? Theme.text : Theme.textMedium)
                    .lineLimit(fillsHeight && side > 160 ? 3 : 2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                if model.viaMatter {
                    Spacer(minLength: 0)
                    Text(verbatim: "M")
                        .font(.system(size: 9 * unit, weight: .heavy))
                        .foregroundStyle(Theme.textLight)
                        .padding(.horizontal, 3)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.textLight.opacity(0.6), lineWidth: 0.75))
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(Theme.tilePadding * min(unit, 1.2))
    }

    private var iconColor: Color {
        if !model.isReachable { return Theme.textLight }
        if model.lit && model.kind == .light { return Theme.yellow }
        return model.lit ? Theme.text : Theme.textLight
    }

    /// Rechtsboven: alarm, geen reactie, batterij of de belangrijkste waarde.
    @ViewBuilder
    private func indicator(unit: CGFloat, side: CGFloat) -> some View {
        if model.alarm {
            Text(verbatim: "!")
                .font(.system(size: 15 * unit, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: side * 0.24, height: side * 0.24)
                .background(Circle().fill(Theme.red))
        } else if !model.isReachable {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14 * unit, weight: .semibold))
                .foregroundStyle(Theme.orange)
        } else if model.lowBattery {
            Image(systemName: "battery.25percent")
                .font(.system(size: 15 * unit, weight: .semibold))
                .foregroundStyle(Theme.red)
        } else if let value = model.indicator {
            Text(value)
                .font(.system(size: (13 * unit).rounded(), weight: .medium))
                .foregroundStyle(model.lit ? Theme.textMedium : Theme.textLight)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .contentTransition(.numericText())
                .frame(maxWidth: side * 0.56, alignment: .topTrailing)
        }
    }
}

/// Tegel voor een HomeKit-apparaat.
struct DeviceTile: View {
    let device: Device
    var minHeight: CGFloat = 0
    var fillsHeight = false

    @EnvironmentObject private var home: HomeStore
    @State private var showDetail = false

    var body: some View {
        TileFace(model: model, minHeight: minHeight, fillsHeight: fillsHeight,
                 onTap: { home.toggle(device) },
                 onOpen: { showDetail = true }) {
            QuickActionsMenu(device: device, showDetail: $showDetail)
        }
        .sheet(isPresented: $showDetail) {
            DeviceDetailSheet(deviceID: device.id)
        }
    }

    private var model: TileModel {
        TileModel(iconKey: device.id.uuidString, iconName: device.iconName, name: device.name,
                  kind: device.kind, isOn: device.isOn, isToggleable: device.isToggleable,
                  isReachable: device.isReachable, lowBattery: device.lowBattery,
                  indicator: indicatorValue, accessibilityValue: device.stateText)
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

/// Sfeer als pil, zoals een Mood in Homey: rond verloop-icoon en de naam.
struct SceneChip: View {
    let name: String
    let symbol: String
    let action: () -> Void
    @State private var fired = 0

    var body: some View {
        Button {
            action()
            fired += 1
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.moodGradient))
                    .symbolEffect(.bounce, value: fired)
                Text(name)
                    .font(HomeyFont.smallMedium)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
            .padding(4)
            .padding(.trailing, 10)
            .frame(height: 40)
            .background(Capsule().fill(Theme.card).shadow(color: .black.opacity(0.12), radius: 3, y: 2))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.success, trigger: fired)
    }
}
