import SwiftUI

enum Theme {
    static let background = Color(red: 0.043, green: 0.051, blue: 0.071)
    static let amber = Color(red: 1.0, green: 0.71, blue: 0.28)
    static let ember = Color(red: 1.0, green: 0.45, blue: 0.25)
    static let violet = Color(red: 0.42, green: 0.36, blue: 0.92)
    static let warmGradient = LinearGradient(colors: [amber, ember],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
    static let corner: CGFloat = 26
}

struct GlassCard: ViewModifier {
    var corner: CGFloat = Theme.corner

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(corner: CGFloat = Theme.corner) -> some View {
        modifier(GlassCard(corner: corner))
    }
}

/// Langzaam bewegende, warme achtergrond met zachte kleurvlekken.
struct AmbientBackground: View {
    var intensity: Double = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                gc.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.background))
                let side = min(size.width, size.height)
                gc.addFilter(.blur(radius: side * 0.12))
                let blobs: [(Color, Double, Double, Double)] = [
                    (Theme.amber, 0.13, 0.0, 0.60),
                    (Theme.ember, 0.09, 2.1, 0.50),
                    (Theme.violet, 0.07, 4.2, 0.55)
                ]
                for (color, speed, phase, scale) in blobs {
                    let x = size.width * (0.5 + 0.32 * cos(t * speed + phase))
                    let y = size.height * (0.5 + 0.28 * sin(t * speed * 1.3 + phase))
                    let r = side * scale
                    let rect = CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)
                    gc.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.32 * intensity)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Knop die licht indrukt.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Double {
    /// "20,5" in de taal van het toestel.
    var oneDecimal: String { formatted(.number.precision(.fractionLength(0...1))) }
}

/// HStack op iPad, VStack op iPhone (compacte breedte).
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = 20
    var rowAlignment: VerticalAlignment = .center
    @ViewBuilder var content: () -> Content
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .compact {
            VStack(alignment: .leading, spacing: spacing, content: content)
        } else {
            HStack(alignment: rowAlignment, spacing: spacing, content: content)
        }
    }
}

extension View {
    /// Ruimte rondom een face: boven voor de profielbalk, onder voor het dock.
    func facePadding(_ compact: Bool) -> some View {
        self
            .padding(.horizontal, compact ? 18 : 32)
            .padding(.top, compact ? 70 : 80)
            .padding(.bottom, compact ? 150 : 130)
    }
}

/// Effen kaart (in de tabbladen, waar geen bewegende achtergrond achter zit).
struct SolidCard: ViewModifier {
    var corner: CGFloat = 22
    var fill: Color = Color.white.opacity(0.07)

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: corner, style: .continuous).fill(fill))
    }
}

extension View {
    func card(corner: CGFloat = 22, fill: Color = Color.white.opacity(0.07)) -> some View {
        modifier(SolidCard(corner: corner, fill: fill))
    }
}

/// Klein vierkant icoon met verloop, zoals in de lijsten van Homio.
struct GradientIcon: View {
    let symbol: String
    var colors: [Color] = [IconPalette.yellow, IconPalette.orange]
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
