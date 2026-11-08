import PhotosUI
import SwiftUI

struct SettingsView: View {
    var showsDone = true
    var startDisplay: (() -> Void)? = nil

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var home: HomeStore
    @EnvironmentObject private var photos: PhotoLibraryStore
    @EnvironmentObject private var proximity: ProximityMonitor
    @Environment(\.dismiss) private var dismiss

    @State private var newProfileName = ""
    @State private var showAddProfile = false
    @State private var picks: [PhotosPickerItem] = []
    @State private var confirmSignOut = false
    @State private var showTimers = false
    @State private var showCameras = false
    @State private var showWhatsNew = false
    @AppStorage("appearance") private var appearance: AppearanceSetting = .system
    @AppStorage("onboarding.done") private var onboardingDone = true

    var body: some View {
        NavigationStack {
            Form {
                // Profiel en woning bovenaan, zoals in de Homey-app.
                Section {
                    if let profile = settings.activeProfile {
                        NavigationLink {
                            ProfileEditView(profileID: profile.id)
                        } label: {
                            HStack(spacing: 14) {
                                ProfileAvatar(profile: profile, size: 52)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                    Text(auth.displayName.isEmpty ? "Naam en foto wijzigen" : "Ingelogd met Apple · \(auth.displayName)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textLight)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    HStack(spacing: 14) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(Theme.text))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(home.home?.name ?? "Thuis")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text("\(home.devices.count) apparaten · \(home.rooms.count) kamers")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textLight)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Zoals Homey's Meer: inzichten, alarmen (timers), batterijen en gebruikers bovenaan.
                Section {
                    NavigationLink {
                        InsightsTab(embedded: true)
                    } label: {
                        SettingsRowLabel("Inzichten", symbol: "chart.xyaxis.line", color: Theme.green)
                    }
                    NavigationLink {
                        HealthView()
                    } label: {
                        SettingsRowLabel("Batterijen", symbol: "battery.75percent", color: Color(red: 0x2D / 255, green: 0xC1 / 255, blue: 0x26 / 255))
                    }
                }

                Section {
                    if let startDisplay {
                        Button(action: startDisplay) {
                            SettingsRowLabel("Start weergavemodus", symbol: "play.rectangle.fill", color: Theme.accent)
                        }
                    }
                    Toggle("Starten in weergavemodus", isOn: $settings.startInDisplayMode)
                    Button { showTimers = true } label: {
                        SettingsRowLabel("Timers", symbol: "timer", color: Theme.orange)
                    }
                    Button { showCameras = true } label: {
                        SettingsRowLabel("Camera's", symbol: "video.fill", color: Color(red: 0.2, green: 0.2, blue: 0.25))
                    }
                } header: {
                    Text("Weergavemodus")
                } footer: {
                    Text("De weergavemodus maakt van je iPad een bedienpaneel aan de muur, met klok, foto's, camera's en je dashboard.")
                }

                Section("Profielen") {
                    ForEach(settings.profiles) { profile in
                        Button {
                            settings.activeProfileID = profile.id
                        } label: {
                            HStack(spacing: 14) {
                                ProfileAvatar(profile: profile, size: 36)
                                Text(profile.name).foregroundStyle(.primary)
                                Spacer()
                                if profile.id == settings.activeProfile?.id {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.amber)
                                }
                            }
                        }
                    }
                    .onDelete { settings.removeProfiles(at: $0) }
                    Button {
                        showAddProfile = true
                    } label: {
                        SettingsRowLabel("Profiel toevoegen", symbol: "person.badge.plus", color: Color(red: 0x9C / 255, green: 0x47 / 255, blue: 0xFC / 255))
                    }
                }

                Section {
                    NavigationLink {
                        FacesSettingsView()
                    } label: {
                        SettingsRowLabel("Faces kiezen en ordenen", symbol: "rectangle.stack", color: Theme.purple)
                    }
                } header: {
                    Text("Faces")
                }

                Section {
                    Toggle("Scherm altijd aan", isOn: $settings.keepAwake)
                    Toggle("'s Nachts dimmen (23–7 uur)", isOn: $settings.nightDimming)
                    Toggle("Nabijheid via camera", isOn: Binding(
                        get: { settings.proximityEnabled },
                        set: { on in
                            settings.proximityEnabled = on
                            if on { proximity.start() } else { proximity.stop() }
                        }
                    ))
                } header: {
                    Text("Scherm")
                } footer: {
                    Text("Met nabijheid toont Homio meer details als je dichterbij komt. De frontcamera kijkt alleen óf er een gezicht is; er wordt niets bewaard of verstuurd.")
                }

                Section {
                    LabeledContent("Foto's in fotolijst", value: "\(photos.urls.count)")
                    PhotosPicker(selection: $picks, maxSelectionCount: 50, matching: .images) {
                        SettingsRowLabel("Foto's toevoegen", symbol: "photo.badge.plus", color: Color(red: 0xF0 / 255, green: 0x16 / 255, blue: 0x85 / 255))
                    }
                    if !photos.urls.isEmpty {
                        Button("Alle foto's verwijderen", role: .destructive) { photos.removeAll() }
                    }
                } header: {
                    Text("Fotolijst")
                }

                Section {
                    NavigationLink {
                        CloudSyncSettingsView()
                    } label: {
                        SettingsRowLabel("iCloud-synchronisatie", symbol: "icloud.fill", color: Color(red: 0x2F / 255, green: 0x8A / 255, blue: 0xF7 / 255))
                    }
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRowLabel("Meldingen", symbol: "bell.badge.fill", color: Color(red: 0xE0 / 255, green: 0xA8 / 255, blue: 0x00 / 255))
                    }
                } header: {
                    Text("Meldingen")
                }

                Section {
                    NavigationLink {
                        MatterSettingsView()
                    } label: {
                        SettingsRowLabel("Matter", symbol: "dot.radiowaves.left.and.right", color: Color(red: 0x1D / 255, green: 0x91 / 255, blue: 0x91 / 255))
                    }
                } footer: {
                    Text("Eigen Matter-netwerk naast Apple Woning, voor apparaten uit Google, Alexa, SmartThings of Homey.")
                }

                Section("Woning") {
                    if home.homes.count > 1 {
                        Picker("Woning", selection: Binding(
                            get: { home.home?.uniqueIdentifier },
                            set: { home.selectedHomeID = $0 }
                        )) {
                            ForEach(home.homes, id: \.uniqueIdentifier) { h in
                                Text(h.name).tag(Optional(h.uniqueIdentifier))
                            }
                        }
                    } else {
                        LabeledContent("Woning", value: home.home?.name ?? "–")
                    }
                    Button {
                        home.addAccessory()
                    } label: {
                        SettingsRowLabel("HomeKit- of Matter-apparaat toevoegen", symbol: "plus.circle", color: Theme.green)
                    }
                    NavigationLink {
                        RoomsManageView()
                    } label: {
                        SettingsRowLabel("Kamers", symbol: "square.split.bottomrightquarter", color: Color(red: 0x32 / 255, green: 0x33 / 255, blue: 0x34 / 255))
                    }
                    NavigationLink {
                        HealthView()
                    } label: {
                        SettingsRowLabel("Huiscontrole", symbol: "stethoscope", color: Theme.red)
                    }
                }

                Section("Account") {
                    LabeledContent("Ingelogd met Apple", value: auth.displayName.isEmpty ? "Ja" : auth.displayName)
                    Button("Afmelden", role: .destructive) { confirmSignOut = true }
                }

                Section {
                    Picker(selection: $appearance) {
                        ForEach(AppearanceSetting.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    } label: {
                        SettingsRowLabel("Thema", symbol: "circle.lefthalf.filled", color: Color(red: 0x75 / 255, green: 0x80 / 255, blue: 0xA6 / 255))
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Weergave")
                } footer: {
                    Text("De weergavemodus, het welkomstscherm en de wekker blijven altijd donker.")
                }

                Section {
                    Button { showWhatsNew = true } label: {
                        SettingsRowLabel("Wat is nieuw", symbol: "sparkles", color: Theme.yellow)
                    }
                    Button { onboardingDone = false } label: {
                        SettingsRowLabel("Toon het welkomstscherm", symbol: "hand.wave", color: Theme.orange)
                    }
                } header: {
                    Text("Over")
                } footer: {
                    Text("Weergegevens: Open-Meteo.com (CC BY 4.0). Merk-iconen: custom-brand-icons door elax46 (MIT).")
                }

                Section {
                    MoreAppsCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text(verbatim: MoreAppsText.current.section)
                }

                Section {
                    AppInfoFooter()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Meer")
            .sheet(isPresented: $showTimers) { TimersView() }
            .sheet(isPresented: $showCameras) { CamerasView() }
            .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
            .toolbar {
                if showsDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Gereed") { dismiss() }
                    }
                }
            }
            .alert("Nieuw profiel", isPresented: $showAddProfile) {
                TextField("Naam", text: $newProfileName)
                Button("Annuleer", role: .cancel) { newProfileName = "" }
                Button("Voeg toe") {
                    settings.addProfile(named: newProfileName)
                    newProfileName = ""
                }
            }
            .confirmationDialog("Afmelden?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Afmelden", role: .destructive) {
                    dismiss()
                    auth.signOut()
                }
            } message: {
                Text("Je profielen en instellingen blijven op dit apparaat bewaard.")
            }
            .onChange(of: picks) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    await photos.add(items)
                    picks = []
                }
            }
        }
    }
}

private struct FacesSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        List {
            Section {
                ForEach($settings.faces) { $face in
                    Toggle(isOn: $face.enabled) {
                        Label(face.kind.title, systemImage: face.kind.symbol)
                    }
                }
                .onMove { settings.faces.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Sleep om de volgorde te veranderen. Veeg op het hoofdscherm naar links of rechts om te wisselen.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Faces")
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// Rij-label zoals in Homey's Meer-scherm: wit icoon op een gekleurd afgerond vlak.
struct SettingsRowLabel: View {
    let title: LocalizedStringKey
    let symbol: String
    let color: Color

    init(_ title: LocalizedStringKey, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Label {
            Text(title).foregroundStyle(Theme.text)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color))
        }
    }
}
