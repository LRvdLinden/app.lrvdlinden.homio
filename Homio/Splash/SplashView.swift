import SwiftUI

/// Korte, krachtige opening (± 1,3 s): de vier tegels van het icoon schieten 3D-gedraaid
/// binnen, komen tot leven, er gaat een lichtgolf met vonken door het beeld en de naam
/// klikt op zijn plek. Daarna zoomt alles weg naar de app.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var shown = [false, false, false, false]
    @State private var active = false
    @State private var burst = false
    @State private var showTitle = false
    @State private var leaving = false
    @State private var burstStart = Date.distantFuture

    var body: some View {
        let logoSize: CGFloat = sizeClass == .compact ? 190 : 250
        ZStack {
            IconPalette.background.ignoresSafeArea()

            // Gloed die opkomt als de tegels "aan" gaan.
            RadialGradient(colors: [Theme.accent.opacity(active ? 0.35 : 0), IconPalette.yellow.opacity(active ? 0.12 : 0), .clear],
                           center: .center, startRadius: 4, endRadius: active ? 560 : 60)
                .ignoresSafeArea()

            // Lichtgolven en vonken.
            TimelineView(.animation) { context in
                Canvas { gc, size in
                    let t = context.date.timeIntervalSince(burstStart)
                    guard t > 0, t < 1.2 else { return }
                    let center = CGPoint(x: size.width / 2, y: size.height / 2 - 30)
                    for i in 0..<3 {
                        let local = t - Double(i) * 0.12
                        guard local > 0 else { continue }
                        let r = CGFloat(local) * 520
                        let alpha = max(0, 0.55 - local * 0.6)
                        let ring = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
                        gc.stroke(ring, with: .color(Theme.accent.opacity(alpha)), lineWidth: 3)
                    }
                    let colors: [Color] = [IconPalette.yellow, IconPalette.orange, IconPalette.blue, .white]
                    for i in 0..<28 {
                        let angle = Double(i) / 28 * 2 * .pi + Double(i % 3) * 0.2
                        let speed = 260 + Double((i * 37) % 120)
                        let d = CGFloat(t * speed)
                        let p = CGPoint(x: center.x + CGFloat(cos(angle)) * d, y: center.y + CGFloat(sin(angle)) * d)
                        let s = CGFloat(max(0, 5 - t * 4))
                        gc.fill(Path(ellipseIn: CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)),
                                with: .color(colors[i % colors.count].opacity(max(0, 1 - t))))
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 34) {
                HomioLogo(size: logoSize, shown: shown, active: active)
                    .rotation3DEffect(.degrees(shown.allSatisfy { $0 } ? 0 : 35), axis: (x: 1, y: -1, z: 0), perspective: 0.6)
                    .scaleEffect(burst ? 1.06 : 1)
                    .scaleEffect(leaving ? 1.6 : 1)
                    .shadow(color: Theme.accent.opacity(active ? 0.45 : 0), radius: 40)

                Text("Homio")
                    .font(.system(size: sizeClass == .compact ? 52 : 68, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.8)], startPoint: .top, endPoint: .bottom))
                    .tracking(showTitle ? 1 : 18)
                    .opacity(showTitle ? 1 : 0)
                    .blur(radius: showTitle ? 0 : 10)
            }
            .opacity(leaving ? 0 : 1)
            .blur(radius: leaving ? 16 : 0)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: burst)
        .task { await run() }
        .accessibilityElement()
        .accessibilityLabel("Homio")
    }

    private func run() async {
        for index in 0..<4 {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { shown[index] = true }
            try? await Task.sleep(nanoseconds: 60_000_000)
        }
        withAnimation(.easeOut(duration: 0.55)) {
            active = true
            showTitle = true
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        burstStart = Date()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { burst = true }
        try? await Task.sleep(nanoseconds: 160_000_000)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { burst = false }
        try? await Task.sleep(nanoseconds: 380_000_000)
        withAnimation(.easeIn(duration: 0.35)) { leaving = true }
        try? await Task.sleep(nanoseconds: 260_000_000)
        onFinish()
    }
}

#Preview {
    SplashView {}
}
