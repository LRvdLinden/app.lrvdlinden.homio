import SwiftUI

/// Homey-achtige huisstijl voor Homio: 4-punts raster, Homey-lettermaten
/// (32/24/20/17/14), Homey-kleuren voor blauw/groen/oranje/rood, licht en donker.
enum Theme {
    // Homey v10.1.4 (colorPalette mono_*, licht / donker):
    // 000 FFF/000 · 010 FBFBFD/09090C · 025 F4F4FA/111218 · 050 EAEAF1/1F2029 · 100 DADAE2/2B2C36
    // 200 C8C8D0/3B3D4A · 300 B1B1B9/4F515F · 400 93939A/666875 · 500 7A7A7F/80818E
    // 600 626265/999AA3 · 700 49494B/B2B3B8 · 800 303031/CACACE · 900 1C1C1C/E4E4E7
    // EX037 F1F1F8/181920 · EX085 DFDFE7/272832
    static let background = Color(light: 0xF4F4FA, dark: 0x111218)       // body = mono_025
    static let area = Color(light: 0xFFFFFF, dark: 0x111218)             // area = mono_000 / mono_025
    static let card = Color(light: 0xFFFFFF, dark: 0x1F2029)             // component = mono_000 / mono_050
    static let cardRaised = Color(light: 0xFFFFFF, dark: 0x2B2C36)       // component_highlight
    static let wrapper = Color(light: 0xEAEAF1, dark: 0x181920)          // component_wrapper
    static let pill = Color(light: 0xEAEAF1, dark: 0x2B2C36)
    /// Apparaattegel uit (component_off, met haarlijn mono_100) en aan (component_on, zonder rand).
    static let tileOff = Color(light: 0xF1F1F8, dark: 0x181920)
    static let tileOn = Color(light: 0xFFFFFF, dark: 0x2B2C36)
    /// Snelle-actieknop op een tegel: uit grijs, aan lichtblauw (gemeten in de Homey-app).
    static let quickOff = Color(light: 0xE4E4EC, dark: 0x2B2C36)
    static let quickOn = Color(light: 0xE6F3FF, dark: 0x003464)          // blue_050 / blue_800
    /// Haarlijn rond een tegel die uit staat (mono_100).
    static let tileBorder = Color(light: 0xDADAE2, dark: 0x2B2C36)
    /// Homey Insights: kaart, pillen, raster en gekozen segment.
    static let insightsCard = Color(light: 0xFFFFFF, dark: 0x1F2029)
    static let insightsPill = Color(light: 0xF1F1F8, dark: 0x2B2C36)
    static let insightsGrid = Color(light: 0xDADAE2, dark: 0x3B3D4A)
    static let insightsSelected = Color(light: 0xFFFFFF, dark: 0x3B3D4A)
    /// Lichtblauwe balk voor "Kaart toevoegen" (blue_050 / blue_800).
    static let addCardFill = Color(light: 0xE6F3FF, dark: 0x003464)
    static let line = Color(light: 0xDADAE2, dark: 0x3B3D4A)              // mono_100 / mono_200
    static let lineLight = Color(light: 0xEAEAF1, dark: 0x2B2C36)         // mono_050 / mono_100
    static let text = Color(light: 0x1C1C1C, dark: 0xE4E4E7)              // mono_900
    static let textLight = Color(light: 0x93939A, dark: 0x999AA3)         // mono_400 / mono_600
    static let textMedium = Color(light: 0x626265, dark: 0x999AA3)        // mono_600
    static let iconMedium = Color(light: 0x7A7A7F, dark: 0xCACACE)        // mono_500 / mono_800
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

    // Raster en vormen zoals in de Homey-app (v10 gelijk aan v8): su = 8, rand 16 (tablet 32), goot 16,
    // tegel-padding 12, radius 10 (klein 5, groot 20).
    static let su: CGFloat = 4
    static let edge: CGFloat = 16
    static let edgeTablet: CGFloat = 32
    static let gutter: CGFloat = 10
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

/// Homey v10 "system_*"-kleuren: de ronde app-iconen in Meer, Instellingen en Flow-kaarten.
enum SystemColor {
    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
    static let account = hex(0xF3AC16), alarms = hex(0xE3292F), apps = hex(0x7538BC)
    static let backups = hex(0x00AEF5), batteries = hex(0x00C900), camera = hex(0x0082FA)
    static let dashboards = hex(0x006FFF), dateTime = hex(0xE3282F), devices = hex(0x7243E1)
    static let energy = hex(0x10C56E), family = hex(0xFF7F33), feedback = hex(0x2FB2DB)
    static let flow = hex(0x3BCB18), general = hex(0x454545), home = hex(0x494949)
    static let insights = hex(0x452D76), language = hex(0x00C1BE), lights = hex(0xF5B207)
    static let location = hex(0x7CD516), logic = hex(0x2AA733), moods = hex(0x5C5AD7)
    static let presence = hex(0xADE127), pushNotifications = hex(0x235B7D), reminders = hex(0xEF0048)
    static let safety = hex(0xEF1965), security = hex(0x495964), settings = hex(0x343434)
    static let siriShortcuts = hex(0x1C1F56), support = hex(0x3C85C3), timeline = hex(0xFFCD00)
    static let updates = hex(0xD20BCB), matter = hex(0x2C2C37), newsletter = hex(0xFFA600)
    static let weather = hex(0xFF8400), zone = hex(0x494949), appearance = hex(0x000000)
    static let thread = hex(0xFF6632), web = hex(0x0082FA)
}

/// Homey v10 Insights-kleuren per soort meting.
enum InsightsColor {
    static let temperature = Color(red: 0xFA / 255, green: 0x64 / 255, blue: 0)
    static let humidity = Color(red: 0, green: 0x91 / 255, blue: 1)
    static let luminance = Color(red: 0xF7 / 255, green: 0xB5 / 255, blue: 0)
    static let power = Color(red: 0x6D / 255, green: 0xD4 / 255, blue: 0)
    static let co2 = Color(red: 0xE0 / 255, green: 0x20 / 255, blue: 0x20 / 255)
    static let door = Color(red: 0, green: 0x82 / 255, blue: 0xFA / 255)
    static let window = Color(red: 0xF5 / 255, green: 0xB2 / 255, blue: 0x07 / 255)
    static let fallback = Color(red: 0x90 / 255, green: 0x33 / 255, blue: 0xFC / 255)
}

/// Achtergrond van een Homey v10-tegel: uit = component_off met haarlijn mono_100,
/// aan = component_on zonder rand; de overgang loopt vloeiend.
struct HomeyTileBackground: View {
    let lit: Bool
    var corner: CGFloat = Theme.tileCorner

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        shape
            .fill(lit ? Theme.tileOn : Theme.tileOff)
            .overlay(shape.strokeBorder(Theme.tileBorder.opacity(lit ? 0 : 1), lineWidth: 1 / displayScale))
            .shadow(color: .black.opacity(lit ? 0.06 : 0), radius: 3, y: 1)
            .animation(.easeInOut(duration: 0.25), value: lit)
    }

    @Environment(\.displayScale) private var displayScale
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
    /// Bewust leeg: de Homey-app gebruikt de standaard zwevende iOS-tabbalk en navigatiebalk.
    static func apply() {
    }
}
#endif
