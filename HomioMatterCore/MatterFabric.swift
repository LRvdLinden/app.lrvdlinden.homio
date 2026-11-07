import CryptoKit
import Foundation
@preconcurrency import Matter
import Security

/// Homio's eigen Matter-netwerk (fabric). De geheimen (root-sleutel, IPK, fabric-ID en
/// root-certificaat) staan in de iCloud-sleutelhanger, zodat al je Apple-apparaten
/// hetzelfde netwerk kunnen bedienen. Gedeeld tussen de app en de koppel-extensie.
enum MatterShared {
    static let appGroup = "group.nl.lrvdlinden.homio"
    /// Team-prefix + gedeelde sleutelhangergroep (zie keychain-access-groups in de entitlements).
    static let keychainGroup = "EU3UY476T6.nl.lrvdlinden.homio.shared"
    /// Matter-testleverancier; vervang door een eigen Vendor ID zodra die er is.
    static let vendorID: UInt16 = 0xFFF1

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    /// Apparaten die de extensie heeft gekoppeld en die de app nog moet overnemen.
    static let pendingKey = "matter.pending.v1"
    /// Kamers die de app aan de extensie doorgeeft (voor het koppelscherm van Apple).
    static let roomsKey = "matter.rooms.v1"
}

struct FabricSecrets: Codable {
    var rootKey: Data       // P-256 private key (rawRepresentation)
    var ipk: Data           // 16 bytes
    var fabricID: UInt64
    var rootCertificate: Data?
    var created: Date

    static func generate() -> FabricSecrets {
        var ipk = Data(count: 16)
        _ = ipk.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let fabricID = UInt64.random(in: 1...0xFFFF_FFFF_FFFF_FFFE)
        return FabricSecrets(rootKey: P256.Signing.PrivateKey().rawRepresentation,
                             ipk: ipk, fabricID: fabricID, rootCertificate: nil, created: Date())
    }
}

/// Opslag van de fabric-geheimen in de (gesynchroniseerde) sleutelhanger.
enum FabricVault {
    private static let service = "nl.lrvdlinden.homio.matter"
    private static let account = "fabric"

    private static func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrAccessGroup as String: MatterShared.keychainGroup,
         kSecAttrSynchronizable as String: kCFBooleanTrue as Any]
    }

    static func load() -> FabricSecrets? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(FabricSecrets.self, from: data)
    }

    static func save(_ secrets: FabricSecrets) throws {
        let data = try JSONEncoder().encode(secrets)
        let update: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(baseQuery() as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery()
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    /// Bestaande geheimen, of nieuwe als er nog geen Homio-netwerk is.
    static func loadOrCreate() throws -> FabricSecrets {
        if let existing = load() { return existing }
        let fresh = FabricSecrets.generate()
        try save(fresh)
        return fresh
    }
}

/// De root-sleutel als MTRKeypair, zodat Matter er certificaten mee kan ondertekenen.
final class FabricKeypair: NSObject, MTRKeypair {
    private let privateKey: P256.Signing.PrivateKey
    private let secKey: SecKey

    init(rawPrivateKey: Data) throws {
        privateKey = try P256.Signing.PrivateKey(rawRepresentation: rawPrivateKey)
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                         kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                                         kSecAttrKeySizeInBits as String: 256]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(privateKey.publicKey.x963Representation as CFData,
                                             attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() ?? NSError(domain: "Homio.Matter", code: 1)
        }
        secKey = key
    }

    /// iOS 18.4+: kopie van de publieke sleutel.
    func copyPublicKey() -> SecKey {
        secKey
    }

    /// Voor oudere iOS-versies (zonder extra referentie).
    func publicKey() -> Unmanaged<SecKey> {
        Unmanaged.passUnretained(secKey)
    }

    func signMessageECDSA_DER(_ message: Data) -> Data {
        (try? privateKey.signature(for: message).derRepresentation) ?? Data()
    }
}

/// Opslag voor de Matter-controller in de gedeelde App Group. App en extensie hebben elk
/// een eigen voorvoegsel, zodat ze elkaars controller-identiteit niet overschrijven.
final class MatterStorage: NSObject, MTRStorage {
    private let prefix: String
    private let defaults = MatterShared.defaults

    init(prefix: String) {
        self.prefix = "mtr.\(prefix)."
    }

    func storageData(forKey key: String) -> Data? {
        defaults.data(forKey: prefix + key)
    }

    func setStorageData(_ value: Data, forKey key: String) -> Bool {
        defaults.set(value, forKey: prefix + key)
        return true
    }

    func removeStorageData(forKey key: String) -> Bool {
        defaults.removeObject(forKey: prefix + key)
        return true
    }
}

enum MatterControllerError: LocalizedError {
    case noController
    case invalidCode
    case commissioningFailed(String)

    var errorDescription: String? {
        switch self {
        case .noController: return "Het Matter-netwerk van Homio kon niet starten."
        case .invalidCode: return "Deze koppelcode klopt niet. Controleer de 11 of 21 cijfers, of scan de QR-code."
        case .commissioningFailed(let reason): return "Koppelen is niet gelukt: \(reason)"
        }
    }
}

/// Start (één keer per proces) de Matter-controller op Homio's fabric.
enum MatterControllerFactory {
    private static var controller: MTRDeviceController?
    private static let lock = NSLock()

    static func shared(prefix: String) throws -> MTRDeviceController {
        lock.lock()
        defer { lock.unlock() }
        if let controller, controller.isRunning { return controller }

        let factory = MTRDeviceControllerFactory.sharedInstance()
        if !factory.isRunning {
            try factory.start(MTRDeviceControllerFactoryParams(storage: MatterStorage(prefix: prefix)))
        }

        var secrets = try FabricVault.loadOrCreate()
        let signer = try FabricKeypair(rawPrivateKey: secrets.rootKey)
        if secrets.rootCertificate == nil {
            secrets.rootCertificate = try MTRCertificates.createRootCertificate(
                signer, issuerID: nil, fabricID: NSNumber(value: secrets.fabricID))
            try FabricVault.save(secrets)
        }

        let params = MTRDeviceControllerStartupParams(ipk: secrets.ipk,
                                                      fabricID: NSNumber(value: secrets.fabricID),
                                                      nocSigner: signer)
        params.vendorID = NSNumber(value: MatterShared.vendorID)
        params.rootCertificate = secrets.rootCertificate

        let made: MTRDeviceController
        if let existing = try? factory.createController(onExistingFabric: params) {
            made = existing
        } else {
            made = try factory.createController(onNewFabric: params)
        }
        controller = made
        return made
    }

    /// Nieuwe node-ID binnen het geldige operationele bereik.
    static func newNodeID() -> UInt64 {
        UInt64.random(in: 0x1_0000...0xFFFF_FFEF_FFFF_FFFF)
    }
}
