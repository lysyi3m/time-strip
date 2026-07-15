import Foundation

/// The two lines of a slot cell — a number over an optional label, on the shared
/// number-over-label baseline (hour over meridiem, or day-of-month over weekday).
public struct SlotLabel: Hashable, Sendable {
    public let primary: String
    public let secondary: String

    public init(primary: String, secondary: String) {
        self.primary = primary
        self.secondary = secondary
    }
}

/// Turns a `Slot` + `City` into the locale-correct strings the view renders. Pure; locale
/// is a parameter (the UI passes `.current`) so it is fully testable.
///
/// Note: the documented spec signature `slotLabel(for:locale:is12h:)` gains a `timeZone`
/// parameter — the date slot's day-of-month/weekday derive from the absolute instant in the
/// city's zone, which a `Slot` (hour/minute only) can't supply on its own.
public enum RibbonFormatter {

    /// 12h vs 24h from the locale — reflects both the region default and the system
    /// 24-Hour toggle when `locale` is `.current`.
    public static func uses12HourClock(locale: Locale) -> Bool {
        DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale)?
            .contains("a") ?? false
    }

    public static func slotLabel(
        for slot: Slot,
        timeZone: TimeZone,
        locale: Locale,
        is12h: Bool
    ) -> SlotLabel {
        slot.isDayStart
            ? dateLabel(for: slot, timeZone: timeZone, locale: locale)
            : hourLabel(for: slot, locale: locale, is12h: is12h)
    }

    /// Conventional abbreviation when one exists, else `UTC±N` (`:30`/`:45` supported).
    /// A per-city manual override wins over both — but an empty/whitespace-only override
    /// is treated as *unset* (falls through to the computed tag), so clearing the override
    /// field in the config never leaves the row with a blank zone tag.
    /// Instant-based → DST-correct.
    public static func zoneTag(for city: City, at instant: Date, override: String?) -> String {
        if let override, !override.trimmingCharacters(in: .whitespaces).isEmpty {
            return override
        }

        let tz = city.timeZone
        let abbreviation = tz.abbreviation(for: instant) ?? ""

        // `GMT±N` is the no-conventional-abbreviation fallback; normalize it to `UTC±N`
        // built from the actual offset (so `:30`/`:45` zones read correctly).
        if abbreviation.range(of: #"^GMT[+-]\d"#, options: .regularExpression) != nil {
            return utcOffsetTag(secondsFromGMT: tz.secondsFromGMT(for: instant))
        }
        return abbreviation
    }

    /// A spoken one-line summary of the widget for VoiceOver: each city and its current local
    /// time at the now-column, e.g. "Los Angeles 11:00 PM, New York 2:00 AM, London 7:00 AM".
    /// Uses the locale's hour format (12h/24h) and includes minutes so sub-hour zones read right.
    public static func accessibilitySummary(for snapshot: RibbonSnapshot, locale: Locale) -> String {
        let nowInstant = snapshot.columnInstants.indices.contains(snapshot.nowColumnIndex)
            ? snapshot.columnInstants[snapshot.nowColumnIndex]
            : snapshot.now
        return snapshot.rows
            .map { row in
                let time = formatted(nowInstant, template: "jmm", timeZone: row.city.timeZone, locale: locale)
                return "\(row.city.name) \(time)"
            }
            .joined(separator: ", ")
    }

    // MARK: - Hour slot

    private static func hourLabel(for slot: Slot, locale: Locale, is12h: Bool) -> SlotLabel {
        let subHour = slot.minute != 0

        if !is12h {
            // 24h: zero-padded two digits keep columns optically even.
            let primary = subHour
                ? String(format: "%02d:%02d", slot.hour, slot.minute)
                : String(format: "%02d", slot.hour)
            return SlotLabel(primary: primary, secondary: "")
        }

        // 12h: no leading zero; noon/midnight both read "12".
        var hour12 = slot.hour % 12
        if hour12 == 0 { hour12 = 12 }
        let primary = subHour ? "\(hour12):\(String(format: "%02d", slot.minute))" : "\(hour12)"
        return SlotLabel(primary: primary, secondary: meridiem(hour: slot.hour, locale: locale))
    }

    private static func meridiem(hour: Int, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbol = hour < 12 ? formatter.amSymbol : formatter.pmSymbol
        return (symbol ?? "").lowercased(with: locale)
    }

    // MARK: - Date slot

    private static func dateLabel(for slot: Slot, timeZone: TimeZone, locale: Locale) -> SlotLabel {
        SlotLabel(
            primary: formatted(slot.instant, template: "d", timeZone: timeZone, locale: locale),
            secondary: formatted(slot.instant, template: "EEE", timeZone: timeZone, locale: locale)
        )
    }

    private static func formatted(
        _ instant: Date,
        template: String,
        timeZone: TimeZone,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale)
            ?? template
        return formatter.string(from: instant)
    }

    // MARK: - Zone tag

    private static func utcOffsetTag(secondsFromGMT: Int) -> String {
        let sign = secondsFromGMT < 0 ? "-" : "+"
        let magnitude = abs(secondsFromGMT)
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        return minutes == 0
            ? "UTC\(sign)\(hours)"
            : "UTC\(sign)\(hours):\(String(format: "%02d", minutes))"
    }
}
