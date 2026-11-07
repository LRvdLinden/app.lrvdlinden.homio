import SwiftUI

@main
struct HomioWatchApp: App {
    @StateObject private var home = WatchHome()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(home)
                .tint(WatchPalette.orange)
        }
    }
}

enum WatchPalette {
    static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let yellow = Color(red: 1.0, green: 0.80, blue: 0.0)
    static let blue = Color(red: 0.039, green: 0.518, blue: 1.0)
}
