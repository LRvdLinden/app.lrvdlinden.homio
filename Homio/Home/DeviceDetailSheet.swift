import HomeKit
import SwiftUI

/// Apparaatscherm zoals in de Homey-app: schermvullend, achtergrond in de kleur van het
/// licht (of donker als het uit staat), ronde knoppen bovenaan (sluiten, favoriet,
/// instellingen) en onderaan een iconenbalk: bediening, helderheid, kleur, inzichten,
/// tijdlijn en flows.
struct DeviceDetailSheet: View {
    let deviceID: UUID

    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab: DeviceTab = .control

    var body: some View {
        NavigationStack {
            ZStack {
                if let device = home.device(id: deviceID) {
                    DeviceBackdrop(device: device).ignoresSafeArea()
                    VStack(spacing: 0) {
                        topBar(device)
                        Spacer(minLength: 12)
                        panel(device)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                            .id(tab)
                        Spacer(minLength: 12)
                        tabBar(device)
                            .padding(.bottom, 18)
                    }
                    .padding(.horizontal, Theme.edge)
                    .animation(.easeInOut(duration: 0.2), value: tab)
                } else {
                    ContentUnavailableView("Apparaat niet gevonden", systemImage: "questionmark.circle")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .environment(\.colorScheme, .dark)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .onAppear {
            if let d = home.device(id: deviceID), d.kind == .light,
               d.characteristic(HMCharacteristicTypeBrightness) != nil {
                tab = .dim
            }
        }
    }

    // MARK: Bovenbalk

    private func topBar(_ device: Device) -> some View {
        HStack {
            circleButton("chevron.down") { dismiss() }
                .accessibilityLabel("Sluiten")
            Spacer()
            Text(device.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            circleButton(settings.isFavorite(deviceID) ? "heart.fill" : "heart") {
                settings.toggleFavorite(deviceID)
            }
            .accessibilityLabel(settings.isFavorite(deviceID) ? "Uit favorieten" : "Aan favorieten")
            NavigationLink {
                DeviceManageView(deviceID: deviceID)
                    .environment(\.colorScheme, .light)
            } label: {
                circleLabel("gearshape.fill")
            }
            .accessibilityLabel("Instellingen")
        }
        .padding(.top, 14)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { circleLabel(symbol) }
            .buttonStyle(PressableStyle())
    }

    private func circleLabel(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(.white.opacity(0.18)))
    }

    // MARK: Iconenbalk onderaan

    private func tabs(for device: Device) -> [DeviceTab] {
        var list: [DeviceTab] = []
        if device.isToggleable || !device.kind.isSensor { list.append(.control) }
        if device.kind == .light, device.characteristic(HMCharacteristicTypeBrightness) != nil { list.append(.dim) }
        if device.kind == .light,
           device.characteristic(HMCharacteristicTypeHue) != nil || device.characteristic(HMCharacteristicTypeColorTemperature) != nil {
            list.append(.color)
        }
        if device.kind.isSensor { list.insert(.control, at: 0) }
        list.append(contentsOf: [.insights, .timeline, .flows])
        return list
    }

    private func tabBar(_ device: Device) -> some View {
        HStack(spacing: 22) {
            ForEach(tabs(for: device), id: \.self) { t in
                Button { tab = t } label: {
                    Image(systemName: t.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(tab == t ? 1 : 0.45))
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel(t.title)
            }
        }
        .sensoryFeedback(.selection, trigger: tab)
    }

    // MARK: Inhoud per tab

    @ViewBuilder
    private func panel(_ device: Device) -> some View {
        switch tab {
        case .control:
            DeviceControls(device: device)
        case .dim:
            HomeyDimSlider(device: device)
        case .color:
            LightColorPanel(device: device)
        case .insights:
            DeviceInsightsPanel(device: device)
        case .timeline:
            DeviceTimelinePanel(device: device)
        case .flows:
            DeviceFlowsPanel(device: device)
        }
    }
}

enum DeviceTab: Hashable {
    case control, dim, color, insights, timeline, flows

    var symbol: String {
        switch self {
        case .control: return "switch.2"
        case .dim: return "slider.horizontal.below.sun.max"
        case .color: return "paintpalette.fill"
        case .insights: return "chart.bar.fill"
        case .timeline: return "clock.fill"
        case .flows: return "arrow.triangle.branch"
        }
    }

    var title: String {
        switch self {
        case .control: return "Bediening"
        case .dim: return "Helderheid"
        case .color: return "Kleur"
        case .insights: return "Inzichten"
        case .timeline: return "Tijdlijn"
        case .flows: return "Flows"
        }
    }
}

/// Achtergrond in de kleur van het apparaat, zoals Homey: warm goud voor een lamp die aan
/// staat (of de lampkleur), donkergrijs als hij uit staat, blauwgrijs voor andere apparaten.
struct DeviceBackdrop: View {
    let device: Device

    var body: some View {
        let top: Color
        if device.kind == .light && device.isOn {
            if let hue = device.number(HMCharacteristicTypeHue), let sat = device.number(HMCharacteristicTypeSaturation), sat > 15 {
                top = Color(hue: hue / 360, saturation: min(0.75, sat / 100), brightness: 0.62)
            } else {
                top = Color(red: 0x8A / 255, green: 0x72 / 255, blue: 0x33 / 255)
            }
        } else if device.isOn && !device.kind.isSensor {
            top = Color(red: 0x2C / 255, green: 0x55 / 255, blue: 0x8C / 255)
        } else {
            top = Color(red: 0x3B / 255, green: 0x3D / 255, blue: 0x4A / 255)
        }
        return LinearGradient(colors: [top, Self.darker(top, by: 0.6)], startPoint: .top, endPoint: .bottom)
            .animation(.easeInOut(duration: 0.4), value: device.isOn)
    }
}

extension DeviceBackdrop {
    /// Kleur richting zwart schuiven (werkt ook op iOS 17, zonder Color.mix).
    static func darker(_ color: Color, by amount: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let k = 1 - amount
        return Color(red: r * k, green: g * k, blue: b * k)
    }
}

/// Dimmer zoals Homey: doorzichtige baan, witte vulling met een marge, zonnetjes erboven en
/// eronder, en een procent-bubbel tijdens het slepen.
struct HomeyDimSlider: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore
    @State private var value: Double = 0
    @State private var dragging = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sun.max.fill").font(.title2).foregroundStyle(.white)
            GeometryReader { geo in
                let h = geo.size.height
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.2))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white)
                        .frame(height: max(0, (h - 12) * value))
                        .padding(6)
                        .opacity(value > 0.005 ? 1 : 0)
                }
                .overlay(alignment: .topLeading) {
                    if dragging {
                        Text("\(Int((value * 100).rounded()))%")
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.25)))
                            .offset(x: -64, y: max(0, min(h - 30, h - (h - 12) * value - 15)))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            dragging = true
                            value = min(1, max(0, 1 - g.location.y / h))
                        }
                        .onEnded { _ in
                            dragging = false
                            commit()
                        }
                )
            }
            .frame(width: 96, height: 330)
            Image(systemName: "sun.min").font(.title2).foregroundStyle(.white)
        }
        .sensoryFeedback(.selection, trigger: Int(value * 10))
        .onAppear { value = device.isOn ? (device.brightness ?? 100) / 100 : 0 }
        .accessibilityElement()
        .accessibilityLabel("Helderheid")
        .accessibilityValue("\(Int(value * 100)) procent")
        .accessibilityAdjustableAction { direction in
            value = min(1, max(0, value + (direction == .increment ? 0.1 : -0.1)))
            commit()
        }
    }

    private func commit() {
        let percent = Int((value * 100).rounded())
        if percent == 0 {
            home.write(device.characteristic(HMCharacteristicTypePowerState), false)
        } else {
            if !device.isOn { home.write(device.characteristic(HMCharacteristicTypePowerState), true) }
            home.write(device.characteristic(HMCharacteristicTypeBrightness), percent)
        }
    }
}

