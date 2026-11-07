import EventKit
import SwiftUI

struct CalendarFace: View {
    @EnvironmentObject private var calendar: CalendarService
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var compact: Bool { sizeClass == .compact }

    var body: some View {
        ZStack {
            AmbientBackground(intensity: 0.35)
            AdaptiveStack(spacing: compact ? 18 : 50, rowAlignment: .top) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.date.formatted(.dateTime.weekday(.wide)).capitalized)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(Theme.amber)
                        Text(context.date.formatted(.dateTime.day()))
                            .font(.system(size: compact ? 84 : 160, weight: .thin, design: .rounded))
                        Text(context.date.formatted(.dateTime.month(.wide).year()).capitalized)
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: compact ? nil : 300, alignment: .leading)

                Group {
                    if calendar.denied {
                        ContentUnavailableView("Geen toegang tot Agenda",
                                               systemImage: "calendar.badge.exclamationmark",
                                               description: Text("Sta toegang toe in Instellingen › Privacy en beveiliging › Agenda's."))
                    } else if calendar.events.isEmpty {
                        ContentUnavailableView("Niets gepland",
                                               systemImage: "calendar",
                                               description: Text("Geen afspraken in de komende zeven dagen."))
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                ForEach(calendar.byDay) { group in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(dayTitle(group.day))
                                            .font(.headline)
                                            .foregroundStyle(.white.opacity(0.6))
                                        ForEach(group.events, id: \.self) { event in
                                            EventRow(event: event)
                                        }
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.white)
            .facePadding(compact)
        }
        .onAppear { calendar.start() }
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Vandaag" }
        if Calendar.current.isDateInTomorrow(day) { return "Morgen" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
    }
}

private struct EventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.color)
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title ?? "Afspraak").font(.title3.weight(.semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(event.timeText)
                    if let location = event.location, !location.isEmpty {
                        Text("· \(location)").lineLimit(1)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCard(corner: 18)
    }
}
