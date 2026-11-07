import CoreLocation
import SwiftUI

/// Weer via Open-Meteo (geen sleutel nodig). Vermeld "Weergegevens: Open-Meteo.com" in de app.
@MainActor
final class WeatherService: NSObject, ObservableObject {
    struct Current {
        var temperature: Double
        var code: Int
        var wind: Double
        var isDay: Bool
    }

    struct Hour: Identifiable {
        let date: Date
        let temperature: Double
        let code: Int
        var id: Date { date }
    }

    struct Day: Identifiable {
        let date: Date
        let code: Int
        let high: Double
        let low: Double
        var id: Date { date }
    }

    @Published private(set) var current: Current?
    @Published private(set) var hours: [Hour] = []
    @Published private(set) var days: [Day] = []
    @Published private(set) var place: String = ""
    @Published private(set) var problem: String?

    private let locationManager = CLLocationManager()
    private var lastFetch: Date?
    private var started = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Mag vaak worden aangeroepen; haalt hooguit elk half uur nieuw weer op.
    func start() {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < 1800 { return }
        started = true
        requestLocationIfAllowed()
    }

    private func requestLocationIfAllowed() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            problem = "Geef Homio toegang tot je locatie voor het weer."
        }
    }

    fileprivate func fetch(for location: CLLocation) async {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", lat)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", lon)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,wind_speed_10m,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7")
        ]
        guard let url = components.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ForecastResponse.self, from: data)
            apply(response)
            lastFetch = Date()
            problem = nil
        } catch {
            problem = "Weer kon niet worden geladen."
        }

        if let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            place = placemark.locality ?? placemark.name ?? ""
        }
    }

    private func apply(_ r: ForecastResponse) {
        current = Current(temperature: r.current.temperature_2m,
                          code: r.current.weather_code,
                          wind: r.current.wind_speed_10m,
                          isDay: r.current.is_day == 1)

        let now = Date()
        var hourList: [Hour] = []
        for (index, time) in r.hourly.time.enumerated() {
            guard let date = Self.hourFormatter.date(from: time),
                  date > now.addingTimeInterval(-3600),
                  index < r.hourly.temperature_2m.count,
                  index < r.hourly.weather_code.count else { continue }
            hourList.append(Hour(date: date, temperature: r.hourly.temperature_2m[index],
                                 code: r.hourly.weather_code[index]))
            if hourList.count == 12 { break }
        }
        hours = hourList

        var dayList: [Day] = []
        for (index, time) in r.daily.time.enumerated() {
            guard let date = Self.dayFormatter.date(from: time),
                  index < r.daily.weather_code.count,
                  index < r.daily.temperature_2m_max.count,
                  index < r.daily.temperature_2m_min.count else { continue }
            dayList.append(Day(date: date, code: r.daily.weather_code[index],
                               high: r.daily.temperature_2m_max[index],
                               low: r.daily.temperature_2m_min[index]))
        }
        days = dayList
    }

    // Opmakers één keer maken en hergebruiken.
    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: Weercodes (WMO)

    static func symbol(for code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Helder"
        case 1: return "Overwegend helder"
        case 2: return "Half bewolkt"
        case 3: return "Bewolkt"
        case 45, 48: return "Mist"
        case 51...57: return "Motregen"
        case 61...65: return "Regen"
        case 66, 67: return "IJzel"
        case 71...77: return "Sneeuw"
        case 80...82: return "Buien"
        case 85, 86: return "Sneeuwbuien"
        case 95...99: return "Onweer"
        default: return "Wisselend"
        }
    }

    static func isRainy(_ code: Int) -> Bool {
        (51...67).contains(code) || (80...82).contains(code) || (95...99).contains(code)
    }
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in await self.fetch(for: location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.problem = "Locatie niet beschikbaar." }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if self.started { self.requestLocationIfAllowed() }
        }
    }
}

// MARK: Open-Meteo JSON

private struct ForecastResponse: Decodable {
    struct CurrentBlock: Decodable {
        let temperature_2m: Double
        let weather_code: Int
        let wind_speed_10m: Double
        let is_day: Int
    }

    struct HourlyBlock: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let weather_code: [Int]
    }

    struct DailyBlock: Decodable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }

    let current: CurrentBlock
    let hourly: HourlyBlock
    let daily: DailyBlock
}