/// Inzichten van dit apparaat (de metingen die Homio bijhoudt).
private struct DeviceInsightsPanel: View {
    let device: Device
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        let metrics = history.sortedMetrics.filter { $0.deviceID == device.id }
        if let metric = metrics.first {
            InsightsCard(metric: metric, metrics: metrics) { _ in }
                .environment(\.colorScheme, .light)
        } else {
            emptyText("Nog geen inzichten", "Homio meet dit apparaat zodra er waarden binnenkomen.")
        }
    }
}

/// Wat er met dit apparaat gebeurde, zoals de tijdlijn in Homey.
private struct DeviceTimelinePanel: View {
    let device: Device
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        let entries = Array(history.log.filter { $0.title == device.name }.prefix(12))
        if entries.isEmpty {
            emptyText("Nog niets gebeurd", "Hier zie je wanneer dit apparaat aan of uit ging.")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entries.indices, id: \.self) { i in
                        let e = entries[i]
                        HStack(alignment: .top, spacing: 14) {
                            DeviceIcon(device: device, size: 18)
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(.white.opacity(0.2)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.detail).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                Text(e.date.formatted(.relative(presentation: .named)))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Flows met dit apparaat, of een knop om er een te maken.
private struct DeviceFlowsPanel: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var flows: FlowStore
    @State private var editing: FlowEditTarget?

    var body: some View {
        let related = home.triggers.filter { flows.summary(for: $0).contains(device.name) }
        VStack(spacing: 14) {
            if related.isEmpty {
                emptyText("Begin met automatiseren.", "Er zijn nog geen flows voor dit apparaat.")
            } else {
                ForEach(related, id: \.uniqueIdentifier) { trigger in
                    HStack(spacing: 12) {
                        FlowRunButton(trigger: trigger, size: 32)
                        Text(trigger.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(8)
                    .background(Capsule().fill(.white.opacity(0.15)))
                }
            }
            Button {
                var draft = FlowDraft(name: device.name)
                if device.canTrigger {
                    draft.when.kind = .device
                    draft.when.deviceID = device.id
                    draft.when.event = DeviceEventKind.options(for: device.kind).first ?? .turnsOn
                }
                editing = FlowEditTarget(draft: draft, trigger: nil)
            } label: {
                Label("Maak een flow", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(Capsule().fill(.white.opacity(0.2)))
            }
            .buttonStyle(PressableStyle())
        }
        .sheet(item: $editing) { target in
            FlowEditorView(initial: target.draft, replacing: nil)
                .environment(\.colorScheme, .light)
        }
    }
}

private func emptyText(_ title: String, _ detail: String) -> some View {
    VStack(spacing: 6) {
        Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
        Text(detail).font(.system(size: 14)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
    }
    .padding()
}

private struct DeviceControls: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        VStack(spacing: 28) {
            switch device.kind {
            case .light:
                // Helderheid en kleur zitten in de iconenbalk; hier alleen aan/uit, zoals Homey.
                PowerButton(device: device)
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
                .foregroundStyle(device.isOn ? Theme.green : Color.white.opacity(0.7))
                .frame(width: 140, height: 140)
                .background(Circle().fill(device.isOn ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.18))))
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
