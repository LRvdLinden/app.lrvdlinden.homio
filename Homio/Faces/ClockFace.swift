import SwiftUI

/// Grote klok. Van ver alleen de tijd; dichtbij ook datum, weer en de volgende afspraak.
struct ClockFace: View {
    @EnvironmentObject private var proximity: ProximityMonitor
    @EnvironmentObject private var weather: WeatherService
    @EnvironmentObject private var calendar: CalendarService

    var body: some View {
        ZStack {
            AmbientBackground(intensity: 0.55)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let near = proximity.isNear
                VStack(spacing: near ? 14 : 0) {
                    Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                        .font(.system(size: near ? 170 : 250, weight: .thin, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)

                    if near {
                        Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                            .font(.title.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        HStack(spacing: 14) {
                            if let current = weather.current {
                                InfoChip(symbol: WeatherService.symbol(for: current.code, isDay: current.isDay),
                                         text: "\(Int(current.temperature.rounded()))° \(WeatherService.description(for: current.code))")
                            }
                            if let event = calendar.nextEvent {
                                InfoChip(symbol: "calendar", text: "\(event.timeText) · \(event.title ?? "")")
                            }
                        }
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .foregroundStyle(.white)
                .padding(40)
                .animation(.spring(response: 0.7, dampingFraction: 0.85), value: near)
            }
        }
        .onAppear {
            weather.start()
            calendar.start()
        }
    }
}

struct InfoChip: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text).lineLimit(1)
        } icon: {
            Image(systemName: symbol).symbolRenderingMode(.multicolor)
        }
        .font(.title3.weight(.medium))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassCard(corner: 22)
    }
}

/// Analoge klok, getekend met Canvas.
struct AnalogClockView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10.0)) { context in
            Canvas { gc, size in
                let r = min(size.width, size.height) / 2
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                gc.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                        with: .color(.white.opacity(0.05)))

                for i in 0..<60 {
                    let angle = Double(i) / 60 * 2 * .pi
                    let sx = CGFloat(sin(angle)), cy0 = CGFloat(cos(angle))
                    let major = i % 5 == 0
                    let outer = r * 0.92
                    let inner = major ? r * 0.78 : r * 0.86
                    var tick = Path()
                    tick.move(to: CGPoint(x: c.x + outer * sx, y: c.y - outer * cy0))
                    tick.addLine(to: CGPoint(x: c.x + inner * sx, y: c.y - inner * cy0))
                    gc.stroke(tick, with: .color(.white.opacity(major ? 0.9 : 0.3)),
                              style: StrokeStyle(lineWidth: major ? 3 : 1, lineCap: .round))
                }

                let parts = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: context.date)
                let seconds = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1_000_000_000
                let minutes = Double(parts.minute ?? 0) + seconds / 60
                let hours = Double((parts.hour ?? 0) % 12) + minutes / 60

                let hands: [(Double, CGFloat, CGFloat, Color)] = [
                    (hours / 12, r * 0.5, 7, .white),
                    (minutes / 60, r * 0.74, 5, .white),
                    (seconds / 60, r * 0.84, 2, Theme.amber)
                ]
                for (fraction, length, width, color) in hands {
                    let angle = fraction * 2 * .pi
                    var hand = Path()
                    hand.move(to: c)
                    hand.addLine(to: CGPoint(x: c.x + length * CGFloat(sin(angle)), y: c.y - length * CGFloat(cos(angle))))
                    gc.stroke(hand, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
                gc.fill(Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)),
                        with: .color(Theme.amber))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(Text(Date(), style: .time))
    }
}
