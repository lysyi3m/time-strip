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

/// The widget's Edit-Widget configuration: five fixed city slots (slot 1 = reference/home row)
/// plus an optional manual zone-tag label per slot. Fixed slots rather than a dynamic array —
/// the native editor renders a reorderable array poorly (spec §6/Phase 6).
struct TimeStripConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Time Strip"
    static var description = IntentDescription("Choose up to five time zones to show as ribbons.")

    @Parameter(title: "City 1") var city1: CityEntity?
    @Parameter(title: "City 2") var city2: CityEntity?
    @Parameter(title: "City 3") var city3: CityEntity?
    @Parameter(title: "City 4") var city4: CityEntity?
    @Parameter(title: "City 5") var city5: CityEntity?

    @Parameter(title: "Label 1") var label1: String?
    @Parameter(title: "Label 2") var label2: String?
    @Parameter(title: "Label 3") var label3: String?
    @Parameter(title: "Label 4") var label4: String?
    @Parameter(title: "Label 5") var label5: String?

    /// The ordered cities the user actually selected (empty slots collapse). No fallback — the
    /// provider decides what to do with 0 (fresh widget → defaults) vs 1 (→ setup prompt) vs 2+.
    var configuredCities: [City] {
        let slots: [(entity: CityEntity?, label: String?)] = [
            (city1, label1), (city2, label2), (city3, label3), (city4, label4), (city5, label5),
        ]
        return slots.compactMap { slot -> City? in
            guard let entity = slot.entity else { return nil }
            let trimmed = slot.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = (trimmed?.isEmpty == false) ? trimmed : nil
            return City(name: entity.name, tzid: entity.id, label: label)
        }
    }
}
