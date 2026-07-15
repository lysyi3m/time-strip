import Foundation

/// Resolves a widget's configured city slots into the rows to render — the pure decision behind
/// the timeline provider, kept in Kit so it's unit-testable without the widget target.
public enum RibbonRows {

    /// What the widget should show for a given configuration.
    public enum Resolution: Equatable {
        /// Enough distinct zones to compare — render these rows, in order.
        case ribbon([City])
        /// Fewer than two distinct zones configured — show the setup prompt instead.
        case setupNeeded
    }

    /// Resolve configured cities into a `Resolution`:
    /// - **deduplicate by `tzid`** (first occurrence wins, preserving slot order) so the same zone
    ///   chosen twice neither renders identical ribbons nor satisfies the two-zone minimum;
    /// - **0 distinct** → fall back to `defaults` (a fresh widget still looks populated);
    /// - **1 distinct** → `setupNeeded` (a comparison needs at least two zones);
    /// - **2+ distinct** → those rows.
    ///
    /// Deduplication keeps the first slot's manual label for a repeated zone.
    public static func resolve(configured: [City], defaults: [City]) -> Resolution {
        var seen = Set<String>()
        let unique = configured.filter { seen.insert($0.tzid).inserted }
        switch unique.count {
        case 0:  return .ribbon(defaults)
        case 1:  return .setupNeeded
        default: return .ribbon(unique)
        }
    }
}
