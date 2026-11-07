import Combine
import SwiftUI

enum AppPanel: String, Identifiable {
    case home, cameras, timers
    var id: String { rawValue }
}

/// Het hoofdscherm: faces om doorheen te vegen, met een dock dat verdwijnt als niemand iets doet.
struct MainView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var proximity: ProximityMonitor
    @EnvironmentObject private var auth: AuthStore

    @State private var selection: FaceKind = .clock
    @State private var panel: AppPanel?
    @State private var showChrome = true
    @State private var lastInteraction = Date()
    @State private var showProfiles = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let idleCheck = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(settings.enabledFaces) { face in
                    FaceView(kind: face, openPanel: openPanel)
                        .tag(face)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            NightDimOverlay()

            VStack {
                TopBar(showProfiles: $showProfiles)
                Spacer()
                PageDots(faces: settings.enabledFaces, selection: selection)
                Dock(openPanel: openPanel, close: { dismiss() })
            }
            .padding(.horizontal, sizeClass == .compact ? 14 : 28)
            .padding(.vertical, 18)
            .opacity(showChrome ? 1 : 0)
            .allowsHitTesting(showChrome)
            .animation(.easeInOut(duration: 0.4), value: showChrome)
        }
        .simultaneousGesture(TapGesture().onEnded { registerInteraction() })
        .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in registerInteraction() })
        .onReceive(idleCheck) { _ in
            if showChrome && Date().timeIntervalSince(lastInteraction) > 15 && panel == nil {
                showChrome = false
            }
        }
        .onChange(of: proximity.isNear) { _, near in
            if near { showChrome = true; lastInteraction = Date() }
        }
        .onChange(of: settings.enabledFaces) { _, faces in
            if !faces.contains(selection) { selection = faces.first ?? .clock }
        }
        .onAppear {
            settings.ensureProfile(named: auth.displayName)
            settings.applyKeepAwake()
            home.start()
            if settings.proximityEnabled { proximity.start() }
            if !settings.enabledFaces.contains(selection) { selection = settings.enabledFaces.first ?? .clock }
        }
        .fullScreenCover(item: $panel) { panel in
            switch panel {
            case .home: HomeControlView()
            case .cameras: CamerasView()
            case .timers: TimersView()
            }
        }
        .sheet(isPresented: $showProfiles) {
            ProfileSwitcher()
        }
    }

    private func openPanel(_ target: AppPanel) {
        registerInteraction()
        panel = target
    }

    private func registerInteraction() {
        lastInteraction = Date()
        proximity.registerTouch()
        if !showChrome { showChrome = true }
    }
}

/// Kiest de juiste face.
struct FaceView: View {
    let kind: FaceKind
    let openPanel: (AppPanel) -> Void

    var body: some View {
        switch kind {
        case .clock: ClockFace()
        case .home: HomeModularFace(openPanel: openPanel)
        case .cameras: CameraFace(openPanel: openPanel)
        case .photos: PhotosFace()
        case .weather: WeatherFace()
        case .calendar: CalendarFace()
        case .flow: FlowFace()
        case .dashboard: DashboardFace()
        }
    }
}

private struct TopBar: View {
    @Binding var showProfiles: Bool
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var timers: TimersStore

    var body: some View {
        HStack(spacing: 12) {
            Button { showProfiles = true } label: {
                if let profile = settings.activeProfile {
                    Text(profile.initial)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(profile.color))
                } else {
                    Image(systemName: "person.crop.circle.fill").font(.largeTitle)
                }
            }
            .accessibilityLabel("Profiel wisselen")

            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 10) {
                    ForEach(timers.timers) { timer in
                        TimerPill(timer: timer, now: context.date)
                    }
                }
            }
        }
    }
}

struct TimerPill: View {
    let timer: KitchenTimer
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().stroke(.white.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: timer.progress(at: now))
                    .stroke(Theme.amber, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)
            Text(TimersStore.format(timer.remaining(at: now)))
                .font(.subheadline.monospacedDigit().weight(.semibold))
            if timer.isPaused {
                Image(systemName: "pause.fill").font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassCard(corner: 18)
    }
}

private struct PageDots: View {
    let faces: [FaceKind]
    let selection: FaceKind

    var body: some View {
        HStack(spacing: 8) {
            ForEach(faces) { face in
                Capsule()
                    .fill(.white.opacity(face == selection ? 0.9 : 0.3))
                    .frame(width: face == selection ? 22 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection)
        .padding(.bottom, 10)
    }
}

private struct Dock: View {
    let openPanel: (AppPanel) -> Void
    let close: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        HStack(spacing: 6) {
            item("Woning", "house.fill", .home)
            item("Camera's", "video.fill", .cameras)
            item("Timers", "timer", .timers)
            Button(action: close) {
                VStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                    Text("Sluiten")
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .frame(width: sizeClass == .compact ? 74 : 96, height: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(8)
        .glassCard(corner: 30)
    }

    private func item(_ title: String, _ symbol: String, _ panel: AppPanel) -> some View {
        Button { openPanel(panel) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title2)
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(width: sizeClass == .compact ? 74 : 96, height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Dimt het scherm 's nachts (23–7 uur), minder als er iemand dichtbij is.
private struct NightDimOverlay: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var proximity: ProximityMonitor

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let hour = Calendar.current.component(.hour, from: context.date)
            let night = settings.nightDimming && (hour >= 23 || hour < 7)
            Color.black
                .opacity(night ? (proximity.isNear ? 0.3 : 0.72) : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 1.2), value: night)
        }
    }
}

struct ProfileSwitcher: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 30) {
            Text("Wie ben je?").font(.largeTitle.bold())
            ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 28) {
                ForEach(settings.profiles) { profile in
                    Button {
                        settings.activeProfileID = profile.id
                        dismiss()
                    } label: {
                        VStack(spacing: 10) {
                            Text(profile.initial)
                                .font(.system(size: 40, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(width: 96, height: 96)
                                .background(Circle().fill(profile.color))
                                .overlay(Circle().strokeBorder(.white,
                                                               lineWidth: profile.id == settings.activeProfile?.id ? 4 : 0))
                            Text(profile.name).font(.headline).foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 4)
            }
            Text("Profielen beheer je in Instellingen.")
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
    }
}
