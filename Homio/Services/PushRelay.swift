import CloudKit
import HomeKit
import SwiftUI
import UserNotifications

/// Pushmeldingen zonder eigen server.
///
/// Eén apparaat dat altijd aan staat (bijv. de iPad aan de muur) "verstuurt": het ziet in
/// HomeKit dat de voordeur opengaat en zet een kort bericht in je eigen iCloud.
/// Elk apparaat dat "ontvangt" heeft een iCloud-abonnement en krijgt daardoor een echte
/// pushmelding, ook als Homio daar dicht is. De Apple Watch toont ze via de iPhone.
@MainActor
final class PushRelay: ObservableObject {
    static let shared = PushRelay()

    static let containerID = "iCloud.nl.lrvdlinden.homio"
    private static let recordType = "HomioEvent"
    private static let subscriptionID = "homio-events"

    @Published var sendsFromThisDevice: Bool { didSet { save() } }
    @Published private(set) var receivesOnThisDevice: Bool { didSet { save() } }
    /// Apparaten (service-ID) waarvoor een melding komt.
    @Published var watched: Set<String> { didSet { save() } }
    @Published private(set) var busy = false
    @Published var problem: String?

    private var lastSent: [String: Date] = [:]
    private let defaults = UserDefaults.standard

    private var database: CKDatabase {
        CKContainer(identifier: Self.containerID).privateCloudDatabase
    }

    private init() {
        sendsFromThisDevice = defaults.bool(forKey: "homio.push.sends")
        receivesOnThisDevice = defaults.bool(forKey: "homio.push.receives")
        if let list = defaults.stringArray(forKey: "homio.push.watched") {
            watched = Set(list)
        } else {
            watched = []
            defaults.set(true, forKey: "homio.push.needsDefaults")
        }
        CloudSync.shared.register("notify", apply: { [weak self] data in
            guard let self, let list = try? JSONDecoder().decode([String].self, from: data) else { return }
            self.applyingRemote = true
            self.defaults.set(false, forKey: "homio.push.needsDefaults")
            self.watched = Set(list)
            self.applyingRemote = false
        }, current: { [weak self] in
            guard let self else { return nil }
            return try? JSONEncoder().encode(Array(self.watched).sorted())
        })
    }

    private var applyingRemote = false
    private var lastWatched: Set<String> = []

    private func save() {
        defaults.set(sendsFromThisDevice, forKey: "homio.push.sends")
        defaults.set(receivesOnThisDevice, forKey: "homio.push.receives")
        defaults.set(Array(watched), forKey: "homio.push.watched")
        if !applyingRemote, watched != lastWatched, let data = try? JSONEncoder().encode(Array(watched).sorted()) {
            CloudSync.shared.push("notify", payload: data)
        }
        lastWatched = watched
    }

    /// Standaard: deuren, ramen, sloten, garagedeuren en alarmsensoren aan; beweging uit.
    func applyDefaultsIfNeeded(_ devices: [Device]) {
        guard defaults.bool(forKey: "homio.push.needsDefaults"), !devices.isEmpty else { return }
        defaults.set(false, forKey: "homio.push.needsDefaults")
        watched = Set(devices.filter { [.contact, .lock, .garage].contains($0.kind) || $0.kind.isAlarm }.map { $0.id.uuidString })
    }

    nonisolated static func canNotify(_ device: Device) -> Bool {
        [.contact, .lock, .garage, .motion, .occupancy, .door, .window, .security].contains(device.kind) || device.kind.isAlarm
    }

    func isWatched(_ device: Device) -> Bool { watched.contains(device.id.uuidString) }

    func setWatched(_ device: Device, _ on: Bool) {
        if on { watched.insert(device.id.uuidString) } else { watched.remove(device.id.uuidString) }
    }

    // MARK: Toestemming

