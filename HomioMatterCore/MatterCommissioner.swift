import Foundation
@preconcurrency import Matter

/// Waarden in het Matter "data-value"-formaat ([type: …, value: …]).
enum MatterValue {
    static func bool(_ v: Bool) -> [String: Any] { [MTRTypeKey: MTRBooleanValueType, MTRValueKey: v] }
    static func uint(_ v: UInt64) -> [String: Any] { [MTRTypeKey: MTRUnsignedIntegerValueType, MTRValueKey: NSNumber(value: v)] }
    static func int(_ v: Int64) -> [String: Any] { [MTRTypeKey: MTRSignedIntegerValueType, MTRValueKey: NSNumber(value: v)] }
    static var null: [String: Any] { [MTRTypeKey: MTRNullValueType] }

    /// Structuur met velden op volgorde van context-tag.
    static func structure(_ fields: [(UInt64, [String: Any])] = []) -> [String: Any] {
        [MTRTypeKey: MTRStructureValueType,
         MTRValueKey: fields.map { [MTRContextTagKey: NSNumber(value: $0.0), MTRDataKey: $0.1] }]
    }

    /// Zet een data-value om naar een gewone Swift-waarde (NSNumber, String, Data, [Any], [UInt64: Any] of nil).
    static func decode(_ dv: Any?) -> Any? {
        guard let dv = dv as? [String: Any], let type = dv[MTRTypeKey] as? String else { return nil }
        switch type {
        case MTRNullValueType:
            return nil
        case MTRArrayValueType:
            let items = dv[MTRValueKey] as? [[String: Any]] ?? []
            return items.compactMap { decode($0[MTRDataKey]) }
        case MTRStructureValueType:
            let fields = dv[MTRValueKey] as? [[String: Any]] ?? []
            var out: [UInt64: Any] = [:]
            for f in fields {
                if let tag = (f[MTRContextTagKey] as? NSNumber)?.uint64Value, let v = decode(f[MTRDataKey]) {
                    out[tag] = v
                }
            }
            return out
        default:
            return dv[MTRValueKey]
        }
    }
}

/// Basisgegevens van een gekoppeld apparaat (uit BasicInformation en Descriptor).
struct MatterNodeInfo: Codable, Hashable {
    var vendorName = ""
    var productName = ""
    var nodeLabel = ""
    var serialNumber = ""
    var uniqueID = ""
    var vendorID: UInt32 = 0
    var productID: UInt32 = 0
    /// Eindpunt → device types.
    var endpoints: [UInt16: [UInt32]] = [:]
    /// Eindpunt → naam uit BridgedDeviceBasicInformation (bij bridges).
    var endpointLabels: [UInt16: String] = [:]
}

/// Koppelt een apparaat aan Homio's fabric met een koppelcode (QR "MT:…" of 11/21 cijfers).
/// Wordt gebruikt in de app (koppelcode van een andere app) en in de extensie
/// (na het koppelscherm van Apple).
final class MatterCommissioner: NSObject, MTRDeviceControllerDelegate, MTRDeviceAttestationDelegate {
    private let controller: MTRDeviceController
    private let queue = DispatchQueue(label: "nl.lrvdlinden.homio.matter.commission")
    private var nodeID: UInt64 = 0
    private var continuation: CheckedContinuation<UInt64, Error>?
    private(set) var attestationFailed = false

    init(controller: MTRDeviceController) {
        self.controller = controller
    }

