import SwiftUI

struct TimersView: View {
    @EnvironmentObject private var timers: TimersStore
    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var hours = 0
    @State private var minutes = 10

    private let presets: [Int] = [1, 3, 5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground(intensity: 0.4)
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        if !timers.timers.isEmpty {
                            SectionTitle("Lopend")
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .compact ? 280 : 220), spacing: 16)], spacing: 16) {
                                    ForEach(timers.timers) { timer in
                                        RunningTimerCard(timer: timer, now: context.date)
                                    }
                                }
                            }
                        }

                        SectionTitle("Snel starten")
                        TextField("Naam (bijv. Pasta)", text: $label)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .glassCard()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                            ForEach(presets, id: \.self) { m in
                                Button {
                                    timers.add(seconds: TimeInterval(m * 60), label: label)
                                    label = ""
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("\(m)").font(.system(size: 34, weight: .semibold, design: .rounded))
                                        Text("min").font(.subheadline).foregroundStyle(Color.primary.opacity(0.6))
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 90)
                                    .glassCard()
                                }
                                .buttonStyle(PressableStyle())
                                .foregroundStyle(.primary)
                            }
                        }

                        SectionTitle("Eigen tijd")
                        AdaptiveStack(spacing: 20) {
                            HStack(spacing: 12) {
                            Picker("Uren", selection: $hours) {
                                ForEach(0..<13, id: \.self) { Text("\($0) u").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: sizeClass == .compact ? 120 : 140, height: 140)
                            .clipped()
                            Picker("Minuten", selection: $minutes) {
                                ForEach(0..<60, id: \.self) { Text("\($0) min").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: sizeClass == .compact ? 150 : 160, height: 140)
                            .clipped()
                            }
                            Button {
                                timers.add(seconds: TimeInterval(hours * 3600 + minutes * 60), label: label)
                                label = ""
                            } label: {
                                Label("Start", systemImage: "play.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 26).padding(.vertical, 16)
                                    .background(Capsule().fill(Theme.amber))
                                    .foregroundStyle(.black)
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(hours == 0 && minutes == 0)
                        }
                        .padding(16)
                        .glassCard()
                    }
                    .padding(sizeClass == .compact ? 16 : 28)
                }
            }
            .foregroundStyle(.primary)
            .navigationTitle("Timers")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sluiten") { dismiss() }
                }
            }
        }
    }
}

private struct RunningTimerCard: View {
    let timer: KitchenTimer
    let now: Date
    @EnvironmentObject private var timers: TimersStore

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: timer.progress(at: now))
                    .stroke(Theme.warmGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.progress(at: now))
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 4) {
                Text(timer.label).font(.headline).lineLimit(1)
                Text(TimersStore.format(timer.remaining(at: now)))
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(spacing: 10) {
                Button { timers.togglePause(timer) } label: {
                    Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.primary.opacity(0.15)))
                }
                .accessibilityLabel(timer.isPaused ? "Hervatten" : "Pauzeren")
                Button(role: .destructive) { timers.remove(timer) } label: {
                    Image(systemName: "xmark")
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.primary.opacity(0.15)))
                }
                .accessibilityLabel("Verwijderen")
            }
            .foregroundStyle(.primary)
        }
        .padding(16)
        .glassCard()
    }
}

/// Volledig scherm als een timer afloopt.
struct TimerAlarmView: View {
    let timer: KitchenTimer
    @EnvironmentObject private var timers: TimersStore
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Theme.amber.opacity(0.25))
                        .frame(width: 220, height: 220)
                        .scaleEffect(pulse ? 1.25 : 0.9)
                    Image(systemName: "timer")
                        .font(.system(size: 90, weight: .medium))
                        .foregroundStyle(Theme.amber)
                        .symbolEffect(.bounce, options: .repeating, value: pulse)
                }
                Text("Timer afgelopen").font(.largeTitle.bold())
                Text(timer.label).font(.title2).foregroundStyle(Color.primary.opacity(0.7))
                Button {
                    timers.stopRinging()
                } label: {
                    Text("Stop")
                        .font(.title2.weight(.semibold))
                        .frame(width: 260, height: 70)
                        .background(Capsule().fill(Theme.amber))
                        .foregroundStyle(.black)
                }
                .buttonStyle(PressableStyle())
            }
            .foregroundStyle(.primary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
