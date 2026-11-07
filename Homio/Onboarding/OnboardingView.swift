import SwiftUI

/// Welkomstschermen: vier pagina's met bewegende illustraties, daarna inloggen.
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0
    private let pages = 4

    var body: some View {
        ZStack {
            OnboardingBackground(page: page)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pages - 1 {
                        Button("Overslaan") { finish() }
                            .font(HomeyFont.bodyMedium)
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                }
                .frame(height: 44)

                TabView(selection: $page) {
                    OnboardingPage(
                        title: "Je huis, in één app",
                        text: "Homio bedient al je HomeKit- en Matter-apparaten: lampen, stekkers, sloten, gordijnen, thermostaten en sensoren.",
                        illustration: AnyView(DevicesIllustration(active: page == 0))
                    ).tag(0)
                    OnboardingPage(
                        title: "Flows die meedenken",
                        text: "Als je thuiskomt en het is donker, dan gaan de lampen aan. Bouw het in drie stappen: Als, En, Dan.",
                        illustration: AnyView(FlowIllustration(active: page == 1))
                    ).tag(1)
                    OnboardingPage(
                        title: "Dashboards en inzichten",
                        text: "Stel je eigen dashboards samen, volg temperatuur en verbruik in grafieken, en zet een iPad als bedienpaneel aan de muur.",
                        illustration: AnyView(DashboardIllustration(active: page == 2))
                    ).tag(2)
                    OnboardingPage(
                        title: "Privé, op al je apparaten",
                        text: "Je gegevens blijven in Apple Woning en in je eigen iCloud. Homio werkt op iPhone, iPad, Mac en Apple Watch.",
                        illustration: AnyView(PrivacyIllustration(active: page == 3))
                    ).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: page)

                PageDots(count: pages, current: page)
                    .padding(.bottom, 24)

                Button {
                    if page < pages - 1 {
                        withAnimation(.easeInOut(duration: 0.35)) { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(page < pages - 1 ? "Volgende" : "Aan de slag")
                        .font(HomeyFont.bodyBold)
                        .frame(maxWidth: 420)
                        .frame(height: 56)
                        .background(Capsule().fill(.white))
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.interpolate)
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.selection, trigger: page)
    }

    private func finish() {
        onFinish()
    }
}

private struct OnboardingPage: View {
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    let illustration: AnyView

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 8)
            illustration
                .frame(maxWidth: 360, maxHeight: 320)
            VStack(spacing: 12) {
                Text(title)
                    .font(HomeyFont.xxlarge)
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(HomeyFont.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            Spacer(minLength: 8)
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(i == current ? 1 : 0.35))
                    .frame(width: i == current ? 26 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: current)
        .accessibilityHidden(true)
    }
}

/// Bewegende achtergrond die per pagina van kleur verschuift.
private struct OnboardingBackground: View {
    let page: Int

    private var colors: [Color] {
        switch page {
        case 0: return [Theme.accent, Color(red: 0.12, green: 0.2, blue: 0.55)]
        case 1: return [IconPalette.orange, Color(red: 0.55, green: 0.18, blue: 0.35)]
        case 2: return [Color(red: 0.25, green: 0.7, blue: 0.55), Color(red: 0.08, green: 0.28, blue: 0.42)]
        default: return [Color(red: 0.45, green: 0.35, blue: 0.95), Color(red: 0.12, green: 0.1, blue: 0.3)]
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                gc.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.04, green: 0.045, blue: 0.07)))
                gc.addFilter(.blur(radius: min(size.width, size.height) * 0.14))
                for (i, color) in colors.enumerated() {
                    let fi = Double(i)
                    let x = size.width * (0.5 + 0.35 * cos(t * 0.18 + fi * 2.4))
                    let y = size.height * (0.35 + 0.25 * sin(t * 0.22 + fi * 1.7))
                    let r = min(size.width, size.height) * 0.75
                    gc.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)),
                            with: .color(color.opacity(0.55)))
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: page)
    }
}

// MARK: Illustraties

/// Tegels die één voor één aan gaan.
private struct DevicesIllustration: View {
    let active: Bool
    @State private var lit = 0

    private let items: [(String, String, Color)] = [
        ("lightbulb.fill", "Woonkamer", IconPalette.yellow),
        ("lock.fill", "Voordeur", Theme.accent),
        ("thermometer.medium", "21,5°", Theme.orange),
        ("blinds.horizontal.open", "Gordijnen", .teal)
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(items.indices, id: \.self) { i in
                let on = i < lit
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: items[i].0)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(on ? Color.white : Color.white.opacity(0.6))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(on ? items[i].2 : Color.white.opacity(0.12)))
                    Text(items[i].1).font(HomeyFont.bodyMedium).foregroundStyle(.white)
                    Text(on ? "Aan" : "Uit").font(HomeyFont.small).foregroundStyle(on ? items[i].2 : Color.white.opacity(0.5))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Color.white.opacity(on ? 0.16 : 0.08)))
                .scaleEffect(on ? 1.03 : 1)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: on)
            }
        }
        .task(id: active) {
            guard active else { return }
            lit = 0
            for i in 1...items.count {
                try? await Task.sleep(nanoseconds: 380_000_000)
                lit = i
            }
        }
    }
}

