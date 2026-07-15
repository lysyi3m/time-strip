import Foundation

/// The pickable set of time zones — sourced entirely from the OS
/// (`TimeZone.knownTimeZoneIdentifiers`), with no bundled dataset. A Time Strip row is a time
/// zone; the "city" is just its label, taken from the identifier's last path segment. Names
/// follow the OS's canonical identifiers, so a few read as older spellings (e.g. "Calcutta")
/// and the list carries a handful of alias duplicates (e.g. Kyiv/Kiev); refining display names
/// is deferred polish and would slot into `displayName(forTZID:)`.
public enum CityCatalog {

    /// Every selectable zone, sorted by display name. Bare "GMT" (the only region-less id) is
    /// dropped — every real zone is region-qualified ("Europe/…", "Asia/…").
    public static let all: [City] = TimeZone.knownTimeZoneIdentifiers
        .filter { $0.contains("/") }
        .map { City(name: displayName(forTZID: $0), tzid: $0) }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    /// Friendly city name from an IANA id: last path segment, underscores → spaces.
    public static func displayName(forTZID tzid: String) -> String {
        guard let last = tzid.split(separator: "/").last else { return tzid }
        return last.replacingOccurrences(of: "_", with: " ")
    }

    /// Region (leading segment) for disambiguation in the picker subtitle, e.g. "Europe".
    public static func region(forTZID tzid: String) -> String {
        guard let first = tzid.split(separator: "/").first else { return "" }
        return String(first)
    }

    /// Lookup by stable id (the IANA identifier).
    public static func city(forID id: String) -> City? { byID[id] }

    private static let byID: [String: City] =
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    /// Case- and diacritic-insensitive search over display name and identifier. An empty query
    /// returns the curated suggestions. Ranked: name-prefix hits, then name-substring, then
    /// identifier-substring — each alphabetically.
    public static func search(_ query: String, limit: Int = 40) -> [City] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).foldedForSearch
        guard !q.isEmpty else { return suggested }
        let scored: [(city: City, rank: Int)] = all.compactMap { city in
            let name = city.name.foldedForSearch
            if name.hasPrefix(q) { return (city, 0) }
            if name.contains(q) { return (city, 1) }
            if city.tzid.foldedForSearch.contains(q) { return (city, 2) }
            return nil
        }
        return scored
            .sorted {
                $0.rank != $1.rank
                    ? $0.rank < $1.rank
                    : $0.city.name.localizedCaseInsensitiveCompare($1.city.name) == .orderedAscending
            }
            .prefix(limit)
            .map(\.city)
    }

    /// Curated popular zones shown when the picker opens (the OS list carries no population to
    /// rank by). `Asia/Calcutta` is the OS's canonical id for India (Kolkata isn't "known").
    public static let suggested: [City] = popularTZIDs.compactMap { byID[$0] }

    /// A sensible default row set for a freshly added, unconfigured widget (west → east).
    public static let defaults: [City] = defaultTZIDs.compactMap { byID[$0] }

    private static let defaultTZIDs = [
        "America/Los_Angeles", "America/New_York", "Europe/London", "Europe/Warsaw", "Asia/Singapore",
    ]

    private static let popularTZIDs = [
        "America/Los_Angeles", "America/Denver", "America/Chicago", "America/New_York",
        "America/Toronto", "America/Sao_Paulo", "Europe/London", "Europe/Paris",
        "Europe/Berlin", "Europe/Madrid", "Europe/Rome", "Europe/Warsaw", "Europe/Moscow",
        "Africa/Cairo", "Africa/Johannesburg", "Asia/Dubai", "Asia/Calcutta", "Asia/Bangkok",
        "Asia/Shanghai", "Asia/Hong_Kong", "Asia/Singapore", "Asia/Tokyo", "Asia/Seoul",
        "Australia/Sydney", "Pacific/Auckland",
    ]
}

private extension String {
    /// Lowercased + diacritic-folded, for accent- and case-insensitive matching.
    var foldedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
