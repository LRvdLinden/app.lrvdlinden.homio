import AppIntents

/// "Hé Siri, start een scène in Homio" en in de app Opdrachten.
struct RunSceneIntent: AppIntent {
    static var title: LocalizedStringResource = "Scène starten"
    static var description = IntentDescription("Start een scène uit je woning.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Scène")
    var sceneName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ok = await HomeStore.shared.runScene(named: sceneName)
        if ok {
            return .result(dialog: "Scène \(sceneName) is gestart.")
        }
        return .result(dialog: "Ik kan geen scène \(sceneName) vinden.")
    }
}

// MARK: Apparaten als keuze in Siri en Opdrachten

struct DeviceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Apparaat"
    static var defaultQuery = DeviceQuery()

    let id: UUID
    let name: String
    let room: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(room)")
    }
}

struct DeviceQuery: EntityStringQuery {
    @MainActor
    private func all() async -> [DeviceEntity] {
        await HomeStore.shared.waitUntilReady()
        return HomeStore.shared.devices
            .filter(\.isToggleable)
            .map { DeviceEntity(id: $0.id, name: $0.name, room: $0.roomName) }
    }

    func entities(for identifiers: [UUID]) async throws -> [DeviceEntity] {
        let list = await all()
        return list.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [DeviceEntity] {
        let list = await all()
        return list.filter {
            $0.name.localizedCaseInsensitiveContains(string) || $0.room.localizedCaseInsensitiveContains(string)
        }
    }

    func suggestedEntities() async throws -> [DeviceEntity] {
        await all()
    }
}

/// "Hé Siri, zet de woonkamerlamp aan met Homio."
struct SetDeviceIntent: AppIntent {
    static var title: LocalizedStringResource = "Apparaat aan- of uitzetten"
    static var description = IntentDescription("Zet een lamp, stekker, slot of ander apparaat aan of uit.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Apparaat")
    var device: DeviceEntity

    @Parameter(title: "Aan", default: true)
    var on: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Zet \(\.$device) aan: \(\.$on)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await HomeStore.shared.waitUntilReady()
        guard let found = HomeStore.shared.device(id: device.id) else {
            return .result(dialog: "Ik kan \(device.name) niet vinden.")
        }
        HomeStore.shared.set(found, on: on)
        if on {
            return .result(dialog: "\(found.name) staat aan.")
        }
        return .result(dialog: "\(found.name) staat uit.")
    }
}

/// "Hé Siri, alle lampen uit met Homio."
struct AllLightsOffIntent: AppIntent {
    static var title: LocalizedStringResource = "Alle lampen uit"
    static var description = IntentDescription("Zet alle lampen in huis uit.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await HomeStore.shared.waitUntilReady()
        HomeStore.shared.setLights(on: false, room: nil)
        return .result(dialog: "Alle lampen gaan uit.")
    }
}

struct HomioShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SetDeviceIntent(),
            phrases: [
                "Bedien \(\.$device) met \(.applicationName)",
                "Zet \(\.$device) aan met \(.applicationName)"
            ],
            shortTitle: "Apparaat bedienen",
            systemImageName: "power"
        )
        AppShortcut(
            intent: AllLightsOffIntent(),
            phrases: [
                "Alle lampen uit met \(.applicationName)",
                "Zet alle lampen uit in \(.applicationName)"
            ],
            shortTitle: "Alle lampen uit",
            systemImageName: "lightbulb.slash"
        )
        AppShortcut(
            intent: RunSceneIntent(),
            phrases: [
                "Start een scène in \(.applicationName)",
                "Scène in \(.applicationName)"
            ],
            shortTitle: "Scène starten",
            systemImageName: "sparkles"
        )
    }
}
