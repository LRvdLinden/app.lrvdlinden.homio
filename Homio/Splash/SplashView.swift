import SwiftUI

/// Openingsscherm met de vier tegels van het icoon:
/// ze vliegen één voor één binnen, komen tot leven (wijzers draaien, ring vult,
/// lamp gaat aan, slot klikt dicht), de naam verschijnt en alles zoomt weg.
struct SplashView: View {
    var onFinish: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var shown = [false, false, false, false]
    @State private var active = false
    @State private var pulse = false
    @State private var showTitle = false
    @State private var leaving = false

    private let title = Array("Homio")

    var body: some View {
        let logoSize: CGFloat = sizeClass == .compact ? 200 : 260
        ZStack {
            IconPalette.background.ignoresSafeArea()

            // Warme gloed van de lamp.
            RadialGradient(colors: [IconPalette.yellow.opacity(active ? 0.16 : 0), .clear],
                           center: .center, startRadius: 10, endRadius: active ? 520 : 80)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                HomioLogo(size: logoSize, shown: shown, active: active)
                    .scaleEffect(pulse ? 1.04 : 1)
                    .scaleEffect(leaving ? 1.45 : 1)

                VStack(spacing: 12) {
                    HStack(spacing: 1) {
                        ForEach(Array(title.enumerated()), id: \.offset) { index, letter in
                            Text(String(letter))
                                .font(.system(size: sizeClass == .compact ? 50 : 64, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .opacity(showTitle ? 1 : 0)
                                .offset(y: showTitle ? 0 : 20)
                                .blur(radius: showTitle ? 0 : 6)
                                .animation(.spring(response: 0.55, dampingFraction: 0.72)
                                    .delay(Double(index) * 0.06), value: showTitle)
                        }
                    }
                    Text("Je huis in één oogopslag")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(showTitle ? 0.6 : 0))
                        .animation(.easeOut(duration: 0.8).delay(0.35), value: showTitle)
                }
            }
            .opacity(leaving ? 0 : 1)
            .blur(radius: leaving ? 14 : 0)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: active)
        .task { await run() }
    }

    private func run() async {
        try? await Task.sleep(nanoseconds: 150_000_000)
        for index in 0..<4 {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.66)) { shown[index] = true }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation(.easeInOut(duration: 1.1)) { active = true }
        try? await Task.sleep(nanoseconds: 700_000_000)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pulse = true }
        showTitle = true
        try? await Task.sleep(nanoseconds: 180_000_000)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { pulse = false }
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        withAnimation(.easeIn(duration: 0.5)) { leaving = true }
        try? await Task.sleep(nanoseconds: 420_000_000)
        onFinish()
    }
}

#Preview {
    SplashView {}
}
