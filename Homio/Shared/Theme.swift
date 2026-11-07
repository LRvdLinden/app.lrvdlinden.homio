import SwiftUI

/// Homey-achtige huisstijl voor Homio: 4-punts raster, Homey-lettermaten
/// (32/24/20/17/14), Homey-kleuren voor blauw/groen/oranje/rood, licht en donker.
enum Theme {
    // Homey-grijswaarden (mono): licht en donker. Pagina = mono-025, kaart/widget = mono-000 (licht)
    // of mono-050 (donker), knoppen/pillen = mono-100, lijnen = mono-100.
    static let background = Color(light: 0xF4F4FA, dark: 0x111218)
    static let card = Color(light: 0xFFFFFF, dark: 0x1F2029)
    static let cardRaised = Color(light: 0xEAEAF1, dark: 0x2B2C36)
    static let pill = Color(light: 0xEAEAF1, dark: 0x2B2C36)
    static let line = Color(light: 0xDADAE2, dark: 0x2B2C36)
    static let lineLight = Color(light: 0xEAEAF1, dark: 0x1F2029)
    static let text = Color(light: 0x1C1C1C, dark: 0xE4E4E7)          // mono-900
    static let textLight = Color(light: 0x7A7A7F, dark: 0x80818E)     // mono-500

    // Homey-kleuren (gelijk in licht en donker)
    static let accent = Color(red: 0x00 / 255, green: 0x82 / 255, blue: 0xFA / 255)   // blue  #0082FA
    static let green = Color(red: 0x3F / 255, green: 0xC7 / 255, blue: 0x00 / 255)    // green #3FC700
    static let orange = Color(red: 0xFF / 255, green: 0x84 / 255, blue: 0x00 / 255)   // orange #FF8400
    static let red = Color(red: 0xD8 / 255, green: 0x1C / 255, blue: 0x1D / 255)      // red   #D81C1D

    // Warme kleuren voor de weergavemodus en het merk
    static let amber = Color(red: 1.0, green: 0.71, blue: 0.28)
    static let ember = Color(red: 1.0, green: 0.45, blue: 0.25)
    static let violet = Color(red: 0.42, green: 0.36, blue: 0.92)
    static let warmGradient = LinearGradient(colors: [amber, ember],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)

    // Raster en vormen: --homey-su = 4 px, --homey-border-radius-default = 12, -small = 6
    static let su: CGFloat = 4
    static let corner: CGFloat = 12
    static let cornerSmall: CGFloat = 6
    static let tileCorner: CGFloat = 12
}

/// Homey-lettermaten.
enum HomeyFont {
    static let xxlarge = Font.system(size: 32, weight: .bold, design: .rounded)
    static let xlarge = Font.system(size: 24, weight: .bold)
    static let large = Font.system(size: 20, weight: .medium)
    static let body = Font.system(size: 17)
    static let bodyMedium = Font.system(size: 17, weight: .medium)
    static let bodyBold = Font.system(size: 17, weight: .bold)
    static let small = Font.system(size: 14)
}

/// Weergave: automatisch, licht of donker.
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .system: return "Automatisch"
        case .light: return "Licht"
        case .dark: return "Donker"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    /// Kleur met een eigen waarde voor licht en donker.
    init(light: UInt32, dark: UInt32) {
        func rgb(_ hex: UInt32) -> (CGFloat, CGFloat, CGFloat) {
            (CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255)
        }
        let (lr, lg, lb) = rgb(light), (dr, dg, db) = rgb(dark)
        self.init(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: dr, green: dg, blue: db, alpha: 1)
            : UIColor(red: lr, green: lg, blue: lb, alpha: 1) })
    }
}

/// Effen Homey-kaart (licht: wit op lichtgrijs; donker: grafiet).
struct GlassCard: ViewModifier {
    var corner: CGFloat = Theme.corner

    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
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
    var corner: CGFloat = Theme.corner
    var fill: Color = Theme.card

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: corner, style: .continuous).fill(fill))
    }
}

extension View {
    func card(corner: CGFloat = Theme.corner, fill: Color = Theme.card) -> some View {
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
