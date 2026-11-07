import Foundation
@preconcurrency import Matter
import MatterSupport

/// Koppel-extensie: iOS doet het koppelscherm (QR scannen, Bluetooth, wifi/Thread) en
/// geeft het apparaat daarna aan Homio. Hier wordt het in Homio's eigen Matter-netwerk gezet.
final class RequestHandler: MatterAddDeviceExtensionRequestHandler {
    private var lastNodeID: UInt64?

    override func validateDeviceCredential(_ deviceCredential: MatterAddDeviceExtensionRequestHandler.DeviceCredential) async throws {
        // Homio accepteert elk apparaat dat iOS heeft goedgekeurd.
    }

    override func selectWiFiNetwork(from wifiScanResults: [MatterAddDeviceExtensionRequestHandler.WiFiScanResult]) async throws -> MatterAddDeviceExtensionRequestHandler.WiFiNetworkAssociation {
        .defaultSystemNetwork
    }

    override func selectThreadNetwork(from threadScanResults: [MatterAddDeviceExtensionRequestHandler.ThreadScanResult]) async throws -> MatterAddDeviceExtensionRequestHandler.ThreadNetworkAssociation {
        .defaultSystemNetwork
    }

    override func commissionDevice(in home: MatterAddDeviceRequest.Home?, onboardingPayload: String, commissioningID: UUID) async throws {
        let controller = try MatterControllerFactory.shared(prefix: "ext")
        let commissioner = MatterCommissioner(controller: controller)
        let nodeID = try await commissioner.commission(code: onboardingPayload)
        let info = await MatterInspector.readInfo(nodeID: nodeID, controller: controller)
        let name = [info.nodeLabel, info.productName].first { !$0.isEmpty } ?? "Matter-apparaat"
        lastNodeID = nodeID
        update(nodeID) { _ in
            PendingMatterDevice(nodeID: nodeID, name: name, room: nil, info: info, certified: !commissioner.attestationFailed)
        }
    }

    override func rooms(in home: MatterAddDeviceRequest.Home?) async -> [MatterAddDeviceRequest.Room] {
        let names = MatterShared.defaults.stringArray(forKey: MatterShared.roomsKey) ?? []
        return names.map { MatterAddDeviceRequest.Room(displayName: $0) }
    }

    override func configureDevice(named name: String, in room: MatterAddDeviceRequest.Room?) async {
        guard let nodeID = lastNodeID else { return }
        update(nodeID) { existing in
            guard var device = existing else { return nil }
            if !name.trimmingCharacters(in: .whitespaces).isEmpty { device.name = name }
            device.room = room?.displayName
            return device
        }
    }

    /// Werk de lijst met nieuw gekoppelde apparaten in de App Group bij.
    private func update(_ nodeID: UInt64, _ change: (PendingMatterDevice?) -> PendingMatterDevice?) {
        let defaults = MatterShared.defaults
        var list = (defaults.data(forKey: MatterShared.pendingKey))
            .flatMap { try? JSONDecoder().decode([PendingMatterDevice].self, from: $0) } ?? []
        let index = list.firstIndex { $0.nodeID == nodeID }
        let updated = change(index.map { list[$0] })
        if let index { list.remove(at: index) }
        if let updated { list.append(updated) }
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: MatterShared.pendingKey)
        }
    }
}
