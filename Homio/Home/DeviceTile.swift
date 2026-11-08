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

/// Apparaattegel zoals in de Homey-app (nagemeten uit de app zelf):
/// vierkant, lijn-icoon linksboven, rond snelle-actieknopje rechtsboven (grijs bij uit,
/// lichtblauw met blauw icoon bij aan), naam en daaronder status of waarde.
/// Uit = grijs vlak, aan of sensor = wit vlak. Tik op de tegel = openen, tik op het
/// knopje = snelle actie, lang drukken = menu.
struct TileFace<Menu: View>: View {
    let model: TileModel
    var minHeight: CGFloat = 0
    var fillsHeight = false
    let onTap: () -> Void
    let onOpen: () -> Void
    @ViewBuilder let menu: () -> Menu

    @State private var tapped = 0
    @State private var opened = 0

    var body: some View {
        GeometryReader { geo in
            let side = fillsHeight ? min(geo.size.width, geo.size.height) : geo.size.width
            let unit = max(0.75, min(1.5, side / 84))
            content(unit: unit)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .aspectRatio(fillsHeight ? nil : 1, contentMode: .fit)
        .frame(minHeight: minHeight > 0 ? minHeight : nil)
        .background {
            RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous)
                .fill(model.lit ? Theme.tileOn : Theme.tileOff)
                .shadow(color: .black.opacity(model.lit ? 0.08 : 0), radius: 3, y: 1)
        }
        .opacity(model.isReachable ? 1 : 0.85)
        .contentShape(RoundedRectangle(cornerRadius: Theme.tileCorner, style: .continuous))
        .onTapGesture {
            opened += 1
            onOpen()
        }
        .contextMenu { menu() }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: tapped)
        .sensoryFeedback(.impact(weight: .medium), trigger: opened)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(model.name), \(model.accessibilityValue)")
        .accessibilityAddTraits(.isButton)
    }

    private func content(unit: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                DeviceIcon(key: model.iconKey, fallback: model.iconName, size: 30 * unit)
                    .foregroundStyle(model.isReachable ? Theme.text : Theme.textLight)
                    .symbolEffect(.bounce, value: tapped)
                Spacer(minLength: 2)
                if model.isToggleable && model.isReachable {
                    quickButton(unit: unit)
                }
            }
            Spacer(minLength: 2)
            Text(model.name)
                .font(.system(size: (11.5 * unit).rounded(), weight: .regular))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.85)
            status(unit: unit)
                .padding(.top, 1)
        }
        .padding(8 * unit)
    }

    /// Rond knopje rechtsboven, zoals de snelle actie in Homey.
    private func quickButton(unit: CGFloat) -> some View {
        Button {
            tapped += 1
            onTap()
        } label: {
            Image(systemName: quickSymbol)
                .font(.system(size: 13 * unit, weight: .semibold))
                .foregroundStyle(model.isOn ? Theme.accent : Theme.textMedium)
                .frame(width: 26 * unit, height: 26 * unit)
                .background(Circle().fill(model.isOn ? Theme.quickOn : Theme.quickOff))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(model.isOn ? "Uitzetten" : "Aanzetten")
    }

    private var quickSymbol: String {
        switch model.kind {
        case .lock: return model.isOn ? "lock.fill" : "lock.open"
        case .blinds, .window, .door, .garage: return model.isOn ? "chevron.down" : "chevron.up"
        case .speaker, .tv, .vacuum: return model.isOn ? "pause.fill" : "play.fill"
        default: return "power"
        }
    }

    /// Regel onder de naam: geen reactie (rood), alarm, batterij, waarde of aan/uit.
    @ViewBuilder
    private func status(unit: CGFloat) -> some View {
        let font = Font.system(size: (10 * unit).rounded())
        if !model.isReachable {
            Label("Geen reactie", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(TightLabel())
                .font(font)
                .foregroundStyle(Theme.red)
                .lineLimit(1)
        } else if model.alarm {
            Label(model.accessibilityValue, systemImage: "exclamationmark.octagon.fill")
                .labelStyle(TightLabel())
                .font(font.weight(.semibold))
                .foregroundStyle(Theme.red)
                .lineLimit(1)
        } else if model.lowBattery {
            Label("Batterij bijna leeg", systemImage: "battery.25percent")
                .labelStyle(TightLabel())
                .font(font)
                .foregroundStyle(Theme.orange)
                .lineLimit(1)
        } else if let value = model.indicator {
            Text(value).font(font).foregroundStyle(Theme.textLight).lineLimit(1)
                .contentTransition(.numericText())
        } else if model.isToggleable {
            Text(model.isOn ? "Aan" : "Uit").font(font).foregroundStyle(Theme.textLight)
        }
    }
}

/// Icoon en tekst dicht op elkaar (voor de statusregel van een tegel).
struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
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
        Button { showDetail = true } label: { Label("Openen", systemImage: "arrow.up.forward.square") }
        Divider()
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
