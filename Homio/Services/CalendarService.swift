import EventKit
import SwiftUI

@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var events: [EKEvent] = []
    @Published private(set) var authorized = false
    @Published private(set) var denied = false

    private let store = EKEventStore()
    private var started = false

    func start() {
        guard !started else { reload(); return }
        started = true
        Task {
            do {
                let granted = try await store.requestFullAccessToEvents()
                authorized = granted
                denied = !granted
                if granted {
                    reload()
                    NotificationCenter.default.addObserver(forName: .EKEventStoreChanged,
                                                           object: store, queue: .main) { [weak self] _ in
                        Task { @MainActor in self?.reload() }
                    }
                }
            } catch {
                denied = true
            }
        }
    }

    func reload() {
        guard authorized else { return }
        let start = Calendar.current.startOfDay(for: Date())
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .filter { $0.endDate > Date() }
            .sorted { $0.startDate < $1.startDate }
    }

    var nextEvent: EKEvent? { events.first }

    /// Afspraken per dag, voor de agenda-face.
    var byDay: [DayEvents] {
        let grouped = Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.startDate) }
        return grouped.keys.sorted().map { DayEvents(day: $0, events: grouped[$0] ?? []) }
    }
}

struct DayEvents: Identifiable {
    let day: Date
    let events: [EKEvent]
    var id: Date { day }
}

extension EKEvent {
    var timeText: String {
        if isAllDay { return "Hele dag" }
        return startDate.formatted(date: .omitted, time: .shortened)
    }

    var color: Color {
        if let cg = calendar?.cgColor { return Color(cgColor: cg) }
        return Theme.amber
    }
}