    @discardableResult
    func requestPermission() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return granted
    }

    // MARK: Ontvangen

    func setReceives(_ on: Bool) async {
        busy = true
        defer { busy = false }
        problem = nil
        do {
            if on {
                guard await requestPermission() else {
                    problem = "Sta meldingen voor Homio toe in Instellingen › Meldingen."
                    return
                }
                try await subscribe()
            } else {
                _ = try? await database.deleteSubscription(withID: Self.subscriptionID)
            }
            receivesOnThisDevice = on
        } catch {
            problem = friendly(error)
        }
    }

    private func subscribe() async throws {
        let subscription = CKQuerySubscription(recordType: Self.recordType,
                                               predicate: NSPredicate(value: true),
                                               subscriptionID: Self.subscriptionID,
                                               options: [.firesOnRecordCreation])
        let info = CKSubscription.NotificationInfo()
        info.titleLocalizationKey = "%1$@"
        info.titleLocalizationArgs = ["title"]
        info.alertLocalizationKey = "%1$@"
        info.alertLocalizationArgs = ["body"]
        info.soundName = "default"
        subscription.notificationInfo = info
        do {
            _ = try await database.save(subscription)
        } catch {
            // In de ontwikkelomgeving bestaat het recordtype pas na de eerste keer opslaan.
            let seed = CKRecord(recordType: Self.recordType)
            seed["title"] = "Homio" as CKRecordValue
            seed["body"] = "Meldingen staan aan" as CKRecordValue
            let saved = try await database.save(seed)
            _ = try? await database.deleteRecord(withID: saved.recordID)
            _ = try await database.save(subscription)
        }
    }

    // MARK: Versturen

    /// Wordt aangeroepen bij elke gebeurtenis in de tijdlijn.
    func handle(serviceID: UUID, title: String, detail: String, room: String) {
        guard sendsFromThisDevice, watched.contains(serviceID.uuidString) else { return }
        let key = "\(serviceID.uuidString)|\(detail)"
        if let last = lastSent[key], Date().timeIntervalSince(last) < 60 { return }
        lastSent[key] = Date()
        let body = room.isEmpty ? detail : "\(detail) · \(room)"
        Task { await send(title: title, body: body) }
    }

    func sendTest() async {
        busy = true
        defer { busy = false }
        await send(title: "Homio", body: "Testmelding: pushmeldingen werken.")
    }

    private func send(title: String, body: String) async {
        let record = CKRecord(recordType: Self.recordType)
        record["title"] = title as CKRecordValue
        record["body"] = body as CKRecordValue
        record["date"] = Date() as CKRecordValue
        do {
            _ = try await database.save(record)
            problem = nil
        } catch {
            problem = friendly(error)
            await localFallback(title: title, body: body)
        }
    }

    /// Als iCloud niet werkt, dan in elk geval een melding op dit apparaat.
    private func localFallback(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func friendly(_ error: Error) -> String {
        if let ck = error as? CKError {
            switch ck.code {
            case .notAuthenticated: return "Log in met iCloud in Instellingen om meldingen te gebruiken."
            case .networkUnavailable, .networkFailure: return "Geen internetverbinding."
            case .quotaExceeded: return "Je iCloud-opslag is vol."
            default: break
            }
        }
        return error.localizedDescription
    }
}

/// Laat meldingen ook zien als Homio open is.
final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

/// Instellingen voor meldingen.
struct NotificationSettingsView: View {
    @EnvironmentObject private var relay: PushRelay
    @EnvironmentObject private var home: HomeStore

    private var candidates: [Device] { home.devices.filter(PushRelay.canNotify) }

    var body: some View {
        Form {
            Section {
                Toggle("Meldingen op dit apparaat", isOn: Binding(
                    get: { relay.receivesOnThisDevice },
                    set: { on in Task { await relay.setReceives(on) } }
                ))
                .disabled(relay.busy)
            } footer: {
                Text("Je krijgt een pushmelding, ook als Homio dicht is. Op de Apple Watch verschijnen ze via je iPhone.")
            }

            Section {
                Toggle("Dit apparaat verstuurt meldingen", isOn: $relay.sendsFromThisDevice)
            } footer: {
                Text("Zet dit aan op één apparaat dat altijd aan staat en Homio open heeft, zoals een iPad aan de muur. Dat apparaat ziet wat er gebeurt en stuurt het via je eigen iCloud door. Er is geen andere server nodig.")
            }

            Section("Waarover") {
                if candidates.isEmpty {
                    Text("Geen deuren, ramen, sloten of bewegingssensoren gevonden.")
                        .foregroundStyle(.secondary)
                }
                ForEach(candidates) { device in
                    Toggle(isOn: Binding(
                        get: { relay.isWatched(device) },
                        set: { relay.setWatched(device, $0) }
                    )) {
                        Label {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                Text(device.roomName).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            DeviceIcon(device: device, size: 22)
                        }
                    }
                }
            }

            Section {
                Button {
                    Task { await relay.sendTest() }
                } label: {
                    Label("Testmelding sturen", systemImage: "bell.badge")
                }
                .disabled(relay.busy)
                if let problem = relay.problem {
                    Text(problem).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Meldingen")
        .onAppear { relay.applyDefaultsIfNeeded(home.devices) }
    }
}