/// ALS → EN → DAN die achter elkaar oplichten.
private struct FlowIllustration: View {
    let active: Bool
    @State private var step = 0

    private let cards: [(String, String, String, Color)] = [
        ("ALS", "figure.walk.arrival", "Iemand komt thuis", IconPalette.orange),
        ("EN", "moon.stars.fill", "Het is donker", IconPalette.yellow),
        ("DAN", "lightbulb.fill", "Lampen aan", IconPalette.blue)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(cards.indices, id: \.self) { i in
                let on = i < step
                HStack(spacing: 12) {
                    Text(cards[i].0)
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(cards[i].3))
                        .foregroundStyle(.black)
                    Image(systemName: cards[i].1).foregroundStyle(cards[i].3)
                    Text(cards[i].2).font(HomeyFont.bodyMedium).foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.green)
                        .opacity(on ? 1 : 0)
                        .scaleEffect(on ? 1 : 0.3)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Color.white.opacity(on ? 0.16 : 0.07)))
                .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(cards[i].3.opacity(on ? 0.8 : 0), lineWidth: 1.5))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: on)
                if i < cards.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(i + 1 < step ? 0.6 : 0.15))
                        .frame(width: 2, height: 22)
                }
            }
        }
        .task(id: active) {
            guard active else { return }
            step = 0
            for i in 1...cards.count {
                try? await Task.sleep(nanoseconds: 520_000_000)
                step = i
            }
        }
    }
}

/// Een mini-dashboard dat zich vult, met een grafiek die wordt getekend.
private struct DashboardIllustration: View {
    let active: Bool
    @State private var shown = false
    @State private var draw: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                miniCard {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("21:30").font(.system(size: 30, weight: .light, design: .rounded))
                        Text("Vrijdag").font(HomeyFont.small).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .offset(x: shown ? 0 : -40)
                miniCard {
                    HStack {
                        Image(systemName: "cloud.sun.fill").symbolRenderingMode(.multicolor).font(.title)
                        Text("14°").font(.system(size: 30, weight: .semibold, design: .rounded))
                    }
                }
                .offset(x: shown ? 0 : 40)
            }
            miniCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Temperatuur", systemImage: "thermometer.medium")
                        .font(HomeyFont.small)
                        .foregroundStyle(Theme.orange)
                    SparkShape()
                        .trim(from: 0, to: draw)
                        .stroke(Theme.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(height: 70)
                }
            }
            .offset(y: shown ? 0 : 40)
        }
        .opacity(shown ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: shown)
        .task(id: active) {
            guard active else { return }
            shown = false
            draw = 0
            try? await Task.sleep(nanoseconds: 150_000_000)
            shown = true
            withAnimation(.easeInOut(duration: 1.4).delay(0.3)) { draw = 1 }
        }
    }

    private func miniCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Color.white.opacity(0.12)))
    }
}

private struct SparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let values: [CGFloat] = [0.6, 0.55, 0.62, 0.4, 0.45, 0.3, 0.35, 0.2, 0.28, 0.15]
        var p = Path()
        for (i, v) in values.enumerated() {
            let pt = CGPoint(x: rect.minX + rect.width * CGFloat(i) / CGFloat(values.count - 1),
                             y: rect.minY + rect.height * v)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

/// Het Homio-logo met een schild en apparaten eromheen.
private struct PrivacyIllustration: View {
    let active: Bool
    @State private var spin = false

    private let devices = ["iphone", "ipad", "laptopcomputer", "applewatch"]

    var body: some View {
        ZStack {
            ForEach(devices.indices, id: \.self) { i in
                let angle = Double(i) * 90 + (spin ? 360 : 0)
                Image(systemName: devices[i])
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                    .rotationEffect(.degrees(-angle)) // icoon blijft rechtop
                    .offset(y: -130)
                    .rotationEffect(.degrees(angle))
            }
            ZStack {
                HomioLogo(size: 120)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white, Theme.green)
                    .offset(x: 52, y: 52)
            }
        }
        .frame(width: 320, height: 320)
        .onChange(of: active, initial: true) { _, isActive in
            if isActive {
                withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { spin = true }
            }
        }
    }
}
