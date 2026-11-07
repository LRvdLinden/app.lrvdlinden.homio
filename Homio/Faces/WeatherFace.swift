import SwiftUI

struct WeatherFace: View {
    @EnvironmentObject private var weather: WeatherService
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var compact: Bool { sizeClass == .compact }

    private var gradient: [Color] {
        guard let c = weather.current else { return [Theme.background, Theme.background] }
        if !c.isDay { return [Color(red: 0.05, green: 0.07, blue: 0.18), Color(red: 0.12, green: 0.1, blue: 0.3)] }
        switch c.code {
        case 0, 1: return [Color(red: 0.16, green: 0.45, blue: 0.85), Color(red: 0.45, green: 0.72, blue: 0.98)]
        case 2, 3, 45, 48: return [Color(red: 0.3, green: 0.36, blue: 0.45), Color(red: 0.52, green: 0.58, blue: 0.66)]
        default: return [Color(red: 0.14, green: 0.2, blue: 0.32), Color(red: 0.28, green: 0.36, blue: 0.5)]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1), value: weather.current?.code)

            if let code = weather.current?.code, WeatherService.isRainy(code) {
                RainView().ignoresSafeArea().allowsHitTesting(false)
            }

            if let current = weather.current {
                ScrollView {
                    AdaptiveStack(spacing: compact ? 22 : 50) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(weather.place.isEmpty ? "Hier" : weather.place)
                                .font(.title.weight(.semibold))
                            Text("\(Int(current.temperature.rounded()))°")
                                .font(.system(size: compact ? 110 : 150, weight: .thin, design: .rounded))
                            Label(WeatherService.description(for: current.code),
                                  systemImage: WeatherService.symbol(for: current.code, isDay: current.isDay))
                                .symbolRenderingMode(.multicolor)
                                .font(.title2)
                            if let today = weather.days.first {
                                Text("H \(Int(today.high.rounded()))°  L \(Int(today.low.rounded()))°  ·  wind \(Int(current.wind.rounded())) km/u")
                                    .font(compact ? .body : .title3)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer().frame(height: compact ? 8 : 20)
                            HourStrip()
                        }
                        DayList()
                            .frame(maxWidth: compact ? CGFloat.infinity : 330)
                    }
                    .foregroundStyle(.white)
                    .facePadding(compact)
                }
                .scrollIndicators(.hidden)
            } else {
                VStack(spacing: 14) {
                    ProgressView().tint(.white)
                    Text(weather.problem ?? "Weer laden…").foregroundStyle(.white)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Weergegevens: Open-Meteo.com")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.trailing, 24)
                        .padding(.bottom, 8)
                }
            }
        }
        .onAppear { weather.start() }
    }
}

private struct HourStrip: View {
    @EnvironmentObject private var weather: WeatherService

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(weather.hours) { hour in
                    VStack(spacing: 8) {
                        Text(hour.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                        Image(systemName: WeatherService.symbol(for: hour.code))
                            .symbolRenderingMode(.multicolor)
                            .font(.title2)
                        Text("\(Int(hour.temperature.rounded()))°")
                            .font(.headline)
                    }
                }
            }
            .padding(18)
        }
        .glassCard()
    }
}

private struct DayList: View {
    @EnvironmentObject private var weather: WeatherService

    var body: some View {
        VStack(spacing: 0) {
            ForEach(weather.days) { day in
                HStack {
                    Text(Calendar.current.isDateInToday(day.date) ? "Vandaag" : day.date.formatted(.dateTime.weekday(.abbreviated)).capitalized)
                        .frame(width: 80, alignment: .leading)
                    Image(systemName: WeatherService.symbol(for: day.code))
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 36)
                    Spacer()
                    Text("\(Int(day.low.rounded()))°").foregroundStyle(.white.opacity(0.6))
                    Text("\(Int(day.high.rounded()))°").frame(width: 40, alignment: .trailing)
                }
                .font(.title3)
                .padding(.vertical, 10)
                if day.id != weather.days.last?.id { Divider().overlay(.white.opacity(0.2)) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .glassCard()
    }
}

/// Vallende regen.
private struct RainView: View {
    private struct Drop {
        let x: Double
        let speed: Double
        let length: Double
        let offset: Double
    }

    @State private var drops: [Drop] = (0..<140).map { _ in
        Drop(x: .random(in: 0...1), speed: .random(in: 0.5...1.1),
             length: .random(in: 14...30), offset: .random(in: 0...1))
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                for drop in drops {
                    let progress = (t * drop.speed * 0.8 + drop.offset).truncatingRemainder(dividingBy: 1)
                    let y = progress * (size.height + 60) - 30
                    let x = drop.x * size.width - progress * 30
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - 4, y: y + drop.length))
                    gc.stroke(p, with: .color(.white.opacity(0.25)), lineWidth: 1.2)
                }
            }
        }
    }
}
