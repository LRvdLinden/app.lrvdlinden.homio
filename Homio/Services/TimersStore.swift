import AudioToolbox
import SwiftUI
import UserNotifications

struct KitchenTimer: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String
    var duration: TimeInterval
    var endDate: Date
    var pausedRemaining: TimeInterval?

    var isPaused: Bool { pausedRemaining != nil }

    func remaining(at now: Date = Date()) -> TimeInterval {
        pausedRemaining ?? max(0, endDate.timeIntervalSince(now))
    }

    func progress(at now: Date = Date()) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, 1 - remaining(at: now) / duration))
    }
}

/// Meerdere timers tegelijk, met wekker en melding.
@MainActor
final class TimersStore: ObservableObject {
    @Published private(set) var timers: [KitchenTimer] = []
    @Published private(set) var ringing: KitchenTimer?

    private let key = "homio.timers.v1"
    private var lastRing = Date.distantPast
    private var askedPermission = false

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([KitchenTimer].self, from: data) {
            timers = saved
        }
        CloudSync.shared.register("timers", apply: { [weak self] data in
            self?.applyRemote(data)
        }, current: { [weak self] in
            guard let self else { return nil }
            return try? JSONEncoder().encode(self.timers)
        })
    }

    private func save() {
        if let data = try? JSONEncoder().encode(timers) {
            UserDefaults.standard.set(data, forKey: key)
            CloudSync.shared.push("timers", payload: data)
        }
    }

    /// Timers van een ander apparaat: overnemen en de meldingen op dit apparaat bijwerken.
    private func applyRemote(_ data: Data) {
        guard let remote = try? JSONDecoder().decode([KitchenTimer].self, from: data) else { return }
        let gone = timers.filter { old in !remote.contains { $0.id == old.id } }
        for timer in gone { unschedule(timer) }
        timers = remote
        if let local = try? JSONEncoder().encode(remote) {
            UserDefaults.standard.set(local, forKey: key)
        }
        for timer in remote {
            if timer.isPaused { unschedule(timer) } else if timer.remaining() > 0 { schedule(timer) }
        }
    }

    func add(seconds: TimeInterval, label: String) {
        guard seconds > 0 else { return }
        let name = label.trimmingCharacters(in: .whitespaces)
        let timer = KitchenTimer(label: name.isEmpty ? Self.format(seconds) : name,
                                 duration: seconds,
                                 endDate: Date().addingTimeInterval(seconds))
        timers.append(timer)
        save()
        schedule(timer)
    }

    func togglePause(_ timer: KitchenTimer) {
        guard let index = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        if let remaining = timers[index].pausedRemaining {
            timers[index].endDate = Date().addingTimeInterval(remaining)
            timers[index].pausedRemaining = nil
            schedule(timers[index])
        } else {
            timers[index].pausedRemaining = timers[index].remaining()
            unschedule(timers[index])
        }
        save()
    }

    func remove(_ timer: KitchenTimer) {
        timers.removeAll { $0.id == timer.id }
        unschedule(timer)
        save()
    }

    func tick() {
        let now = Date()
        if ringing == nil, let done = timers.first(where: { !$0.isPaused && $0.endDate <= now }) {
            timers.removeAll { $0.id == done.id }
            save()
            ringing = done
            lastRing = .distantPast
        }
        if ringing != nil, now.timeIntervalSince(lastRing) >= 2 {
            lastRing = now
            AudioServicesPlaySystemSound(1005)
        }
    }

    func stopRinging() {
        ringing = nil
    }

    // MARK: Meldingen voor als de app op de achtergrond staat

    private func schedule(_ timer: KitchenTimer) {
        let center = UNUserNotificationCenter.current()
        if !askedPermission {
            askedPermission = true
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        let content = UNMutableNotificationContent()
        content.title = "Timer afgelopen"
        content.body = timer.label
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, timer.remaining()), repeats: false)
        center.add(UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: trigger))
    }

    private func unschedule(_ timer: KitchenTimer) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timer.id.uuidString])
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
