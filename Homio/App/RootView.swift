import Combine
import SwiftUI

/// Splash → welkom → inloggen → hoofdscherm, met de wekker van de timers er altijd bovenop.
struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var timers: TimersStore
    @EnvironmentObject private var proximity: ProximityMonitor
    @Environment(\.scenePhase) private var scenePhase

    @State private var splashDone = false
    @AppStorage("onboarding.done") private var onboardingDone = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if !splashDone {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.6)) { splashDone = true }
                }
                .transition(.opacity)
                .environment(\.colorScheme, .dark)
            } else if !onboardingDone {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.5)) { onboardingDone = true }
                }
                .transition(.opacity)
            } else if !auth.isSignedIn {
                LoginView()
                    .environment(\.colorScheme, .dark)
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else {
                AppShell()
                    .transition(.opacity)
            }

            if let ringing = timers.ringing {
                TimerAlarmView(timer: ringing)
                    .environment(\.colorScheme, .dark)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: timers.ringing?.id)
        .onReceive(ticker) { _ in
            timers.tick()
            proximity.tick()
        }
        .onAppear { auth.verifyCredential() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if auth.isSignedIn && settings.proximityEnabled { proximity.start() }
            case .background:
                proximity.stop()
            default:
                break
            }
        }
    }
}
