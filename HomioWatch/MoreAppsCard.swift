import SwiftUI

/// LRvdLinden-huisstijl (van lrvdlinden.app): accentblauw, inkt, vlak, lijn en gedempte
/// tekst, elk met een donkere waarde. Gelijk aan de kaart in Homey Store.
enum Brand {
    static let url = URL(string: "https://lrvdlinden.app")!
    static let accent = Color(light: 0x2747E8, dark: 0x8A9DFF)
    static let accentSoft = Color(light: 0xE6EBFF, dark: 0x1D2547)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x0D1018)
    static let ink = Color(light: 0x121726, dark: 0xE9ECF4)
    static let muted = Color(light: 0x5D6578, dark: 0x98A0B3)
    static let surface = Color(light: 0xFFFFFF, dark: 0x161B27)
    static let line = Color(light: 0xDDE2EC, dark: 0x262D3D)
    /// De logotegel is altijd donkere inkt, met de blauwe stip.
    static let logoTile = Color(red: 0x12 / 255, green: 0x17 / 255, blue: 0x26 / 255)
    static let logoDot = Color(red: 0x4C / 255, green: 0x6B / 255, blue: 0xFF / 255)
}

extension Color {
    /// Kleur met een eigen waarde voor licht en donker.
    init(light: UInt32, dark: UInt32) {
        #if os(watchOS)
        self.init(hex24: dark)
        #else
        self.init(uiColor: UIColor { trait in
            let v = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255,
                           green: CGFloat((v >> 8) & 0xFF) / 255,
                           blue: CGFloat(v & 0xFF) / 255,
                           alpha: 1)
        })
        #endif
    }

    init(hex24 v: UInt32) {
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

/// Het "LR"-merk van lrvdlinden.app, natively getekend (ontwerpraster 512 × 512).
struct LRLogo: View {
    var size: CGFloat = 60

    var body: some View {
        Canvas { ctx, canvas in
            let s = canvas.width / 512
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: canvas), cornerRadius: 116 * s, style: .continuous),
                     with: .color(Brand.logoTile))

            var letters = Path()
            // L
            letters.move(to: p(132, 146)); letters.addLine(to: p(132, 370)); letters.addLine(to: p(232, 370))
            // R: steel en boog
            letters.move(to: p(292, 370)); letters.addLine(to: p(292, 146)); letters.addLine(to: p(340, 146))
            letters.addArc(center: p(340, 208), radius: 62 * s, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            letters.addLine(to: p(292, 270))
            // R: poot
            letters.move(to: p(338, 270)); letters.addLine(to: p(390, 370))
            ctx.stroke(letters, with: .color(.white),
                       style: StrokeStyle(lineWidth: 46 * s, lineCap: .round, lineJoin: .round))

            let dot = Path(ellipseIn: CGRect(x: (404 - 34) * s, y: (126 - 34) * s, width: 68 * s, height: 68 * s))
            ctx.fill(dot, with: .color(Brand.logoDot))
            ctx.stroke(dot, with: .color(Brand.logoTile), lineWidth: 14 * s)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Kaart "Meer apps van de ontwikkelaar" voor onderaan de instellingen.
/// Opent lrvdlinden.app. De tekst volgt de taal van de app.
struct MoreAppsCard: View {
    #if os(watchOS)
    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 34
    #else
    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 60
    #endif

    private var text: MoreAppsText { MoreAppsText.current }

    var body: some View {
        Link(destination: Brand.url) {
            content
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text.title). \(text.subtitle)")
        .accessibilityHint("lrvdlinden.app")
        .accessibilityAddTraits(.isLink)
    }

    @ViewBuilder
    private var content: some View {
        #if os(watchOS)
        // Op de Watch: onder elkaar, zonder kaartrand (de lijst geeft al een vlak).
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                LRLogo(size: logoSize)
                Text(text.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Brand.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(text.subtitle)
                .font(.caption2)
                .foregroundStyle(Brand.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(text.action)
                .font(.caption.weight(.bold))
                .foregroundStyle(Brand.onAccent)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Brand.accent, in: Capsule())
        }
        .padding(.vertical, 4)
        #else
        HStack(spacing: 14) {
            LRLogo(size: logoSize)
                .overlay(RoundedRectangle(cornerRadius: logoSize * 116 / 512, style: .continuous)
                    .strokeBorder(Brand.line, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(text.title)
                    .font(.headline)
                    .foregroundStyle(Brand.accent)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Brand.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(spacing: 4) {
                Text(text.action)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Brand.onAccent)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Brand.accent, in: Capsule())
                Text(verbatim: "lrvdlinden.app")
                    .font(.caption2)
                    .foregroundStyle(Brand.muted)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Brand.line, lineWidth: 1))
        #endif
    }
}

/// Teksten van de kaart per taal. Kiest de taal waarin de app draait, anders Engels.
struct MoreAppsText {
    let section: String
    let title: String
    let subtitle: String
    let action: String

    /// De talen die Homio ondersteunt.
    static let supported = ["nl", "en", "de", "fr", "es"]

    /// De taal waarin de app draait. De Watch-app heeft geen eigen vertalingen,
    /// dus daar volgen we de taalvoorkeur van het toestel.
    static var language: String {
        #if os(watchOS)
        let candidates = Locale.preferredLanguages
        #else
        let candidates = Bundle.main.preferredLocalizations
        #endif
        for id in candidates {
            let code = String(id.prefix(2))
            if supported.contains(code) { return code }
        }
        return "en"
    }

    static var current: MoreAppsText { all[language] ?? all["en"]! }

    static let all: [String: MoreAppsText] = [
        "nl": .init(section: "Ontdekken", title: "Meer apps van de ontwikkelaar",
                    subtitle: "Apps voor iPhone, iPad, Apple TV en Homey", action: "Bekijk"),
        "en": .init(section: "Discover", title: "More apps from the developer",
                    subtitle: "Apps for iPhone, iPad, Apple TV and Homey", action: "View"),
        "de": .init(section: "Entdecken", title: "Weitere Apps des Entwicklers",
                    subtitle: "Apps für iPhone, iPad, Apple TV und Homey", action: "Ansehen"),
        "fr": .init(section: "Découvrir", title: "Plus d’apps du développeur",
                    subtitle: "Apps pour iPhone, iPad, Apple TV et Homey", action: "Voir"),
        "es": .init(section: "Descubrir", title: "Más apps del desarrollador",
                    subtitle: "Apps para iPhone, iPad, Apple TV y Homey", action: "Ver"),
        "it": .init(section: "Scopri", title: "Altre app dello sviluppatore",
                    subtitle: "App per iPhone, iPad, Apple TV e Homey", action: "Vedi"),
        "sv": .init(section: "Upptäck", title: "Fler appar från utvecklaren",
                    subtitle: "Appar för iPhone, iPad, Apple TV och Homey", action: "Visa"),
        "no": .init(section: "Oppdag", title: "Flere apper fra utvikleren",
                    subtitle: "Apper for iPhone, iPad, Apple TV og Homey", action: "Vis"),
        "nb": .init(section: "Oppdag", title: "Flere apper fra utvikleren",
                    subtitle: "Apper for iPhone, iPad, Apple TV og Homey", action: "Vis"),
        "da": .init(section: "Opdag", title: "Flere apps fra udvikleren",
                    subtitle: "Apps til iPhone, iPad, Apple TV og Homey", action: "Vis"),
        "pl": .init(section: "Odkrywaj", title: "Więcej aplikacji od dewelopera",
                    subtitle: "Aplikacje na iPhone’a, iPada, Apple TV i Homey", action: "Zobacz"),
    ]
}

#Preview {
    VStack(spacing: 20) {
        MoreAppsCard()
        MoreAppsCard().environment(\.colorScheme, .dark)
    }
    .padding()
}
