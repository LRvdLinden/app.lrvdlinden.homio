import SwiftUI

enum AppTab: Hashable {
    case home, devices, flows, dashboards, more
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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            HomeTab(startDisplay: startDisplay)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            DevicesTab(startDisplay: startDisplay)
                .tabItem { Label("Apparaten", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.devices)

            FlowsTab()
                .tabItem { Label("Automatisering", systemImage: "arrow.triangle.branch") }
                .tag(AppTab.flows)

            DashboardsTab(startDisplay: startDisplay)
                .tabItem { Label("Dashboards", systemImage: "rectangle.3.group.fill") }
                .tag(AppTab.dashboards)

            SettingsView(showsDone: false, startDisplay: startDisplay)
                .tabItem { Label("Meer", systemImage: "ellipsis.circle.fill") }
                .tag(AppTab.more)
        }
        .fullScreenCover(isPresented: $displayMode) {
            MainView()
                .environment(\.colorScheme, .dark)
        }
        .modifier(ReviewPromptModifier(blocked: displayMode))
        .onChange(of: home.isReady) { _, ready in
            if ready {
                PushRelay.shared.applyDefaultsIfNeeded(home.devices)
                HomioShortcuts.updateAppShortcutParameters()
                MatterStore.shared.publishRooms(home.allRooms.map(\.name))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Apparaten die via het koppelscherm van Apple zijn toegevoegd, overnemen.
            if phase == .active { MatterStore.shared.start() }
        }
        .onAppear {
            settings.ensureProfile(named: auth.displayName)
            settings.applyKeepAwake()
            home.start()
            history.start()
            CloudSync.shared.syncNow()
            MatterStore.shared.start()
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
