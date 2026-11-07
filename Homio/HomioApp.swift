import SwiftUI

@main
struct HomioApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var appDelegate
    @StateObject private var auth = AuthStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var home = HomeStore.shared
    @StateObject private var weather = WeatherService()
    @StateObject private var calendar = CalendarService()
    @StateObject private var photos = PhotoLibraryStore()
    @StateObject private var timers = TimersStore()
    @StateObject private var proximity = ProximityMonitor()
    @StateObject private var dashboards = DashboardStore()
    @StateObject private var history = HistoryStore.shared
    @StateObject private var flows = FlowStore.shared
    @StateObject private var relay = PushRelay.shared
    @StateObject private var groups = GroupStore()
    @StateObject private var cloud = CloudSync.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(settings)
                .environmentObject(home)
                .environmentObject(weather)
                .environmentObject(calendar)
                .environmentObject(photos)
                .environmentObject(timers)
                .environmentObject(proximity)
                .environmentObject(dashboards)
                .environmentObject(history)
                .environmentObject(flows)
                .environmentObject(relay)
                .environmentObject(groups)
                .environmentObject(cloud)
                .preferredColorScheme(.dark)
                .tint(Theme.amber)
        }
    }
}
