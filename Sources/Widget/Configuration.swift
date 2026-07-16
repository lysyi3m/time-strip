import AppIntents
import TimeStripKit

/// A selectable time zone exposed to the native widget editor. Backed by `CityCatalog`; the id
/// is the IANA identifier, so selections resolve stably across launches. The region is shown as
/// a subtitle to disambiguate same-named cities.
struct CityEntity: AppEntity {
    let id: String        // IANA tzid
    let name: String
    let region: String

    init(city: City) {
        self.id = city.id
        self.name = city.name
        self.region = CityCatalog.region(forTZID: city.tzid)
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "City" }
    static var defaultQuery = CityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(region)")
    }
}

/// Feeds the native searchable picker: popular suggestions when empty, population-free string
/// search while typing, and id resolution for saved selections — all from `CityCatalog`.
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
    static var title: LocalizedStringResource = "Time Strip"
    static var description = IntentDescription("Choose the time zones to show as ribbons.")

    static let maxCities = 7

    @Parameter(title: "Cities")
    var cities: [CityEntity]?

    /// The ordered cities the user selected, in order, capped at `maxCities`. No fallback — the
    /// provider decides what to do with 0 (fresh widget → defaults) vs 1 (→ setup prompt) vs 2+.
    var configuredCities: [City] {
        (cities ?? [])
            .prefix(Self.maxCities)
            .map { City(name: $0.name, tzid: $0.id) }
    }
}
