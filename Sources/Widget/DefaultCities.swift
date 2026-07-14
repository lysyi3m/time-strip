import TimeStripKit

/// Temporary default city set for the P5 timeline provider — shown until the user configures
/// their own via the native widget editor in P6 (which resolves selections from the real
/// `cities.json` dataset). Ordered west → east by longitude; slot 0 is the reference/home row.
enum DefaultCities {
    static let ordered: [City] = [
        City(id: "america-los-angeles", name: "Los Angeles", country: "United States",
             admin1: "California", tzid: "America/Los_Angeles",
             coordinate: GeoCoordinate(latitude: 34.0522, longitude: -118.2437), population: 3_898_747),
        City(id: "america-new-york", name: "New York", country: "United States",
             admin1: "New York", tzid: "America/New_York",
             coordinate: GeoCoordinate(latitude: 40.7128, longitude: -74.0060), population: 8_804_190),
        City(id: "europe-london", name: "London", country: "United Kingdom",
             admin1: "England", tzid: "Europe/London",
             coordinate: GeoCoordinate(latitude: 51.5074, longitude: -0.1278), population: 8_982_000),
        City(id: "europe-warsaw", name: "Warsaw", country: "Poland",
             admin1: "Masovian", tzid: "Europe/Warsaw",
             coordinate: GeoCoordinate(latitude: 52.2297, longitude: 21.0122), population: 1_793_579),
        City(id: "asia-singapore", name: "Singapore", country: "Singapore",
             admin1: nil, tzid: "Asia/Singapore",
             coordinate: GeoCoordinate(latitude: 1.3521, longitude: 103.8198), population: 5_453_600),
    ]
}
