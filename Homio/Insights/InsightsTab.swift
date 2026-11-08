import Charts
import SwiftUI

/// Inzichten: grafieken van temperatuur, vocht, licht en schakelaars, en een tijdlijn.
struct InsightsTab: View {
    @EnvironmentObject private var history: HistoryStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var mode = 0
    @State private var selected: Metric?
    @AppStorage("insights.focus") private var focusKey = ""
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PillSegments(items: [(0, "Grafieken"), (1, "Tijdlijn")], selection: $mode)
                        .frame(maxWidth: 420)

                    if mode == 0 { charts } else { timeline }
                }
                .padding(.horizontal, sizeClass == .compact ? Theme.edge : Theme.edgeTablet)
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
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Theme.blueGradient))
                Text("Metingen worden verzameld").font(HomeyFont.large.weight(.bold))
                Text("Apple Woning bewaart geen geschiedenis. Homio meet daarom zelf elke 5 minuten zolang de app open is. Op een iPad aan de muur heb je zo altijd een volledige grafiek. Kom over een uurtje terug.")
                    .foregroundStyle(Theme.textLight)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.cornerLarge, style: .continuous).fill(Theme.card))
        } else {
            let current = metrics.first { $0.key == focusKey } ?? metrics[0]
            InsightsCard(metric: current, metrics: metrics) { focusKey = $0.key }
            SectionHeading(title: "Alle meetwaarden", subtitle: "Tik om bovenaan te tonen")
                .padding(.top, 8)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .compact ? 300 : 320), spacing: 12)], spacing: 12) {
                ForEach(metrics) { metric in
                    Button {
                        withAnimation { focusKey = metric.key }
                    } label: {
                        MetricCard(metric: metric, selected: metric.key == current.key)
                    }
                    .buttonStyle(PressableStyle())
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
                        .foregroundStyle(Color.primary.opacity(0.7))
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
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.subheadline.weight(.semibold))
                Text(entry.room.isEmpty ? entry.detail : "\(entry.detail) · \(entry.room)")
                    .font(.caption)
                    .foregroundStyle(Theme.textLight)
            }
            .padding(.bottom, 12)
            Spacer()
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textLight)
        }
    }
}

