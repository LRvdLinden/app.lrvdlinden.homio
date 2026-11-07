import Combine
import SwiftUI

/// Splash → inloggen → hoofdscherm, met de wekker van de timers er altijd bovenop.
struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var timers: TimersStore
    @EnvironmentObject private var proximity: ProximityMonitor
    @Environment(\.scenePhase) private var scenePhase

    @State private var splashDone = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if !splashDone {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.6)) { splashDone = true }
                }
                .transition(.opacity)
            } else if !auth.isSignedIn {
                LoginView()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else {
                AppShell()
                    .transition(.opacity)
            }

            if let ringing = timers.ringing {
                TimerAlarmView(timer: ringing)
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
