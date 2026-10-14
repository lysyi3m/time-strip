import Foundation

/// The pickable places. The OS knows only time zones (`TimeZone.knownTimeZoneIdentifiers`), not
/// the cities inside them, so a city such as Seattle or Astana is not in its list. A bundled table
/// generated from GeoNames (`Resources/cities.tsv`, see `Scripts/make-cities.swift`) maps each
/// city to its zone. The OS zones stay pickable too, for UTC offsets and for widgets saved before
/// the table existed.
public enum CityCatalog {

    /// Every city in the bundled table, most populous first. Loads on first use; the widget's
    /// render path never touches it.
    public static let cities: [City] = table.map(\.city)

    /// Every OS zone except bare "GMT" (the only region-less id), less the zones whose label
    /// already names a city in that zone, so "Los Angeles" appears once.
    public static let zones: [City] = {
        let covered = Set(table.map { "\($0.city.tzid)|\($0.names[0])" })
        return osZones.filter { !covered.contains("\($0.tzid)|\($0.name.foldedForSearch)") }
    }()

    private static let osZones: [City] = TimeZone.knownTimeZoneIdentifiers
        .filter { $0.contains("/") }
        .map { City(name: City.zoneName(forTZID: $0), tzid: $0) }

    /// Resolves a saved selection by its `City.id`.
    public static func city(forID id: String) -> City? { City(id: id) }

    /// Picker subtitle that tells same-named places apart: "Washington, United States" for a
    /// city, the IANA id for a zone.
    public static func subtitle(for city: City, locale: Locale = .current) -> String {
        guard !city.isZone else { return city.tzid }
        let country = locale.localizedString(forRegionCode: city.country) ?? city.country
        return city.admin.isEmpty || city.admin == city.name ? country : "\(city.admin), \(country)"
    }

    /// Case- and diacritic-insensitive search. An empty query returns the curated suggestions.
    /// Ranked by how the query matches — name prefix, word prefix inside the name, country name,
    /// name substring, then the zone's name ("Pacific Time") or id — and by population within a
    /// rank, so the largest Paris comes first.
    public static func search(_ query: String, limit: Int = 40) -> [City] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).foldedForSearch
        guard !q.isEmpty else { return suggested }
        // Country and zone names repeat across thousands of cities, so match each one once.
        let countryHits = Set(countryNames.filter { $0.value.contains { $0.hasPrefix(q) } }.keys)
        let zoneHits = Set(zoneNames.filter { $0.value.contains { $0.contains(q) } }.keys)
        let wordPrefixes = [" \(q)", "-\(q)"]
        let scored: [(entry: Row, rank: Int)] = entries.compactMap { entry in
            var rank = Int.max
            for name in entry.names where name.contains(q) {
                if name.hasPrefix(q) { return (entry, 0) }
                rank = min(rank, wordPrefixes.contains { name.contains($0) } ? 1 : 3)
            }
            if countryHits.contains(entry.city.country) { rank = min(rank, 2) }
            if zoneHits.contains(entry.city.tzid) { rank = min(rank, 4) }
            return rank == .max ? nil : (entry, rank)
        }
        return scored
            .sorted {
                if $0.rank != $1.rank { return $0.rank < $1.rank }
                if $0.entry.population != $1.entry.population {
                    return $0.entry.population > $1.entry.population
                }
                return $0.entry.city.name.localizedCaseInsensitiveCompare($1.entry.city.name) == .orderedAscending
            }
            .prefix(max(0, limit))  // `prefix` traps on a negative count; clamp defensively
            .map(\.entry.city)
    }

    /// Curated popular cities shown when the picker opens, as name and ISO country. The table is
    /// sorted by population, so the first match is the largest city of that name.
    public static let suggested: [City] = popularCities.compactMap { name, country in
        table.first { $0.city.name == name && $0.city.country == country }?.city
    }

    /// A sensible default row set for a freshly added, unconfigured widget (west → east). These
    /// are OS zones, so rendering a fresh widget never loads the city table.
    public static let defaults: [City] = defaultTZIDs.compactMap { City(id: $0) }

    private static let defaultTZIDs = [
        "America/Los_Angeles", "America/New_York", "Europe/London", "Europe/Warsaw",
        "Asia/Dubai", "Asia/Singapore", "Asia/Tokyo",
    ]

    private static let popularCities = [
        ("Los Angeles", "US"), ("Denver", "US"), ("Chicago", "US"), ("New York City", "US"),
        ("Toronto", "CA"), ("São Paulo", "BR"), ("London", "GB"), ("Paris", "FR"),
        ("Berlin", "DE"), ("Madrid", "ES"), ("Rome", "IT"), ("Warsaw", "PL"), ("Moscow", "RU"),
        ("Cairo", "EG"), ("Johannesburg", "ZA"), ("Dubai", "AE"), ("Mumbai", "IN"),
        ("Bangkok", "TH"), ("Shanghai", "CN"), ("Hong Kong", "HK"), ("Singapore", "SG"),
        ("Tokyo", "JP"), ("Seoul", "KR"), ("Sydney", "AU"), ("Auckland", "NZ"),
    ]

    // MARK: - Table

    /// Every searchable place: the table's cities, then the OS zones.
    private static let entries: [Row] =
        table + zones.map { Row(city: $0, population: 0, names: [$0.name.foldedForSearch]) }

    private static let searchLocales = [Locale.current, Locale(identifier: "en")]

    /// Folded country names by ISO code, in the user's language and in English.
    private static let countryNames: [String: [String]] = Dictionary(
        uniqueKeysWithValues: Set(table.map(\.city.country)).map { code in
            (code, Array(Set(searchLocales.compactMap { $0.localizedString(forRegionCode: code)?.foldedForSearch })))
        }
    )

    /// Folded generic zone names ("Pacific Time") and the folded IANA id, by IANA id.
    private static let zoneNames: [String: [String]] = Dictionary(
        uniqueKeysWithValues: Set(entries.map(\.city.tzid)).map { tzid in
            let generic = searchLocales.compactMap {
                TimeZone(identifier: tzid)?.localizedName(for: .generic, locale: $0)?.foldedForSearch
            }
            return (tzid, Array(Set(generic + [tzid.foldedForSearch])))
        }
    )

    private struct Row {
        let city: City
        let population: Int
        let names: [String]     // folded name, then the folded ASCII name when the table has one
    }

    private static let table: [Row] = loadTable()

    private final class BundleToken {}

    /// Parses the table: name, ASCII name (only when folding cannot reach it), admin1, ISO
    /// country, IANA tzid, population, most populous first. Lines starting with `#` are comments.
    private static func loadTable() -> [Row] {
        guard
            let url = Bundle(for: BundleToken.self).url(forResource: "cities", withExtension: "tsv"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            assertionFailure("cities.tsv is missing from the TimeStripKit bundle")
            return []
        }
        return text.split(separator: "\n").compactMap { line in
            let f = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard !line.hasPrefix("#"), f.count == 6 else { return nil }
            return Row(
                city: City(name: String(f[0]), tzid: String(f[4]), admin: String(f[2]), country: String(f[3])),
                population: Int(f[5]) ?? 0,
                names: [f[0].foldedForSearch] + (f[1].isEmpty ? [] : [f[1].foldedForSearch])
            )
        }
    }
}

private extension StringProtocol {
    /// Lowercased + diacritic-folded, for accent- and case-insensitive matching.
    var foldedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
