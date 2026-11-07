import StoreKit
import SwiftUI

/// Regels voor de beoordelingsvraag, per apparaat:
/// - eerste keer: 4 uur na het eerste gebruik op dit apparaat;
/// - daarna: hooguit één keer per week;
/// - alleen op een rustig moment: een paar seconden na het openen, niet tijdens
///   splash, inloggen of de weergavemodus, en pas als er minstens één apparaat is.
/// Apple bepaalt daarnaast zelf of de vraag echt verschijnt (max. 3 keer per jaar).
enum ReviewPrompter {
    private static let firstUseKey = "homio.review.firstUse"
    private static let vendorKey = "homio.review.vendor"
    private static let lastAskedKey = "homio.review.lastAsked"

    static let firstDelay: TimeInterval = 4 * 3600
    static let repeatInterval: TimeInterval = 7 * 86_400
    static let settleDelay: UInt64 = 4_000_000_000

    /// Onthoudt het eerste gebruik. Na het terugzetten van een back-up op een ander
    /// apparaat verandert de leveranciers-ID, en telt het opnieuw als eerste gebruik.
    static func registerFirstUse() {
        let defaults = UserDefaults.standard
        let vendor = UIDevice.current.identifierForVendor?.uuidString ?? "onbekend"
        if defaults.object(forKey: firstUseKey) == nil || defaults.string(forKey: vendorKey) != vendor {
            defaults.set(Date(), forKey: firstUseKey)
            defaults.set(vendor, forKey: vendorKey)
            defaults.removeObject(forKey: lastAskedKey)
        }
    }

    static func isDue(now: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        guard let first = defaults.object(forKey: firstUseKey) as? Date,
              now.timeIntervalSince(first) >= firstDelay else { return false }
        if let last = defaults.object(forKey: lastAskedKey) as? Date,
           now.timeIntervalSince(last) < repeatInterval {
            return false
        }
        return true
    }

    static func markAsked(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: lastAskedKey)
    }
}

struct ReviewPromptModifier: ViewModifier {
    /// Waar, als er nu iets anders op het scherm hoort (bijv. de weergavemodus).
    let blocked: Bool

    @EnvironmentObject private var home: HomeStore
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                ReviewPrompter.registerFirstUse()
                schedule()
            }
            .onDisappear { pending?.cancel() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { schedule() } else { pending?.cancel() }
            }
            .onChange(of: blocked) { _, isBlocked in
                if isBlocked { pending?.cancel() } else { schedule() }
            }
    }

    private func schedule() {
        pending?.cancel()
        guard !blocked, scenePhase == .active else { return }
        pending = Task { @MainActor in
            try? await Task.sleep(nanoseconds: ReviewPrompter.settleDelay)
            guard !Task.isCancelled,
                  !home.devices.isEmpty,
                  ReviewPrompter.isDue() else { return }
            ReviewPrompter.markAsked()
            requestReview()
        }
    }
}