private struct MetricCard: View {
    let metric: Metric
    var selected = false
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label(metric.kind.title, systemImage: metric.kind.symbol)
                    .font(HomeyFont.tiny.weight(.medium))
                    .foregroundStyle(metric.kind.color)
                Text(metric.name).font(HomeyFont.bodyMedium).foregroundStyle(Theme.text).lineLimit(1)
                Text(history.latest(metric.key).map { metric.kind.format($0) } ?? "–")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.text)
            }
            .frame(width: 130, alignment: .leading)
            MetricSparkline(metric: metric, hours: 24)
                .frame(height: 64)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerLarge, style: .continuous)
            .strokeBorder(selected ? metric.kind.color : .clear, lineWidth: 2))
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
                .foregroundStyle(Theme.textLight)
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
            Text(title).font(.caption).foregroundStyle(Theme.textLight)
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(metric.kind.color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Homey Insights-kaart

/// Periode zoals in Homey Insights: uur, dag, week, maand, jaar.
enum InsightsPeriod: Int, CaseIterable {
    case hour, day, week, month, year

    var letter: LocalizedStringKey {
        switch self {
        case .hour: return "U"
        case .day: return "D"
        case .week: return "W"
        case .month: return "M"
        case .year: return "J"
        }
    }

    /// Begin en eind van de periode; `back` = 1 voor de vorige.
    func range(back: Int, now: Date = Date()) -> (Date, Date) {
        let cal = Calendar.current
        switch self {
        case .hour:
            let end = now.addingTimeInterval(Double(-back) * 3600)
            return (end.addingTimeInterval(-3600), end)
        case .day, .week, .month, .year:
            let comp: Calendar.Component = self == .day ? .day : (self == .week ? .weekOfYear : (self == .month ? .month : .year))
            let interval = cal.dateInterval(of: comp, for: now) ?? DateInterval(start: now, duration: 86_400)
            let start = cal.date(byAdding: comp, value: -back, to: interval.start) ?? interval.start
            let end = cal.date(byAdding: comp, value: 1, to: start) ?? now
            return (start, back == 0 ? now : end)
        }
    }

    func title(back: Int) -> String {
        switch (self, back) {
        case (.hour, 0): return "Afgelopen uur"
        case (.hour, _): return "Uur ervoor"
        case (.day, 0): return "Vandaag"
        case (.day, _): return "Gisteren"
        case (.week, 0): return "Deze week"
        case (.week, _): return "Vorige week"
        case (.month, 0): return "Deze maand"
        case (.month, _): return "Vorige maand"
        case (.year, 0): return "Dit jaar"
        case (.year, _): return "Vorig jaar"
        }
    }

    var compareLabels: (String, String) {
        (title(back: 0), title(back: 1))
    }
}

struct InsightsCard: View {
    let metric: Metric
    let metrics: [Metric]
    let onPick: (Metric) -> Void

    @EnvironmentObject private var history: HistoryStore
    @State private var period: InsightsPeriod = .day
    @State private var back = 0
    @State private var selectedDate: Date?

    var body: some View {
        let range = period.range(back: back)
        let from = range.0
        let to = range.1
        let points = history.points(metric.key, from: from, to: to)
        let selectedPoint = selectedDate.flatMap { d in points.min { abs($0.date.timeIntervalSince(d)) < abs($1.date.timeIntervalSince(d)) } }
        let color = metric.kind.color

        VStack(spacing: 16) {
            Text(metric.name).font(HomeyFont.bodyBold).foregroundStyle(Theme.text)

            Menu {
                ForEach(MetricKind.allCases, id: \.self) { kind in
                    let group = metrics.filter { $0.kind == kind }
                    if !group.isEmpty {
                        Section(kind.title) {
                            ForEach(group) { m in
                                Button { onPick(m) } label: { Label(m.name, systemImage: kind.symbol) }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: metric.kind.symbol)
                    Text(metric.kind.title)
                    Image(systemName: "chevron.down").font(.caption.weight(.bold))
                }
                .font(HomeyFont.smallMedium)
                .foregroundStyle(color)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(Theme.insightsPill))
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedPoint.map { $0.date.formatted(date: .omitted, time: .shortened) } ?? period.title(back: back))
                        .font(HomeyFont.xlarge)
                        .foregroundStyle(Theme.text)
                    Text(from.formatted(.dateTime.day().month(.wide).year()))
                        .font(HomeyFont.small)
                        .foregroundStyle(Theme.textLight)
                }
                Spacer()
                let value = selectedPoint?.v ?? points.last?.v ?? history.latest(metric.key)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value.map { valueText($0) } ?? "–")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                    Text(metric.kind.unit)
                        .font(HomeyFont.bodyMedium)
                        .foregroundStyle(color.opacity(0.6))
                }
            }

            chart(points: points, selected: selectedPoint, from: from, to: to, color: color)
                .frame(height: 240)

            PillSegments(items: InsightsPeriod.allCases.map { ($0, $0.letter) }, selection: $period)
            PillSegments(items: [(0, LocalizedStringKey(period.compareLabels.0)), (1, LocalizedStringKey(period.compareLabels.1))],
                         selection: $back)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: Theme.cornerLarge, style: .continuous).fill(Theme.insightsCard))
        .onChange(of: period) { _, _ in selectedDate = nil }
        .onChange(of: back) { _, _ in selectedDate = nil }
    }

    private func valueText(_ v: Double) -> String {
        switch metric.kind {
        case .power: return v > 0.5 ? "Aan" : "Uit"
        case .temperature: return v.formatted(.number.precision(.fractionLength(1)))
        default: return v.formatted(.number.precision(.fractionLength(0...1)))
        }
    }

    @ViewBuilder
    private func chart(points: [Sample], selected: Sample?, from: Date, to: Date, color: Color) -> some View {
        if points.count < 2 {
            ZStack {
                RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.insightsGrid, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                Text("Nog geen metingen in deze periode")
                    .font(HomeyFont.small)
                    .foregroundStyle(Theme.textLight)
            }
        } else {
            let interpolation: InterpolationMethod = metric.kind.isStep ? .stepCenter : .catmullRom
            Chart {
                ForEach(points, id: \.t) { p in
                    AreaMark(x: .value("Tijd", p.date), y: .value(metric.kind.unit, p.v))
                        .interpolationMethod(interpolation)
                        .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Tijd", p.date), y: .value(metric.kind.unit, p.v))
                        .interpolationMethod(interpolation)
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                if let s = selected {
                    RuleMark(x: .value("Tijd", s.date))
                        .foregroundStyle(Theme.textLight.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(x: .value("Tijd", s.date), y: .value(metric.kind.unit, s.v))
                        .symbol {
                            Circle().fill(Theme.insightsCard).frame(width: 11, height: 11)
                                .overlay(Circle().strokeBorder(color, lineWidth: 2.5))
                        }
                }
            }
            .chartXScale(domain: from...max(to, from.addingTimeInterval(60)))
            .chartYScale(domain: .automatic(includesZero: metric.kind != .temperature))
            .chartYAxisLabel(position: .topLeading) {
                Text(verbatim: metric.kind.unit).font(HomeyFont.extraTiny).foregroundStyle(Theme.textLight)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Theme.insightsGrid)
                    AxisValueLabel().font(HomeyFont.extraTiny).foregroundStyle(Theme.textLight)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel().font(HomeyFont.extraTiny).foregroundStyle(Theme.textLight)
                }
            }
            .chartXSelection(value: $selectedDate)
            .sensoryFeedback(.selection, trigger: selected?.t)
        }
    }
}

/// Pil-segmenten zoals in Homey (U D W M J, of deze/vorige periode).
struct PillSegments<T: Hashable>: View {
    let items: [(T, LocalizedStringKey)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                Button { selection = item.0 } label: {
                    Text(item.1)
                        .font(HomeyFont.smallMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection == item.0 ? Theme.insightsSelected : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == item.0 ? Theme.text : Theme.textLight)
            }
        }
        .padding(4)
        .background(Theme.insightsPill, in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}
