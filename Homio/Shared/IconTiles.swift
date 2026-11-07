import SwiftUI

/// Kleuren van het app-icoon.
enum IconPalette {
    static let background = Color(red: 0.082, green: 0.090, blue: 0.110)
    static let clockTile = Color(red: 0.961, green: 0.961, blue: 0.969)
    static let ink = Color(red: 0.110, green: 0.110, blue: 0.118)
    static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let darkTile = Color(red: 0.173, green: 0.173, blue: 0.188)
    static let track = Color(red: 0.275, green: 0.275, blue: 0.298)
    static let yellow = Color(red: 1.0, green: 0.80, blue: 0.0)
    static let bulb = Color(red: 0.157, green: 0.133, blue: 0.039)
    static let blue = Color(red: 0.039, green: 0.518, blue: 1.0)

    /// Hoekafronding van een tegel, als deel van de tegelgrootte (zoals in het icoon).
    static let cornerRatio: CGFloat = 0.247
}

// MARK: Klok

struct ClockTile: View {
    var size: CGFloat
    var active: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * IconPalette.cornerRatio, style: .continuous)
                .fill(IconPalette.clockTile)

            ForEach(0..<12, id: \.self) { i in
                let major = i % 3 == 0
                Capsule()
                    .fill(IconPalette.ink)
                    .frame(width: size * (major ? 0.042 : 0.021), height: size * (major ? 0.075 : 0.048))
                    .offset(y: -size * (major ? 0.302 : 0.316))
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            // Wijzers draaien bij het starten een rondje en landen op 10:09.
            hand(length: size * 0.17, width: size * 0.053, color: IconPalette.ink,
                 degrees: active ? 303 : -57)
            hand(length: size * 0.245, width: size * 0.038, color: IconPalette.ink,
                 degrees: active ? 54 : -666)
            hand(length: size * 0.27, width: size * 0.018, color: IconPalette.orange,
                 degrees: active ? 228 : -132)

            Circle()
                .fill(IconPalette.orange)
                .frame(width: size * 0.07, height: size * 0.07)
        }
        .frame(width: size, height: size)
    }

    private func hand(length: CGFloat, width: CGFloat, color: Color, degrees: Double) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length + width)
            .offset(y: -(length - width) / 2)
            .rotationEffect(.degrees(degrees))
    }
}

// MARK: Thermostaat

struct ThermostatTile: View {
    var size: CGFloat
    var active: Bool

    private let start = 0.0
    private let full = 0.75          // 270° spoor
    private let filled = 0.5417      // 195° oranje

    var body: some View {
        let lineWidth = size * 0.088
        let diameter = size * 0.64 - lineWidth
        ZStack {
            RoundedRectangle(cornerRadius: size * IconPalette.cornerRatio, style: .continuous)
                .fill(IconPalette.darkTile)

            Circle()
                .trim(from: 0, to: full)
                .stroke(IconPalette.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
                .frame(width: diameter, height: diameter)

            Circle()
                .trim(from: 0, to: active ? filled : 0.001)
                .stroke(IconPalette.orange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
                .frame(width: diameter, height: diameter)

            ArcKnob(progress: active ? filled : 0.001, radius: diameter / 2, knob: lineWidth)
                .fill(.white)
                .frame(width: diameter, height: diameter)

            Circle()
                .fill(IconPalette.orange)
                .frame(width: size * 0.205, height: size * 0.205)
                .scaleEffect(active ? 1 : 0.6)
        }
        .frame(width: size, height: size)
    }
}

/// Bolletje dat over de boog meeloopt (animeerbaar).
private struct ArcKnob: Shape {
    var progress: Double
    var radius: CGFloat
    var knob: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let angle = (135 + 360 * progress) * .pi / 180
        let center = CGPoint(x: rect.midX + radius * CGFloat(cos(angle)),
                             y: rect.midY + radius * CGFloat(sin(angle)))
        return Path(ellipseIn: CGRect(x: center.x - knob / 2, y: center.y - knob / 2,
                                      width: knob, height: knob))
    }
}

// MARK: Lamp

struct LampTile: View {
    var size: CGFloat
    var active: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * IconPalette.cornerRatio, style: .continuous)
                .fill(active ? IconPalette.yellow : IconPalette.darkTile)
                .shadow(color: IconPalette.yellow.opacity(active ? 0.55 : 0), radius: size * 0.18)
            Image(systemName: active ? "lightbulb.fill" : "lightbulb")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(active ? IconPalette.bulb : Color.white.opacity(0.55))
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
    }
}

// MARK: Slot

struct LockTile: View {
    var size: CGFloat
    var active: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * IconPalette.cornerRatio, style: .continuous)
                .fill(IconPalette.blue)
            Image(systemName: active ? "lock.fill" : "lock.open.fill")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
    }
}

// MARK: Het logo: 2×2 tegels zoals het icoon

struct HomioLogo: View {
    /// Breedte van het hele raster.
    var size: CGFloat
    /// Welke tegels zichtbaar zijn (voor de binnenvlieg-animatie).
    var shown: [Bool] = [true, true, true, true]
    /// Tegels "aan": wijzers op hun plek, ring gevuld, lamp aan, slot dicht.
    var active: Bool = true

    var body: some View {
        let tile = size * 340 / 724
        let gap = size * 44 / 724
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                place(ClockTile(size: tile, active: active), index: 0, dx: -1, dy: -1)
                place(ThermostatTile(size: tile, active: active), index: 1, dx: 1, dy: -1)
            }
            HStack(spacing: gap) {
                place(LampTile(size: tile, active: active), index: 2, dx: -1, dy: 1)
                place(LockTile(size: tile, active: active), index: 3, dx: 1, dy: 1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Homio")
    }

    private func place<V: View>(_ view: V, index: Int, dx: CGFloat, dy: CGFloat) -> some View {
        let visible = shown[safe: index] ?? true
        return view
            .scaleEffect(visible ? 1 : 0.2)
            .rotationEffect(.degrees(visible ? 0 : Double(dx * dy) * 18))
            .offset(x: visible ? 0 : dx * size * 0.35, y: visible ? 0 : dy * size * 0.35)
            .opacity(visible ? 1 : 0)
    }
}

#Preview {
    HomioLogo(size: 260)
        .padding(60)
        .background(IconPalette.background)
}