    static func parse(_ code: String) throws -> MTRSetupPayload {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        if #available(iOS 17.6, macCatalyst 17.6, *) {
            guard let payload = MTRSetupPayload(payload: trimmed) else { throw MatterControllerError.invalidCode }
            return payload
        } else {
            do { return try MTRSetupPayload(onboardingPayload: trimmed) } catch { throw MatterControllerError.invalidCode }
        }
    }

    /// Koppelt en geeft de nieuwe node-ID terug.
    func commission(code: String) async throws -> UInt64 {
        let payload = try Self.parse(code)
        nodeID = MatterControllerFactory.newNodeID()
        controller.setDeviceControllerDelegate(self, queue: queue)
        return try await withCheckedThrowingContinuation { cont in
            queue.async {
                self.continuation = cont
                do {
                    try self.controller.setupCommissioningSession(with: payload, newNodeID: NSNumber(value: self.nodeID))
                } catch {
                    self.finish(.failure(error))
                }
            }
        }
    }

    private func finish(_ result: Result<UInt64, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(with: result)
    }

    // MARK: MTRDeviceControllerDelegate

    func controller(_ controller: MTRDeviceController, statusUpdate status: MTRCommissioningStatus) {
        if status == .failed {
            finish(.failure(MatterControllerError.commissioningFailed("het apparaat reageerde niet")))
        }
    }

    func controller(_ controller: MTRDeviceController, commissioningSessionEstablishmentDone error: Error?) {
        if let error {
            finish(.failure(MatterControllerError.commissioningFailed(error.localizedDescription)))
            return
        }
        let params = MTRCommissioningParameters()
        params.deviceAttestationDelegate = self
        params.failSafeTimeout = 120
        do {
            try controller.commissionNode(withID: NSNumber(value: nodeID), commissioningParams: params)
        } catch {
            finish(.failure(MatterControllerError.commissioningFailed(error.localizedDescription)))
        }
    }

    func controller(_ controller: MTRDeviceController, commissioningComplete error: Error?) {
        if let error {
            finish(.failure(MatterControllerError.commissioningFailed(error.localizedDescription)))
        } else {
            finish(.success(nodeID))
        }
    }

    // MARK: MTRDeviceAttestationDelegate

    /// Niet-gecertificeerde apparaten (bijv. zelfbouw of test) toch toelaten: de gebruiker
    /// heeft de code van het apparaat zelf. Homio markeert ze als "niet gecertificeerd".
    func deviceAttestationFailed(for controller: MTRDeviceController, opaqueDeviceHandle: UnsafeMutableRawPointer, error: Error) {
        attestationFailed = true
        do {
            try controller.continueCommissioningDevice(opaqueDeviceHandle, ignoreAttestationFailure: true)
        } catch {
            finish(.failure(MatterControllerError.commissioningFailed(error.localizedDescription)))
        }
    }
}

/// Leest naam, merk, serienummer en eindpunten van een gekoppeld apparaat.
enum MatterInspector {
    static func readInfo(nodeID: UInt64, controller: MTRDeviceController) async -> MatterNodeInfo {
        let device = MTRBaseDevice(nodeID: NSNumber(value: nodeID), controller: controller)
        var info = MatterNodeInfo()

        // BasicInformation (0x0028) op eindpunt 0.
        let basic = await read(device, endpoint: 0, cluster: 0x0028, attribute: nil)
        for (path, value) in basic where path.endpoint == 0 {
            switch path.attribute {
            case 0x0001: info.vendorName = value as? String ?? ""
            case 0x0002: info.vendorID = (value as? NSNumber)?.uint32Value ?? 0
            case 0x0003: info.productName = value as? String ?? ""
            case 0x0004: info.productID = (value as? NSNumber)?.uint32Value ?? 0
            case 0x0005: info.nodeLabel = value as? String ?? ""
            case 0x000F: info.serialNumber = value as? String ?? ""
            case 0x0012: info.uniqueID = value as? String ?? ""
            default: break
            }
        }

        // Descriptor (0x001D) DeviceTypeList (0x0000) op alle eindpunten.
        let types = await read(device, endpoint: nil, cluster: 0x001D, attribute: 0x0000)
        for (path, value) in types {
            let list = (value as? [Any] ?? []).compactMap { entry -> UInt32? in
                guard let fields = entry as? [UInt64: Any] else { return nil }
                return (fields[0] as? NSNumber)?.uint32Value
            }
            info.endpoints[path.endpoint] = list
        }

        // Namen van apparaten achter een bridge: BridgedDeviceBasicInformation (0x0039) NodeLabel (0x0005).
        let labels = await read(device, endpoint: nil, cluster: 0x0039, attribute: 0x0005)
        for (path, value) in labels {
            if let label = value as? String, !label.isEmpty { info.endpointLabels[path.endpoint] = label }
        }
        return info
    }

    struct Path: Hashable {
        let endpoint: UInt16
        let cluster: UInt32
        let attribute: UInt32
    }

    private static func read(_ device: MTRBaseDevice, endpoint: UInt16?, cluster: UInt32, attribute: UInt32?) async -> [Path: Any] {
        await withCheckedContinuation { cont in
            device.readAttributes(withEndpointID: endpoint.map { NSNumber(value: $0) },
                                  clusterID: NSNumber(value: cluster),
                                  attributeID: attribute.map { NSNumber(value: $0) },
                                  params: nil,
                                  queue: .global()) { values, _ in
                var out: [Path: Any] = [:]
                for item in values ?? [] {
                    guard let path = item[MTRAttributePathKey] as? MTRAttributePath else { continue }
                    let key = Path(endpoint: path.endpoint.uint16Value, cluster: path.cluster.uint32Value,
                                   attribute: path.attribute.uint32Value)
                    if let v = MatterValue.decode(item[MTRDataKey]) { out[key] = v }
                }
                cont.resume(returning: out)
            }
        }
    }
}

/// Een apparaat dat de koppel-extensie heeft toegevoegd; de app neemt het over.
struct PendingMatterDevice: Codable {
    var nodeID: UInt64
    var name: String
    var room: String?
    var info: MatterNodeInfo
    var certified: Bool
}
