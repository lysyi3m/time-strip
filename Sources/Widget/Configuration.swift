import AppIntents
import TimeStripKit

/// A selectable city exposed to the native widget editor. The id is `City.id`, which carries
/// everything needed to rebuild the city, so selections resolve stably across launches and table
/// updates. The subtitle tells same-named cities apart.
struct CityEntity: AppEntity {
    let city: City
    var id: String { city.id }

    init(city: City) {
        self.city = city
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "City" }
    static let defaultQuery = CityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(city.name)", subtitle: "\(CityCatalog.subtitle(for: city))")
    }
}

/// Feeds the native searchable picker: popular suggestions when empty, string search while
/// typing, and id resolution for saved selections — all from `CityCatalog`.
struct CityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CityEntity] {
        identifiers.compactMap { CityCatalog.city(forID: $0).map(CityEntity.init) }
    }

    func suggestedEntities() async throws -> [CityEntity] {
        CityCatalog.suggested.map(CityEntity.init)
    }

    func entities(matching string: String) async throws -> [CityEntity] {
        CityCatalog.search(string).map(CityEntity.init)
    }
}

/// The widget's Edit-Widget configuration: a single ordered list of cities. A dynamic array
/// (not fixed slots) so the native editor offers add / remove / drag-to-reorder. The first entry
/// is the reference/home row. Up to `maxCities` are kept; how many actually render depends on the
/// family (fewer on `.systemMedium`, more on `.systemLarge`).
struct TimeStripConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Time Strip"
    static let description = IntentDescription("Choose the cities to show as ribbons.")

    static let maxCities = 7

    @Parameter(title: "Cities")
    var cities: [CityEntity]?

    /// The ordered cities the user selected, in order, capped at `maxCities`. No fallback — the
    /// provider decides what to do with 0 (fresh widget → defaults) vs 1 (→ setup prompt) vs 2+.
    var configuredCities: [City] {
        (cities ?? [])
            .prefix(Self.maxCities)
            .map(\.city)
    }
}
