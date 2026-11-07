import HomeKit
import SwiftUI

/// Kleur en wit voor een lamp: een kleurwiel en een schuif voor warm-tot-koel wit.
struct LightColorPanel: View {
    let device: Device
    @EnvironmentObject private var home: HomeStore

    @State private var mode = 0
    @State private var hue: Double = 30
    @State private var saturation: Double = 60
    @State private var mireds: Double = 300

    private var hasColor: Bool { device.characteristic(HMCharacteristicTypeHue) != nil }
    private var hasTemperature: Bool { device.characteristic(HMCharacteristicTypeColorTemperature) != nil }

    private var miredRange: ClosedRange<Double> {
        let meta = device.characteristic(HMCharacteristicTypeColorTemperature)?.metadata
        let low = meta?.minimumValue?.doubleValue ?? 140
        let high = meta?.maximumValue?.doubleValue ?? 500
        return low...max(low + 1, high)
    }

    var body: some View {
        if hasColor || hasTemperature {
            VStack(spacing: 18) {
                if hasColor && hasTemperature {
                    Picker("Soort", selection: $mode) {
                        Text("Kleur").tag(0)
                        Text("Wit").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
                if hasColor && (mode == 0 || !hasTemperature) {
                    ColorWheel(hue: $hue, saturation: $saturation) {
                        home.setColor(device, hue: hue, saturation: saturation)
                    }
                    .frame(width: 230, height: 230)
                    QuickColors { h, s in
                        hue = h
                        saturation = s
                        home.setColor(device, hue: h, saturation: s)
                    }
                } else if hasTemperature {
                    ColorTemperatureSlider(mireds: $mireds, range: miredRange) {
                        home.setColorTemperature(device, mireds: Int(mireds.rounded()))
                    }
                    .frame(maxWidth: 320)
                }
            }
            .onAppear {
                hue = device.number(HMCharacteristicTypeHue) ?? hue
                saturation = device.number(HMCharacteristicTypeSaturation) ?? saturation
                mireds = device.number(HMCharacteristicTypeColorTemperature) ?? mireds
                if hasTemperature && saturation < 15 { mode = 1 }
            }
        }
    }
}

/// Kleurwiel: hoek = tint, afstand tot het midden = verzadiging.
struct ColorWheel: View {
    @Binding var hue: Double          // 0...360
    @Binding var saturation: Double   // 0...100
    var onCommit: () -> Void

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            let angle = hue * .pi / 180
            let distance = CGFloat(saturation / 100) * radius
            ZStack {
                Circle()
                    .fill(AngularGradient(
                        gradient: Gradient(colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
                            Color(hue: $0, saturation: 1, brightness: 1)
                        }),
                        center: .center))
                Circle()
                    .fill(RadialGradient(colors: [.white, .white.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: radius))
                Circle()
                    .fill(Color(hue: hue / 360, saturation: saturation / 100, brightness: 1))
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.35), radius: 4)
                    .position(x: radius + CGFloat(cos(angle)) * distance,
                              y: radius + CGFloat(sin(angle)) * distance)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let dx = g.location.x - radius
                        let dy = g.location.y - radius
                        var degrees = Double(atan2(dy, dx)) * 180 / .pi
                        if degrees < 0 { degrees += 360 }
                        hue = degrees
                        saturation = Double(min(1, hypot(dx, dy) / radius)) * 100
                    }
                    .onEnded { _ in onCommit() }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Kleur")
        .accessibilityValue("Tint \(Int(hue)) graden, verzadiging \(Int(saturation)) procent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: hue = (hue + 15).truncatingRemainder(dividingBy: 360)
            case .decrement: hue = (hue + 345).truncatingRemainder(dividingBy: 360)
            @unknown default: break
            }
            onCommit()
        }
    }
}

/// Een rij veelgebruikte kleuren.
private struct QuickColors: View {
    let pick: (Double, Double) -> Void

    private let colors: [(String, Double, Double)] = [
        ("Warm", 30, 55), ("Rood", 0, 100), ("Oranje", 28, 100), ("Geel", 50, 100),
        ("Groen", 120, 100), ("Blauw", 220, 100), ("Paars", 280, 100), ("Roze", 320, 70)
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(colors.indices, id: \.self) { i in
                let c = colors[i]
                Button { pick(c.1, c.2) } label: {
                    Circle()
                        .fill(Color(hue: c.1 / 360, saturation: c.2 / 100, brightness: 1))
                        .frame(width: 30, height: 30)
                        .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(c.0)
            }
        }
    }
}

/// Wit van warm (veel mireds) tot koel (weinig mireds), getoond in Kelvin.
struct ColorTemperatureSlider: View {
    @Binding var mireds: Double
    let range: ClosedRange<Double>
    var onCommit: () -> Void

    private var kelvin: Int { Int((1_000_000 / max(1, mireds)).rounded() / 50) * 50 }

    var body: some View {
        VStack(spacing: 12) {
            Text("\(kelvin) K")
                .font(.title2.monospacedDigit().weight(.semibold))
            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.3),
                                                  Color(red: 1, green: 0.93, blue: 0.85),
                                                  Color(red: 0.8, green: 0.9, blue: 1)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 14)
                // Links warm, rechts koel: de schuif loopt dus van veel naar weinig mireds.
                Slider(value: Binding(
                    get: { range.upperBound + range.lowerBound - mireds },
                    set: { mireds = range.upperBound + range.lowerBound - $0 }
                ), in: range) { editing in
                    if !editing { onCommit() }
                }
                .tint(.clear)
            }
            HStack {
                Text("Warm").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Koel").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
