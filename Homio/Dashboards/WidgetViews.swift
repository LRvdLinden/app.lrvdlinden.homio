import HomeKit
import SwiftUI

/// Kiest de juiste weergave voor een widget.
struct WidgetView: View {
    let widget: DashWidget

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch widget.kind {
        case .device: DeviceWidget(deviceID: widget.deviceID, size: widget.size)
        case .group: GroupWidget(groupID: widget.groupID)
        case .scene: SceneWidget(sceneID: widget.sceneID, size: widget.size)
        case .room: RoomWidget(roomName: widget.roomName, size: widget.size)
        case .clock: ClockWidget(size: widget.size)
        case .weather: WeatherWidget(size: widget.size)
        case .camera: CameraWidget(cameraID: widget.cameraID)
        case .chart: ChartWidget(metricKey: widget.metricKey, size: widget.size)
        case .timers: TimersWidget(size: widget.size)
        case .calendar: CalendarWidget(size: widget.size)
        case .flows: FlowsWidget(size: widget.size)
        case .note: NoteWidget(text: widget.text, size: widget.size)
        }
    }
}

/// Kaart om een widget heen.
struct WidgetCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct WidgetPlaceholder: View {
    let symbol: String
    let text: String

    var body: some View {
        WidgetCard {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title2)
                Text(text).font(.footnote).multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct WidgetHeader: View {
    let title: String
    let symbol: String
    var color: Color = IconPalette.orange

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

// MARK: Apparaat

private struct DeviceWidget: View {
    let deviceID: UUID?
    let size: WidgetSize
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        if let id = deviceID, let device = home.device(id: id) {
            switch size {
            case .small:
                DeviceTile(device: device, minHeight: 0, fillsHeight: true)
            case .wide:
                HStack(spacing: 12) {
                    DeviceTile(device: device, minHeight: 0, fillsHeight: true)
                    WidgetCard(padding: 12) { DeviceQuickControl(device: device) }
                }
            case .large:
                VStack(spacing: 12) {
                    DeviceTile(device: device, minHeight: 0, fillsHeight: true)
                    WidgetCard(padding: 14) { DeviceQuickControl(device: device) }
                }
            }
        } else {
            WidgetPlaceholder(symbol: "questionmark.circle", text: "Apparaat niet gevonden")
        }
    }
}

/// Snelle bediening naast een apparaat: helderheid, positie, snelheid of temperatuur.
struct DeviceQuickControl: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore
    @State private var value: Double = 0

    private var sliderType: String? {
        switch device.kind {
        case .light: return device.characteristic(HMCharacteristicTypeBrightness) != nil ? HMCharacteristicTypeBrightness : nil
        case .blinds: return HMCharacteristicTypeTargetPosition
        case .fan: return device.characteristic(HMCharacteristicTypeRotationSpeed) != nil ? HMCharacteristicTypeRotationSpeed : nil
        default: return nil
        }
    }

    private var current: Double {
        switch device.kind {
        case .light: return device.isOn ? (device.brightness ?? 100) : 0
        case .blinds: return device.position ?? 0
        case .fan: return device.number(HMCharacteristicTypeRotationSpeed) ?? 0
        case .thermostat: return device.targetTemperature ?? device.currentTemperature ?? 20
        default: return 0
        }
    }

    var body: some View {
        Group {
            if device.kind == .thermostat {
                thermostat
            } else if let type = sliderType {
                slider(type)
            } else {
                power
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { value = current }
        .onChange(of: current) { _, newValue in value = newValue }
    }

    private func slider(_ type: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(value > 0 ? "\(Int(value))%" : (device.kind == .blinds ? "Dicht" : "Uit"))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Slider(value: $value, in: 0...100, step: 1) { editing in
                guard !editing else { return }
                commit(type)
            }
            .tint(device.tint)
        }
    }

    private func commit(_ type: String) {
        let percent = Int(value.rounded())
        if device.kind == .light {
            if percent == 0 {
                home.write(device.characteristic(HMCharacteristicTypePowerState), false)
                return
            }
            if !device.isOn { home.write(device.characteristic(HMCharacteristicTypePowerState), true) }
        }
        home.write(device.characteristic(type), percent)
    }

    private var thermostat: some View {
        HStack(spacing: 10) {
            stepper("minus", -0.5)
            VStack(spacing: 0) {
                Text("\(value.oneDecimal)°")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                if let now = device.currentTemperature {
                    Text("nu \(now.oneDecimal)°").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            stepper("plus", 0.5)
        }
    }

    private func stepper(_ symbol: String, _ delta: Double) -> some View {
        Button {
            value = min(32, max(8, value + delta))
            home.write(device.characteristic(HMCharacteristicTypeTargetTemperature), NSNumber(value: value))
        } label: {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.12)))
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.white)
    }

    private var power: some View {
        Button { home.toggle(device) } label: {
            VStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(device.isOn ? Color.black : Color.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(device.isOn ? AnyShapeStyle(device.tint) : AnyShapeStyle(Color.white.opacity(0.12))))
                Text(device.stateText).font(.caption).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(!device.isToggleable)
    }
}

// MARK: Sfeer

private struct SceneWidget: View {
    let sceneID: UUID?
    let size: WidgetSize
    @EnvironmentObject private var home: HomeStore
    @State private var fired = false

    var body: some View {
        if let scene = home.scene(id: sceneID) {
            Button {
                home.run(scene)
                fired.toggle()
            } label: {
                WidgetCard {
                    VStack(alignment: .leading, spacing: 8) {
                        GradientIcon(symbol: scene.symbol, size: size == .small ? 42 : 52)
                            .symbolEffect(.bounce, value: fired)
                        Spacer(minLength: 0)
                        Text(scene.name).font(.headline).lineLimit(2)
                        Text("Tik om te starten").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(PressableStyle())
            .foregroundStyle(.white)
            .sensoryFeedback(.success, trigger: fired)
        } else {
            WidgetPlaceholder(symbol: "sparkles", text: "Sfeer niet gevonden")
        }
    }
}

// MARK: Kamer of hele huis

private struct RoomWidget: View {
    let roomName: String?
    let size: WidgetSize
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        let devices = home.devices(inRoom: roomName)
        let lights = devices.filter { $0.kind == .light }
        let lightsOn = lights.filter(\.isOn).count
        let temps = devices.compactMap { $0.kind == .temperature || $0.kind == .thermostat ? $0.currentTemperature : nil }
        WidgetCard {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: roomName ?? "Hele huis", symbol: roomName == nil ? "house.fill" : "square.split.bottomrightquarter.fill")
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    if !temps.isEmpty {
                        Text("\((temps.reduce(0, +) / Double(temps.count)).oneDecimal)°")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                    }
                    Text(lightsOn == 1 ? "1 lamp aan" : "\(lightsOn) lampen aan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if size == .large {
                    VStack(spacing: 6) {
                        ForEach(devices.filter { $0.isToggleable }.prefix(5)) { device in
                            MiniDeviceRow(device: device)
                        }
                    }
                }
                Spacer(minLength: 0)
                if !lights.isEmpty {
                    HStack(spacing: 8) {
                        Button { home.setLights(on: true, room: roomName) } label: {
                            Label("Aan", systemImage: "lightbulb.fill").frame(maxWidth: .infinity)
                        }
                        Button { home.setLights(on: false, room: roomName) } label: {
                            Label("Uit", systemImage: "lightbulb.slash").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(IconPalette.yellow)
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
    }
}

private struct MiniDeviceRow: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore

    var body: some View {
        Button { home.toggle(device) } label: {
            HStack(spacing: 10) {
                Image(systemName: device.symbol)
                    .foregroundStyle(device.isOn ? device.tint : .secondary)
                    .frame(width: 24)
                Text(device.name).lineLimit(1)
                Spacer()
                Text(device.stateText).font(.caption).foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(device.isOn ? 0.12 : 0.05)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Klok

private struct ClockWidget: View {
    let size: WidgetSize

    var body: some View {
        WidgetCard {
            if size == .large {
                VStack(spacing: 10) {
                    AnalogClockView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 2) {
                        Spacer(minLength: 0)
                        Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                            .font(.system(size: size == .small ? 44 : 60, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(context.date.formatted(.dateTime.weekday(size == .small ? .abbreviated : .wide).day().month(.abbreviated)).capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: Weer

private struct WeatherWidget: View {
    let size: WidgetSize
    @EnvironmentObject private var weather: WeatherService

    var body: some View {
        WidgetCard {
            if let current = weather.current {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: WeatherService.symbol(for: current.code, isDay: current.isDay))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 34))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(Int(current.temperature.rounded()))°")
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                            Text(weather.place.isEmpty ? WeatherService.description(for: current.code) : weather.place)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    if size != .small {
                        Spacer(minLength: 0)
                        HStack(spacing: 0) {
                            ForEach(weather.hours.prefix(6)) { hour in
                                VStack(spacing: 4) {
                                    Text(hour.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: WeatherService.symbol(for: hour.code))
                                        .symbolRenderingMode(.multicolor)
                                    Text("\(Int(hour.temperature.rounded()))°").font(.caption.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    if size == .large {
                        Divider().overlay(.white.opacity(0.15))
                        ForEach(weather.days.prefix(4)) { day in
                            HStack {
                                Text(Calendar.current.isDateInToday(day.date) ? "Vandaag" : day.date.formatted(.dateTime.weekday(.abbreviated)).capitalized)
                                    .frame(width: 70, alignment: .leading)
                                Image(systemName: WeatherService.symbol(for: day.code)).symbolRenderingMode(.multicolor)
                                Spacer()
                                Text("\(Int(day.low.rounded()))°").foregroundStyle(.secondary)
                                Text("\(Int(day.high.rounded()))°")
                            }
                            .font(.subheadline)
                        }
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "cloud.sun").font(.title)
                    Text(weather.problem ?? "Weer laden…").font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { weather.start() }
    }
}

// MARK: Camera

private struct CameraWidget: View {
    let cameraID: UUID?
    @EnvironmentObject private var home: HomeStore
    @State private var live = false

    var body: some View {
        if let accessory = home.cameras.first(where: { $0.uniqueIdentifier == cameraID }) ?? (cameraID == nil ? home.cameras.first : nil) {
            let feed = home.feed(for: accessory)
            CameraTile(feed: feed)
                .onTapGesture { live = true }
                .fullScreenCover(isPresented: $live) { CameraLiveView(feed: feed) }
        } else {
            WidgetPlaceholder(symbol: "video.slash", text: "Camera niet gevonden")
        }
    }
}

// MARK: Grafiek

private struct ChartWidget: View {
    let metricKey: String?
    let size: WidgetSize
    @EnvironmentObject private var history: HistoryStore
    @State private var showDetail = false

    var body: some View {
        if let key = metricKey, let metric = history.metrics[key] {
            Button { showDetail = true } label: {
                WidgetCard {
                    VStack(alignment: .leading, spacing: 6) {
                        WidgetHeader(title: metric.name, symbol: metric.kind.symbol, color: metric.kind.color)
                        Text(history.latest(key).map { metric.kind.format($0) } ?? "–")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                        MetricSparkline(metric: metric, hours: 24)
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDetail) { MetricDetailView(metric: metric) }
        } else {
            WidgetPlaceholder(symbol: "chart.xyaxis.line", text: "Nog geen metingen")
        }
    }
}

// MARK: Timers

private struct TimersWidget: View {
    let size: WidgetSize
    @EnvironmentObject private var timers: TimersStore

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: "Timers", symbol: "timer")
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 6) {
                        if timers.timers.isEmpty {
                            Text("Geen timers").font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(timers.timers.prefix(size == .large ? 4 : 1)) { timer in
                            HStack {
                                Text(timer.label).lineLimit(1)
                                Spacer()
                                Text(TimersStore.format(timer.remaining(at: context.date)))
                                    .monospacedDigit()
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    ForEach([5, 10, 15], id: \.self) { minutes in
                        Button {
                            timers.add(seconds: TimeInterval(minutes * 60), label: "")
                        } label: {
                            Text("\(minutes) min").frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .font(.subheadline.weight(.semibold))
            }
        }
    }
}

// MARK: Agenda

private struct CalendarWidget: View {
    let size: WidgetSize
    @EnvironmentObject private var calendar: CalendarService

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(title: "Agenda", symbol: "calendar")
                if calendar.events.isEmpty {
                    Text(calendar.denied ? "Geen toegang tot Agenda" : "Niets gepland")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(calendar.events.prefix(size == .large ? 6 : 2), id: \.self) { event in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(event.color).frame(width: 4, height: 30)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(event.title ?? "Afspraak").font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(event.timeText).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .onAppear { calendar.start() }
    }
}

// MARK: Flows

private struct FlowsWidget: View {
    let size: WidgetSize
    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var flows: FlowStore

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(title: "Flows", symbol: "arrow.triangle.branch", color: IconPalette.blue)
                if home.triggers.isEmpty {
                    Text("Nog geen flows").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(home.triggers.prefix(size == .large ? 6 : 2), id: \.uniqueIdentifier) { trigger in
                    HStack {
                        Circle()
                            .fill(trigger.isEnabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(trigger.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        Button { flows.run(trigger) } label: {
                            Image(systemName: "play.fill")
                                .font(.caption)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(IconPalette.blue))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Nu uitvoeren")
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: Notitie

private struct NoteWidget: View {
    let text: String
    let size: WidgetSize

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(title: "Notitie", symbol: "note.text", color: IconPalette.yellow)
                Text(text.isEmpty ? "Tik in bewerkmodus op deze notitie om tekst te schrijven." : text)
                    .font(text.isEmpty ? .footnote : (size == .large ? .title2 : .title3))
                    .foregroundStyle(text.isEmpty ? Color.secondary : Color.white)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: Groep

private struct GroupWidget: View {
    let groupID: UUID?
    @EnvironmentObject private var groups: GroupStore

    var body: some View {
        if let group = groups.group(id: groupID) {
            GroupTile(group: group, minHeight: 0, fillsHeight: true)
        } else {
            WidgetPlaceholder(symbol: "lightbulb.2", text: "Groep niet gevonden")
        }
    }
}
