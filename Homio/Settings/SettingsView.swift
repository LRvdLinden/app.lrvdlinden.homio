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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let startDisplay {
                        Button(action: startDisplay) {
                            Label("Start weergavemodus", systemImage: "play.rectangle.fill")
                        }
                    }
                    Toggle("Starten in weergavemodus", isOn: $settings.startInDisplayMode)
                    Button { showTimers = true } label: {
                        Label("Timers", systemImage: "timer")
                    }
                    Button { showCameras = true } label: {
                        Label("Camera's", systemImage: "video.fill")
                    }
                } header: {
                    Text("Weergave")
                } footer: {
                    Text("De weergavemodus maakt van je iPad een bedienpaneel aan de muur, met klok, foto's, camera's en je dashboard.")
                }

                Section("Profielen") {
                    ForEach(settings.profiles) { profile in
                        Button {
                            settings.activeProfileID = profile.id
                        } label: {
                            HStack(spacing: 14) {
                                Text(profile.initial)
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(profile.color))
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
                        Label("Profiel toevoegen", systemImage: "person.badge.plus")
                    }
                }

                Section {
                    NavigationLink {
                        FacesSettingsView()
                    } label: {
                        Label("Faces kiezen en ordenen", systemImage: "rectangle.stack")
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
                        Label("Foto's toevoegen", systemImage: "photo.badge.plus")
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
                        Label("iCloud-synchronisatie", systemImage: "icloud.fill")
                    }
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Meldingen", systemImage: "bell.badge.fill")
                    }
                } header: {
                    Text("Meldingen")
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
                        Label("HomeKit- of Matter-apparaat toevoegen", systemImage: "plus.circle")
                    }
                    NavigationLink {
                        RoomsManageView()
                    } label: {
                        Label("Kamers", systemImage: "square.split.bottomrightquarter")
                    }
                    NavigationLink {
                        HealthView()
                    } label: {
                        Label("Huiscontrole", systemImage: "stethoscope")
                    }
                }

                Section("Account") {
                    LabeledContent("Ingelogd met Apple", value: auth.displayName.isEmpty ? "Ja" : auth.displayName)
                    Button("Afmelden", role: .destructive) { confirmSignOut = true }
                }

                Section("Over") {
                    LabeledContent("Versie", value: Bundle.main.appVersion)
                    Text("Weergegevens: Open-Meteo.com (CC BY 4.0)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    MoreAppsCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text(verbatim: MoreAppsText.current.section)
                }
            }
            .navigationTitle("Meer")
            .sheet(isPresented: $showTimers) { TimersView() }
            .sheet(isPresented: $showCameras) { CamerasView() }
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
