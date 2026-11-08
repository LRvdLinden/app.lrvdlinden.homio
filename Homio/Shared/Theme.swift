import SwiftUI

/// Homey-achtige huisstijl voor Homio: 4-punts raster, Homey-lettermaten
/// (32/24/20/17/14), Homey-kleuren voor blauw/groen/oranje/rood, licht en donker.
enum Theme {
    // Homey-grijswaarden (colorPalette mono_*), licht en donker, zoals in de Homey-app.
    // Semantisch: body = mono_025, component = mono_000/mono_050,
    // component_on = mono_000/mono_200, component_off = mono_EX030/mono_050.
    static let background = Color(light: 0xF4F4FA, dark: 0x111218)       // body
    static let card = Color(light: 0xFFFFFF, dark: 0x1F2029)             // component
    static let cardRaised = Color(light: 0xEAEAF1, dark: 0x2B2C36)       // component_highlight
    static let pill = Color(light: 0xEAEAF1, dark: 0x2B2C36)
    /// Apparaattegel uit (component_off) en aan (component_on).
    static let tileOff = Color(light: 0xF1F1F8, dark: 0x1F2029)
    static let tileOn = Color(light: 0xFFFFFF, dark: 0x3B3D4A)
    /// Haarlijn rond een tegel die uit staat (licht: zwart 5%, donker: mono_100).
    static let tileBorder = Color(lightRGBA: (0, 0, 0, 0.05), dark: 0x2B2C36)
    /// Homey Insights: kaart, pillen, raster en gekozen segment.
    static let insightsCard = Color(light: 0xFFFFFF, dark: 0x1C1D26)
    static let insightsPill = Color(light: 0xF1F2F6, dark: 0x2A2B36)
    static let insightsGrid = Color(light: 0xE3E5EC, dark: 0x3A3C4A)
    static let insightsSelected = Color(light: 0xFFFFFF, dark: 0x3B3D4A)
    static let line = Color(light: 0xDADAE2, dark: 0x3B3D4A)              // mono_100 / mono_200
    static let lineLight = Color(light: 0xEAEAF1, dark: 0x2B2C36)         // mono_050 / mono_100
    static let text = Color(light: 0x1C1C1C, dark: 0xE4E4E7)              // mono_900
    static let textLight = Color(light: 0x93939A, dark: 0x999AA3)         // mono_400 / mono_600
    static let textMedium = Color(light: 0x626265, dark: 0x999AA3)        // mono_600
    static let iconLight = Color(light: 0xC8C8D0, dark: 0x999AA3)         // mono_200 / mono_600

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

    // Zone-bediening (zoneControls): lampen geel, klimaat oranje, speakers paars.
    static let yellow = Color(red: 0xF5 / 255, green: 0xB2 / 255, blue: 0x07 / 255)   // #F5B207
    static let purple = Color(red: 0x90 / 255, green: 0x33 / 255, blue: 0xFC / 255)   // #9033FC
    /// Homey-verlopen (30°): blauw en moods.
    static let blueGradient = LinearGradient(colors: [Color(red: 0, green: 0x6A / 255, blue: 1), Color(red: 0, green: 0xBF / 255, blue: 1)],
                                             startPoint: .bottomLeading, endPoint: .topTrailing)
    static let moodGradient = LinearGradient(colors: [Color(red: 0x8B / 255, green: 0x55 / 255, blue: 0xEA / 255),
                                                      Color(red: 0xB6 / 255, green: 0x20 / 255, blue: 0xE0 / 255),
                                                      Color(red: 0xF7 / 255, green: 0xB5 / 255, blue: 0)],
                                             startPoint: .bottomLeading, endPoint: .topTrailing)

    // Raster en vormen zoals in de Homey-app: su = 8, rand 16 (tablet 32), goot 16,
    // tegel-padding 12, radius 10 (klein 5, groot 20).
    static let su: CGFloat = 4
    static let edge: CGFloat = 16
    static let edgeTablet: CGFloat = 32
    static let gutter: CGFloat = 16
    static let tilePadding: CGFloat = 12
    static let corner: CGFloat = 10
    static let cornerSmall: CGFloat = 5
    static let cornerLarge: CGFloat = 20
    static let tileCorner: CGFloat = 10
}

/// Homey-lettermaten.
enum HomeyFont {
    static let xxlarge = Font.system(size: 32, weight: .bold)
    static let xlarge = Font.system(size: 24, weight: .bold)
    static let large = Font.system(size: 20, weight: .medium)
    static let body = Font.system(size: 17)
    static let bodyMedium = Font.system(size: 17, weight: .medium)
    static let bodyBold = Font.system(size: 17, weight: .bold)
    static let small = Font.system(size: 14)
    static let smallMedium = Font.system(size: 14, weight: .medium)
    static let tiny = Font.system(size: 12)
    static let extraTiny = Font.system(size: 11)
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
    /// Lichte variant met transparantie, donkere variant als hex.
    init(lightRGBA: (Double, Double, Double, Double), dark: UInt32) {
        let d = (CGFloat((dark >> 16) & 0xFF) / 255, CGFloat((dark >> 8) & 0xFF) / 255, CGFloat(dark & 0xFF) / 255)
        self.init(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: d.0, green: d.1, blue: d.2, alpha: 1)
            : UIColor(red: lightRGBA.0, green: lightRGBA.1, blue: lightRGBA.2, alpha: lightRGBA.3) })
    }

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
            .background(RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Theme.card)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2))
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
            .background(RoundedRectangle(cornerRadius: corner, style: .continuous).fill(fill)
                // Homey shadow.light: y 2, blur 3, 12% zwart.
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2))
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

#if canImport(UIKit)
/// Tabbalk en navigatiebalk zoals in de Homey-app: effen vlak, haarlijn, blauw voor de
/// gekozen tab, grijze iconen, grote vette titels.
enum HomeyChrome {
    private static func dynamic(_ light: UInt32, _ dark: UInt32, alpha: CGFloat = 1) -> UIColor {
        func c(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
        }
        return UIColor { $0.userInterfaceStyle == .dark ? c(dark) : c(light) }
    }

    static func apply() {
        let accent = UIColor(red: 0, green: 0x82 / 255, blue: 0xFA / 255, alpha: 1)
        let unselected = dynamic(0x93939A, 0x80818E)

        let item = UITabBarItemAppearance()
        item.normal.iconColor = unselected
        item.normal.titleTextAttributes = [.foregroundColor: unselected, .font: UIFont.systemFont(ofSize: 10, weight: .medium)]
        item.selected.iconColor = accent
        item.selected.titleTextAttributes = [.foregroundColor: accent, .font: UIFont.systemFont(ofSize: 10, weight: .semibold)]

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = dynamic(0xFFFFFF, 0x111218)
        tab.shadowColor = dynamic(0xDADAE2, 0x2B2C36)
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let text = dynamic(0x1C1C1C, 0xE4E4E7)
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = dynamic(0xF4F4FA, 0x111218)
        nav.largeTitleTextAttributes = [.foregroundColor: text, .font: UIFont.systemFont(ofSize: 32, weight: .bold)]
        nav.titleTextAttributes = [.foregroundColor: text, .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.largeTitleTextAttributes = nav.largeTitleTextAttributes
        scrolled.titleTextAttributes = nav.titleTextAttributes
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
    }
}
#endif
