import Foundation

/// Resolves a widget's configured city slots into the rows to render — the pure decision behind
/// the timeline provider, kept in Kit so it's unit-testable without the widget target.
public enum RibbonRows {

    /// What the widget should show for a given configuration.
    public enum Resolution: Equatable {
        /// Enough distinct cities to compare — render these rows, in order.
        case ribbon([City])
        /// Fewer than two distinct cities configured — show the setup prompt instead.
        case setupNeeded
    }

    /// Resolve configured cities into a `Resolution`:
    /// - **deduplicate by zone and name** (first occurrence wins, preserving slot order) so the
    ///   same city chosen twice neither renders twice nor satisfies the two-city minimum. The name
    ///   is what the rail shows, so this also collapses a pre-table zone row and the table city of
    ///   the same name. Two cities in one zone (Seattle, Los Angeles) stay two rows: a row is a
    ///   city, not a zone;
    /// - **0 distinct** → fall back to `defaults` (a fresh widget still looks populated);
    /// - **1 distinct** → `setupNeeded` (a comparison needs at least two cities);
    /// - **2+ distinct** → those rows.
    public static func resolve(configured: [City], defaults: [City]) -> Resolution {
        var seen = Set<String>()
        let unique = configured.filter { seen.insert("\($0.tzid)|\($0.name)").inserted }
        switch unique.count {
        case 0:  return .ribbon(defaults)
        case 1:  return .setupNeeded
        default: return .ribbon(unique)
        }
    }
}
