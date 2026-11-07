import SwiftUI

enum AppTab: Hashable {
    case home, dashboards, flows, insights, more
}

/// De app na het inloggen: vijf tabbladen, plus de weergavemodus (kiosk) over alles heen.
struct AppShell: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var proximity: ProximityMonitor
    @EnvironmentObject private var history: HistoryStore

    @State private var tab: AppTab = .home
    @State private var displayMode = false
    @State private var didAutoStart = false

    var body: some View {
        TabView(selection: $tab) {
            HomeTab(startDisplay: startDisplay)
                .tabItem { Label("Thuis", systemImage: "house.fill") }
                .tag(AppTab.home)

            DashboardsTab(startDisplay: startDisplay)
                .tabItem { Label("Dashboards", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.dashboards)

            FlowsTab()
                .tabItem { Label("Flows", systemImage: "arrow.triangle.branch") }
                .tag(AppTab.flows)

            InsightsTab()
                .tabItem { Label("Inzichten", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.insights)

            SettingsView(showsDone: false, startDisplay: startDisplay)
                .tabItem { Label("Meer", systemImage: "ellipsis.circle.fill") }
                .tag(AppTab.more)
        }
        .fullScreenCover(isPresented: $displayMode) {
            MainView()
        }
        .modifier(ReviewPromptModifier(blocked: displayMode))
        .onChange(of: home.isReady) { _, ready in
            if ready {
                PushRelay.shared.applyDefaultsIfNeeded(home.devices)
                HomioShortcuts.updateAppShortcutParameters()
            }
        }
        .onAppear {
            settings.ensureProfile(named: auth.displayName)
            settings.applyKeepAwake()
            home.start()
            history.start()
            CloudSync.shared.syncNow()
            if settings.proximityEnabled { proximity.start() }
            if settings.startInDisplayMode && !didAutoStart {
                didAutoStart = true
                displayMode = true
            }
        }
    }

    private func startDisplay() {
        displayMode = true
    }
}
