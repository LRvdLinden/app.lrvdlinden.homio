import SwiftUI

/// Synchroniseert de Homio-extra's (dashboards, groepen, profielen, flows, timers …) via
/// iCloud-sleutelopslag tussen je iPhone, iPad en Mac. De nieuwste wijziging wint.
/// HomeKit-zaken (apparaten, kamers, sferen, automatiseringen) synct Apple zelf al.
@MainActor
final class CloudSync: ObservableObject {
    static let shared = CloudSync()

    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "homio.cloud.enabled")
            if enabled { syncNow() }
        }
    }
    @Published private(set) var lastSync: Date?
    @Published private(set) var lastChangeFrom: String?

    var iCloudAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    private struct Envelope: Codable {
        let updatedAt: Date
        let device: String
        let payload: Data
    }

    private let kvs = NSUbiquitousKeyValueStore.default
    private var handlers: [String: @MainActor (Data) -> Void] = [:]
    private var pushers: [String: @MainActor () -> Data?] = [:]
    private let deviceName = UIDevice.current.name

    private init() {
        enabled = UserDefaults.standard.object(forKey: "homio.cloud.enabled") as? Bool ?? true
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: kvs, queue: .main) { [weak self] note in
            let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
            Task { @MainActor in self?.receive(keys) }
        }
        kvs.synchronize()
    }

    private func stampKey(_ key: String) -> String { "homio.cloud.stamp.\(key)" }

    private func localStamp(_ key: String) -> Date {
        UserDefaults.standard.object(forKey: stampKey(key)) as? Date ?? .distantPast
    }

    /// Een store meldt zich aan: `apply` krijgt nieuwere gegevens van een ander apparaat,
    /// `current` levert de eigen gegevens om te uploaden.
    func register(_ key: String, apply: @escaping @MainActor (Data) -> Void, current: @escaping @MainActor () -> Data?) {
        handlers[key] = apply
        pushers[key] = current
        receive([key])
    }

    /// Na elke lokale wijziging.
    func push(_ key: String, payload: Data) {
        let now = Date()
        UserDefaults.standard.set(now, forKey: stampKey(key))
        guard enabled else { return }
        let envelope = Envelope(updatedAt: now, device: deviceName, payload: payload)
        if let data = try? JSONEncoder().encode(envelope) {
            kvs.set(data, forKey: key)
            lastSync = now
        }
    }

    /// Haalt nieuwere gegevens op en zet eigen nieuwere gegevens terug.
    func syncNow() {
        kvs.synchronize()
        receive(Array(handlers.keys))
        guard enabled else { return }
        for (key, current) in pushers {
            let remote = envelope(for: key)
            if remote == nil || remote!.updatedAt < localStamp(key), let payload = current() {
                let stamp = localStamp(key) == .distantPast ? Date() : localStamp(key)
                let envelope = Envelope(updatedAt: stamp, device: deviceName, payload: payload)
                if let data = try? JSONEncoder().encode(envelope) { kvs.set(data, forKey: key) }
            }
        }
        lastSync = Date()
    }

    private func envelope(for key: String) -> Envelope? {
        guard let data = kvs.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Envelope.self, from: data)
    }

    private func receive(_ keys: [String]) {
        guard enabled else { return }
        for key in keys {
            guard let handler = handlers[key], let remote = envelope(for: key) else { continue }
            guard remote.updatedAt > localStamp(key) else { continue }
            UserDefaults.standard.set(remote.updatedAt, forKey: stampKey(key))
            handler(remote.payload)
            lastSync = Date()
            lastChangeFrom = remote.device
        }
    }
}

/// Instellingen voor iCloud-synchronisatie.
struct CloudSyncSettingsView: View {
    @EnvironmentObject private var cloud: CloudSync

    var body: some View {
        Form {
            Section {
                Toggle("Synchroniseer via iCloud", isOn: $cloud.enabled)
                if !cloud.iCloudAvailable {
                    Label("Log in met iCloud in Instellingen om te synchroniseren.", systemImage: "exclamationmark.icloud")
                        .foregroundStyle(.orange)
                }
                if let last = cloud.lastSync {
                    LabeledContent("Laatst", value: last.formatted(.relative(presentation: .named)))
                }
                if let from = cloud.lastChangeFrom {
                    LabeledContent("Laatste wijziging van", value: from)
                }
                Button {
                    cloud.syncNow()
                } label: {
                    Label("Nu synchroniseren", systemImage: "arrow.triangle.2.circlepath.icloud")
                }
                .disabled(!cloud.enabled)
            } footer: {
                Text("Dashboards, groepen, profielen, favorieten, faces, timers, het bewerken van flows en je keuze waarover je meldingen krijgt, zijn gelijk op al je apparaten met hetzelfde Apple-account. Apparaten, kamers, sferen en automatiseringen synct Apple Woning zelf al.")
            }
            Section {
                Label("Per apparaat blijven: de stand van de weergavemodus, nachtdimmen, scherm aan, nabijheid, of dit apparaat meldingen verstuurt of ontvangt, de fotolijst en de metingen in Inzichten.", systemImage: "iphone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("iCloud")
    }
}
