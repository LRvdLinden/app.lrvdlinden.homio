import Foundation

/// Matter-clusters en -attributen die Homio gebruikt (Matter 1.4-specificatie).
enum MC {
    static let onOff: UInt32 = 0x0006
    static let level: UInt32 = 0x0008
    static let descriptor: UInt32 = 0x001D
    static let basic: UInt32 = 0x0028
    static let powerSource: UInt32 = 0x002F
    static let opCredentials: UInt32 = 0x003E
    static let booleanState: UInt32 = 0x0045
    static let airQuality: UInt32 = 0x005B
    static let smokeCO: UInt32 = 0x005C
    static let opState: UInt32 = 0x0060
    static let rvcOpState: UInt32 = 0x0061
    static let valve: UInt32 = 0x0081
    static let elecPower: UInt32 = 0x0090
    static let doorLock: UInt32 = 0x0101
    static let windowCovering: UInt32 = 0x0102
    static let thermostat: UInt32 = 0x0201
    static let fan: UInt32 = 0x0202
    static let color: UInt32 = 0x0300
    static let illuminance: UInt32 = 0x0400
    static let temperature: UInt32 = 0x0402
    static let pressure: UInt32 = 0x0403
    static let flow: UInt32 = 0x0404
    static let humidity: UInt32 = 0x0405
    static let occupancy: UInt32 = 0x0406
}

/// Alle Matter device types (spec 1.0–1.4) → Homio's soort apparaat.
enum MatterDeviceTypes {
    /// Nuts-types die zelf geen apparaat zijn.
    static let utility: Set<UInt32> = [0x0016, 0x0011, 0x0013, 0x000E, 0x0012, 0x0014, 0x0019, 0x0510]

    static let names: [UInt32: String] = [
        0x0100: "Aan/uit-lamp", 0x0101: "Dimbare lamp", 0x010C: "Kleurtemperatuurlamp", 0x010D: "Kleurenlamp",
        0x010A: "Stekker", 0x010B: "Dimbare stekker", 0x0110: "Inbouwschakelaar", 0x0111: "Inbouwdimmer", 0x0303: "Pomp",
        0x0103: "Lichtschakelaar", 0x0104: "Dimschakelaar", 0x0105: "Kleurdimschakelaar", 0x000F: "Knop",
        0x0840: "Schakelaar", 0x0842: "Bediening",
        0x000A: "Deurslot", 0x0202: "Raambekleding", 0x0301: "Thermostaat", 0x0300: "Verwarming/koeling",
        0x0072: "Airco", 0x0309: "Warmtepomp", 0x050F: "Boiler", 0x002B: "Ventilator", 0x002D: "Luchtreiniger",
        0x002C: "Luchtkwaliteitssensor", 0x0022: "Speaker", 0x0023: "Mediaspeler", 0x0024: "Castingspeler",
        0x0028: "Videospeler", 0x0029: "Content-app", 0x002A: "Afstandsbediening",
        0x0302: "Temperatuursensor", 0x0307: "Vochtigheidssensor", 0x0106: "Lichtsensor", 0x0107: "Aanwezigheidssensor",
        0x0015: "Contactsensor", 0x0076: "Rook-/CO-melder", 0x0043: "Lekkagemelder", 0x0041: "Vorstmelder",
        0x0044: "Regensensor", 0x0305: "Druksensor", 0x0306: "Debietsensor", 0x0042: "Waterklep", 0x0040: "Beregening",
        0x0074: "Robotstofzuiger", 0x0070: "Koelkast", 0x0071: "Koelkast", 0x0073: "Wasmachine", 0x0075: "Vaatwasser",
        0x0077: "Kookplaat", 0x0078: "Kookzone", 0x0079: "Magnetron", 0x007A: "Afzuigkap", 0x007B: "Oven", 0x007C: "Droger",
        0x0027: "Modusknop", 0x050C: "Laadpaal", 0x050D: "Energiebeheer", 0x0017: "Zonnepanelen", 0x0018: "Thuisbatterij",
        0x0142: "Camera", 0x0143: "Videodeurbel", 0x0144: "Deurbel", 0x0145: "Intercom"
    ]

    /// Volgorde bepaalt welk type wint als een eindpunt er meerdere heeft.
    static func kind(for types: [UInt32]) -> DeviceKind? {
        let set = Set(types).subtracting(utility)
        guard !set.isEmpty else { return nil }
        let order: [(Set<UInt32>, DeviceKind)] = [
            ([0x0076], .smoke), ([0x0043, 0x0041], .leak), ([0x000A], .lock), ([0x0202], .blinds),
            ([0x0301], .thermostat), ([0x0300, 0x0072, 0x050F], .heaterCooler), ([0x002D], .airPurifier),
            ([0x002B], .fan), ([0x0042, 0x0040], .valve), ([0x0074], .vacuum),
            ([0x0070, 0x0071, 0x0073, 0x0075, 0x0077, 0x0078, 0x0079, 0x007A, 0x007B, 0x007C, 0x0027], .appliance),
            ([0x050C, 0x050D, 0x0017, 0x0018, 0x0309], .energy),
            ([0x0100, 0x0101, 0x010C, 0x010D], .light),
            ([0x010A, 0x010B, 0x0110, 0x0111, 0x0303], .outlet),
            ([0x0022], .speaker), ([0x0023, 0x0024, 0x0028, 0x0029], .tv),
            ([0x0302], .temperature), ([0x0307], .humidity), ([0x0106], .lux), ([0x0107], .occupancy),
            ([0x0015], .contact), ([0x002C], .airQuality), ([0x0044, 0x0305, 0x0306], .sensor),
            ([0x0103, 0x0104, 0x0105, 0x000F, 0x0840, 0x0842, 0x002A], .switchKind),
            ([0x0142, 0x0143, 0x0144, 0x0145], .security)
        ]
        for (ids, kind) in order where !ids.isDisjoint(with: set) { return kind }
        return .switchKind
    }

    static func label(for types: [UInt32]) -> String {
        types.lazy.compactMap { names[$0] }.first ?? "Matter-apparaat"
    }
}
