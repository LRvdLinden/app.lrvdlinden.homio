import Charts
import SwiftUI

/// Inzichten: grafieken van temperatuur, vocht, licht en schakelaars, en een tijdlijn.
struct InsightsTab: View {
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var mode = 0
    @State private var selected: Metric?
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Weergave", selection: $mode) {
                        Text("Grafieken").tag(0)
                        Text("Tijdlijn").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)

                    if mode == 0 { charts } else { timeline }
                }
                .padding(.horizontal, sizeClass == .compact ? 16 : 28)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Inzichten")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { history.sample() } label: { Label("Nu meten", systemImage: "arrow.clockwise") }
                        Button(role: .destructive) { confirmClear = true } label: {
                            Label("Geschiedenis wissen", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selected) { metric in
                MetricDetailView(metric: metric)
            }
            .confirmationDialog("Alle metingen en de tijdlijn wissen?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Wissen", role: .destructive) { history.clearAll() }
            }
        }
    }

    // MARK: Grafieken

    @ViewBuilder
    private var charts: some View {
        let metrics = history.sortedMetrics
        if metrics.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                GradientIcon(symbol: "chart.xyaxis.line", colors: [IconPalette.orange, IconPalette.yellow], size: 52)
                Text("Metingen worden verzameld").font(.title3.weight(.semibold))
                Text("Apple Woning bewaart geen geschiedenis. Homio meet daarom zelf elke 5 minuten zolang de app open is. Op een iPad aan de muur heb je zo altijd een volledige grafiek. Kom over een uurtje terug.")
                    .foregroundStyle(.secondary)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        } else {
            ForEach(MetricKind.allCases, id: \.self) { kind in
                let group = metrics.filter { $0.kind == kind }
                if !group.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(kind.title, systemImage: kind.symbol)
                            .font(.headline)
                            .foregroundStyle(kind.color)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .compact ? 300 : 320), spacing: 12)], spacing: 12) {
                            ForEach(group) { metric in
                                Button { selected = metric } label: {
                                    MetricCard(metric: metric)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Tijdlijn

    @ViewBuilder
    private var timeline: some View {
        if history.log.isEmpty {
            ContentUnavailableView("Nog niets gebeurd",
                                   systemImage: "list.bullet.rectangle",
                                   description: Text("Hier zie je wat er in huis gebeurt: lampen, deuren, sloten en beweging."))
        } else {
            let groups = Dictionary(grouping: history.log) { Calendar.current.startOfDay(for: $0.date) }
            ForEach(groups.keys.sorted(by: >), id: \.self) { day in
                VStack(alignment: .leading, spacing: 0) {
                    Text(dayTitle(day))
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 8)
                    ForEach(groups[day] ?? []) { entry in
                        TimelineRow(entry: entry)
                    }
                }
                .padding(16)
                .card()
            }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Vandaag" }
        if Calendar.current.isDateInYesterday(day) { return "Gisteren" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
    }
}

private struct TimelineRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: entry.symbol)
                    .font(.subheadline)
                    .foregroundStyle(IconPalette.orange)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(IconPalette.orange.opacity(0.15)))
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.subheadline.weight(.semibold))
                Text(entry.room.isEmpty ? entry.detail : "\(entry.detail) · \(entry.room)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)
            Spacer()
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private struct MetricCard: View {
    let metric: Metric
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.name).font(.headline).lineLimit(1)
                Text(metric.room).font(.caption).foregroundStyle(.secondary)
                Text(history.latest(metric.key).map { metric.kind.format($0) } ?? "–")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(metric.kind.color)
            }
            .frame(width: 130, alignment: .leading)
            MetricSparkline(metric: metric, hours: 24)
                .frame(height: 70)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .foregroundStyle(.white)
    }
}

/// Kleine grafiek zonder assen.
struct MetricSparkline: View {
    let metric: Metric
    var hours: Double = 24
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        let points = history.points(metric.key, hours: hours)
        if points.count < 2 {
            Text("Te weinig metingen")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(points, id: \.t) { point in
                AreaMark(x: .value("Tijd", point.date), y: .value("Waarde", point.v))
                    .interpolationMethod(metric.kind.isStep ? .stepEnd : .catmullRom)
                    .foregroundStyle(LinearGradient(colors: [metric.kind.color.opacity(0.35), metric.kind.color.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Tijd", point.date), y: .value("Waarde", point.v))
                    .interpolationMethod(metric.kind.isStep ? .stepEnd : .catmullRom)
                    .foregroundStyle(metric.kind.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: metric.kind != .temperature))
        }
    }
}

/// Grote grafiek met bereik, minimum, maximum en gemiddelde.
struct MetricDetailView: View {
    let metric: Metric
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var hours: Double = 24

    var body: some View {
        let points = history.points(metric.key, hours: hours)
        let values = points.map(\.v)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Periode", selection: $hours) {
                        Text("6 uur").tag(6.0)
                        Text("24 uur").tag(24.0)
                        Text("3 dagen").tag(72.0)
                        Text("7 dagen").tag(168.0)
                    }
                    .pickerStyle(.segmented)

                    if points.count < 2 {
                        ContentUnavailableView("Te weinig metingen",
                                               systemImage: "chart.xyaxis.line",
                                               description: Text("Laat Homio wat langer open staan."))
                    } else {
                        Chart(points, id: \.t) { point in
                            AreaMark(x: .value("Tijd", point.date), y: .value("Waarde", point.v))
                                .interpolationMethod(metric.kind.isStep ? .stepEnd : .catmullRom)
                                .foregroundStyle(LinearGradient(colors: [metric.kind.color.opacity(0.35), metric.kind.color.opacity(0)],
                                                                startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("Tijd", point.date), y: .value("Waarde", point.v))
                                .interpolationMethod(metric.kind.isStep ? .stepEnd : .catmullRom)
                                .foregroundStyle(metric.kind.color)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                        }
                        .chartYScale(domain: .automatic(includesZero: metric.kind != .temperature))
                        .frame(height: 280)
                        .padding(16)
                        .card()

                        if let min = values.min(), let max = values.max() {
                            HStack(spacing: 12) {
                                stat("Laagste", metric.kind.format(min))
                                stat("Gemiddeld", metric.kind.format(values.reduce(0, +) / Double(values.count)))
                                stat("Hoogste", metric.kind.format(max))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(metric.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gereed") { dismiss() }
                }
            }
        }
        .presentationBackground(Theme.background)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(metric.kind.color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
