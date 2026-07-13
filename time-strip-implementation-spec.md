# Time Strip — implementation spec

> Source of truth for the build. Where this spec describes a flat file layout and
> `project.yml` describes targets, **`project.yml` wins** (see §4). Work proceeds in
> phases per `CLAUDE.md`: do the named phase(s), then stop for review.

---

## 1. What Time Strip is

A native macOS **widget** that shows 2–5 time zones as horizontal, day/night-shaded
"ribbons," aligned so a single vertical marker reads the *same instant* across every
city. The visible window is narrow — the current hour −2h to +5h (~8 columns) — a
glanceable "is now a reasonable time to reach these people, and what's it o'clock for
them?" reference. Not a day planner.

The look and interaction are fully specified in the companion **design brief**
(`timezone-ribbon-widget-design-brief.md`); this spec covers structure, engines, and
build order. Final visual details will arrive as designer output — build the view to
the brief's structural rules and keep styling swappable.

## 2. Goals / non-goals

**Goals**
- A WidgetKit widget rendering the ribbon per the design brief, correct across DST,
  half-hour/45-min offsets, and day boundaries.
- Solar-accurate day/twilight/night shading from each city's coordinates.
- Native widget configuration (city selection) via the system "Edit Widget" UI — no
  in-app settings screen.
- 12h/24h following the OS locale automatically; abbreviation-vs-`UTC±N` zone tags.

**Non-goals (v1)**
- No menu-bar app, no main-window ribbon, no interaction/animation (it's a static
  snapshot widget).
- No iCloud sync, accounts, networking, or analytics.
- No Large/Medium layouts — **Extra Large only** for v1 (§3). A condensed Large is a
  future item.

## 3. Platform & tech constraints

- **Deployment target: macOS 15.0+.** Baseline for AppIntent-based widget config.
- Swift + SwiftUI + WidgetKit. No third-party dependencies; the only bundled asset is
  the city dataset (§5).
- System font **SF Pro** only; two weights (regular 400 / medium 500). Min text 11pt.
- **Primary (only) widget family for v1: `.systemExtraLarge`** (~726×354 pt). The
  8-column ribbon plus label rail needs the width; Medium/Large can't hold it legibly.
- **Timeline granularity: hourly.** Slots are hour-granular and the now-frame sits on
  the hour, so content only changes on the hour. Bake ~24 hourly entries per
  `getTimeline`, refresh policy `.atEnd` (≈1 scheduled reload/day). Config changes
  trigger an unbudgeted `reloadTimelines(ofKind:)`. (Dropping to 30-min later is a
  one-line change.)
- **No App Group needed for v1.** Selected cities live in the widget's configuration
  intent; the city dataset is a bundled read-only resource. Add
  `group.com.mlkshkvch.timestrip` only if a future host-app feature must share mutable
  state with the widget.

## 4. Architecture & targets

Repository: `github.com/lysyi3m/time-strip` (empty at kickoff; repo root = the tree
below). In-repo this file is `implementation-spec.md`.

`project.yml` (XcodeGen) refines the layout into **three targets + a test bundle**,
mirroring the PDF Unpack shape. Bundle IDs under `com.mlkshkvch.*`.

- **`TimeStripKit`** — framework, `Sources/Kit/`. The **UI-free core**: models, the time
  engine, the solar engine, and formatting. **No SwiftUI / WidgetKit / AppKit imports.**
  Bundles `cities.json` as a resource and exposes a loader. Everything the app/widget
  needs is `public`. This is where all P1–P3 logic and all unit tests live.
- **`Time Strip`** — app, `Sources/App/`. Minimal host app (onboarding window only, §
  Phase 7). Hosts and embeds the widget extension. `import TimeStripKit`.
- **`TimeStripWidget`** — widget extension, `Sources/Widget/`. WidgetKit + SwiftUI: the
  ribbon views + Xcode previews, the `TimelineProvider`, and the
  `WidgetConfigurationIntent` + `CityEntity`/`EntityQuery`. `import TimeStripKit`.
  Embedded in `Time Strip`.
- **`TimeStripTests`** — unit tests, `Tests/`. `@testable import TimeStripKit`. Not hosted
  by the app, so the test runner isn't sandboxed and can read fixtures directly.

The ribbon SwiftUI view lives in the widget extension for v1. If the host app later
grows a ribbon view, extract the views into a shared `Time StripUI` framework then — not
now.

```
time-strip/
  implementation-spec.md      ← this file (source of truth)
  CLAUDE.md                   ← conventions + phased working agreement
  project.yml                 ← XcodeGen (targets, bundle IDs)
  .gitignore
  Config/                     ← generated Info.plists / entitlements (gitignored)
  Sources/
    Kit/                      ← TimeStripKit (UI-free core)
    App/                      ← Time Strip (host app)
    Widget/                   ← TimeStripWidget (extension)
  Resources/
    cities.json               ← bundled city dataset (§5)
  Tests/                      ← TimeStripTests
  tools/                      ← dataset build script (§5)
```

## 5. Data asset — city dataset

Solar shading needs coordinates and the picker needs friendly names; `TimeZone`
identifiers give neither. Bundle a curated **`cities.json`**.

- **Schema** (array of):
  ```
  { "name": "Warsaw", "country": "Poland", "admin1": "Mazovia",
    "tzid": "Europe/Warsaw", "lat": 52.2297, "lon": 21.0122, "pop": 1790658 }
  ```
- Keys: display name, country (and optional admin1 for disambiguation), IANA `tzid`,
  latitude, longitude, population (for search ranking / picking a canonical city per
  name collision).
- **Source:** a trimmed GeoNames extract (e.g. cities with population above a
  threshold), license **CC-BY** → carry attribution in the host app's about/onboarding.
- `tools/build_cities.py` downloads/filters the GeoNames dump into `cities.json` and is
  committed so the dataset is reproducible; the generated `cities.json` is also
  committed (it's static and license-clean).
- `TimeStripKit` exposes `CityDatabase` (load, search-by-prefix ranked by population,
  lookup by id) used by both the solar engine and the widget's `EntityQuery`.

## 6. Structural rules the view must honor (from the design brief)

These are correctness constraints, not styling. The design brief is authoritative; the
load-bearing ones:

1. **Columns align by absolute time.** Every column is one UTC instant; each row shows
   its local clock for that instant. Rows share one column grid; `now` is one straight
   vertical line through all rows.
2. **Constant grid stride.** The day-boundary notch is *inset* — carved from the two
   adjacent slots — never *inserted* as width. Column centers must not move.
3. **The now-frame position is fixed** (window is always −2h/+5h around now → `now` is
   always column index 2). Labels/shading reflow beneath a stationary frame each bake.
4. **Static snapshot.** No hover/press/scrub/animation states exist.
5. **Number-over-label rhythm everywhere.** Hour slots (number over optional meridiem)
   and the new-day slot (day-of-month over weekday) share one baseline grid.
6. **Shading = solar** day/twilight/night, and must read from **lightness alone**
   (desaturation-safe), light + dark appearance both supported.
7. **12h/24h from the OS locale** (`DateFormatter.dateFormat(fromTemplate:"j",…)`); 12h
   slots are two-line, 24h effectively one line (empty label row).
8. **Zone tag:** conventional abbreviation when one exists, else `UTC±N`
   (`TimeZone.abbreviation` already branches this way — normalize its `GMT±N` fallback
   to `UTC±N`). Per-city manual label override available.

## 7. Build plan (phase overview)

Each phase is independently verifiable and ends with a review stop. Pure phases
(P1–P3) land before any UI — that's the correctness core, fully unit-testable.

- **P0 · Scaffold** — targets generate; app builds to a placeholder window; widget
  appears in the gallery as a placeholder. *(detailed below)*
- **P1 · Time engine (pure)** — `City`, `Column`, `RibbonSnapshot`; window/column
  computation; per-row day-boundary detection. *Done: tests pass across multi-zone, a
  DST-transition day, and a half-hour-offset zone.*
- **P2 · Solar engine (pure)** — sunrise/sunset/civil-twilight from lat·lon·date →
  day/twilight/night per column. *Done: classification matches reference within
  tolerance.*
- **P3 · Formatting (pure)** — 12/24h detection, hour + meridiem, date slot,
  abbreviation-vs-`UTC±N`, per-city label override. *Done: tests pass.*
- **P4 · Ribbon view (SwiftUI, hardcoded snapshot)** — rows, day-pills, capped
  boundary, now-frame, solar shading, light/dark. *Done: previews match the mocks
  across 2–5 rows, 12/24h, boundary/none.*
- **P5 · Timeline provider** — bake hourly entries around `now`, `.atEnd` policy,
  placeholder/snapshot. *Done: widget advances correctly over time.*
- **P6 · Configuration** — `WidgetConfigurationIntent`, fixed city slots (empty =
  hidden row), `CityEntity` + `EntityQuery` over `CityDatabase`, per-city label
  override. *Done: cities selectable via Edit Widget.*
- **P7 · Host app** — minimal onboarding window + GeoNames attribution. *Done.*
- **P8 · Polish** — desaturated/tinted appearance, localization, accessibility, empty
  states. *Done.*

---

## Phase 0 — Scaffold

**Objective:** the whole thing generates and builds; the app opens a placeholder
window; the widget shows a placeholder in the gallery. No real logic yet.

**Tasks**
1. Create the folder structure from §4 (`Sources/Kit`, `Sources/App`, `Sources/Widget`,
   `Tests`, `Resources`, `Config`, `tools`) with minimal stub files:
   - `Sources/Kit/TimeStrip.swift` — trivial public symbol so the framework compiles,
     e.g. `public enum TimeStrip { public static let schemaVersion = 1 }`.
   - `Sources/App/TimeStripApp.swift` — `@main` SwiftUI `App` with one window rendering a
     placeholder (`Text("Time Strip")`).
   - `Sources/Widget/TimeStripWidget.swift` — a minimal `StaticConfiguration` widget
     limited to `.systemExtraLarge`, whose provider returns a single placeholder entry
     and whose view renders `Text("Time Strip")`. (Upgraded to `AppIntentConfiguration` in
     P6.)
   - `Sources/Widget/TimeStripWidgetBundle.swift` — `@main WidgetBundle` exposing the
     widget.
   - `Tests/SmokeTests.swift` — one passing test that does `@testable import TimeStripKit`
     and asserts `TimeStrip.schemaVersion == 1`.
   - `Resources/cities.json` — a tiny placeholder (`[]` or 3–4 hand-written entries) so
     the resource bundles; the real dataset lands in P1/P5 via `tools/build_cities.py`.
2. Author `project.yml` (XcodeGen): the four targets from §4, deployment target
   macOS 15.0, bundle IDs `com.mlkshkvch.timestrip`, `com.mlkshkvch.timestrip.widget`,
   `com.mlkshkvch.timestrip.tests`; the widget extension embedded in the app; a `Time Strip`
   scheme that runs the app and runs `TimeStripTests` on `test` (so no app signing is
   needed to run tests). `TimeStripKit` bundles `Resources/cities.json`.
3. Author `.gitignore`: ignore `*.xcodeproj/`, `Config/*.plist`, `Config/*.entitlements`
   (all regenerated by XcodeGen), `build/`, `DerivedData/`, `.DS_Store`, Python
   `__pycache__/`, `.venv/`.
4. Generate and build:
   ```
   xcodegen generate
   xcodebuild -project "Time Strip.xcodeproj" -scheme "Time Strip" build CODE_SIGNING_ALLOWED=NO
   ```
5. Do **not** commit the generated `.xcodeproj` (gitignored).

**Done when**
- `xcodegen generate` succeeds and `xcodebuild … build` is green.
- Running the app shows the placeholder window.
- The widget appears in the widget gallery at Extra Large as a placeholder.
- `TimeStripTests` passes.

**Stop for review.**

---

## Phase 1 — Time engine (pure, no UI)

**Objective:** turn `(now, cities, window)` into a fully-resolved structural snapshot —
columns, per-city rows, per-slot local time, day-boundary flags — with zero UI and zero
solar logic (period is a placeholder here, filled in P2). This is the phase where the
subtle correctness bugs live (DST, sub-hour offsets, midnight rollover), so it lands
first and is covered by tests before any pixel exists.

All of this is in `Sources/Kit/` (`TimeStripKit`), UI-free.

### 1.1 Public model

```swift
public struct GeoCoordinate: Codable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
}

public struct City: Identifiable, Codable, Hashable, Sendable {
    public let id: String          // stable slug, e.g. "europe-warsaw"
    public let name: String
    public let country: String
    public let admin1: String?
    public let tzid: String        // IANA identifier
    public let coordinate: GeoCoordinate
    public let population: Int
    public var timeZone: TimeZone { TimeZone(identifier: tzid) ?? .gmt }
}

public enum DayPeriod: String, Codable, Hashable, Sendable {
    case day, twilight, night      // real values assigned in P2; P1 uses .day placeholder
}

public struct Slot: Hashable, Sendable {
    public let columnIndex: Int
    public let instant: Date        // the absolute column instant (shared across rows)
    public let hour: Int            // local hour 0...23 at `instant` in the city's tz
    public let minute: Int          // local minute (0 except sub-hour-offset zones)
    public let isDayStart: Bool     // first slot of a new local day → render date, not hour
    public var period: DayPeriod    // placeholder (.day) in P1
}

public struct RowSnapshot: Hashable, Sendable {
    public let city: City
    public let slots: [Slot]        // one per column, count == window.columnCount
}

public struct RibbonSnapshot: Hashable, Sendable {
    public let now: Date
    public let columnInstants: [Date]   // absolute instants, one per column
    public let nowColumnIndex: Int      // == window.hoursBefore
    public let rows: [RowSnapshot]
}

public struct WindowSpec: Sendable, Equatable {
    public let hoursBefore: Int         // default 2
    public let hoursAfter: Int          // default 5
    public init(hoursBefore: Int = 2, hoursAfter: Int = 5) { … }
    public var columnCount: Int { hoursBefore + hoursAfter + 1 }   // default 8
}

public enum RibbonEngine {
    public static func snapshot(
        now: Date,
        cities: [City],
        window: WindowSpec = .init(),
        referenceIndex: Int = 0
    ) -> RibbonSnapshot
}
```

### 1.2 Computation rules (these encode the structural invariants from §6)

**Column instants — step by absolute hours, not clock hours.**
1. `referenceTZ = cities[referenceIndex].timeZone` (default: first city = the "home"
   row).
2. Floor `now` to the start of its hour *in `referenceTZ`* → `nowHourStart` (an absolute
   `Date`). Use a `Calendar(identifier: .gregorian)` with `timeZone = referenceTZ` and
   `dateComponents`/`date(from:)`, or `dateInterval(of: .hour, for: now)`.
3. `columnInstants[i] = nowHourStart.addingTimeInterval(Double(i - hoursBefore) * 3600)`
   for `i in 0..<columnCount`. **Advance by a fixed 3600 s**, never by "add one clock
   hour." This guarantees every column is an equal absolute step, so the columns stay
   aligned across rows (invariant §6.1). A consequence, which is *correct*: on the
   reference zone's own DST-transition day, its displayed hours will show the skip
   (spring: 1→3) or repeat (fall) — that's truthful wall-clock behavior.
4. `nowColumnIndex = hoursBefore` (the current-hour column, containing `now`).

**Per-slot local time.** For each city and each column `i`, render `columnInstants[i]`
in `city.timeZone`:
- `hour`, `minute` = local hour/minute components at that instant. Whole-offset zones
  yield `minute == 0`; sub-hour zones (Asia/Kolkata +5:30, Asia/Kathmandu +5:45, parts
  of Australia) yield `minute == 30`/`45`. Alignment is unaffected — minutes are a
  *display* concern handled in P3; the columns remain the same absolute instants.
- A city that itself transitions DST inside the window simply shows its own skipped or
  repeated hour in the affected slots — no special-casing needed, because we render each
  absolute instant independently through its tz.

**Day-boundary flag (per city, per §6.2/§6.5 — this drives the date slot).**
- Compute each slot's local day (`year/month/day` in the city's tz).
- `isDayStart = (i == 0) ? (localHour == 0) : (localDay(i) != localDay(i-1))`.
- At most one, sometimes zero, `isDayStart` per row within a narrow window; different
  rows flip at different column indices (or not at all). The renderer (P4) shows the
  date instead of the hour where `isDayStart == true`; the actual date string is
  produced in P3 from the slot's local components.

**No count enforcement.** The engine accepts any `cities.count`; the 2–5 constraint is a
UI/configuration concern (P6), not a core concern. Tests may use any count.

### 1.3 Tests (`Tests/`, `@testable import TimeStripKit`)

Build each expectation independently from `TimeZone`/`Calendar` (don't hardcode magic
numbers that could drift). Cover:

1. **Alignment & shape.** `now` on a normal day, cities = [Warsaw, London, New York,
   Singapore]. Assert: `columnInstants.count == 8`; consecutive instants differ by
   exactly 3600 s; `nowColumnIndex == 2`; for each row, each slot's `hour` equals the
   independently-computed local hour of that instant. This is the absolute-time-alignment
   guarantee.
2. **DST transition (spring forward).** Pick a `now` on the EU DST-change Sunday so the
   window straddles Warsaw's 02:00→03:00 jump. Assert Warsaw's slot hours show the
   skipped hour (no `02`), while `columnInstants` remain uniformly 3600 s apart and other
   rows stay aligned.
3. **DST transition (fall back).** Symmetric case: assert the repeated hour appears and
   alignment holds.
4. **Sub-hour offset.** Include Asia/Kolkata (+5:30). Assert its slots have `minute == 30`
   with consecutive `hour` values, and that `columnInstants` are identical to case 1
   (the sub-hour zone does not perturb the shared grid).
5. **Day boundary.** Construct a `now` so exactly one city's window crosses local
   midnight. Assert exactly one slot has `isDayStart == true`, at the expected index, and
   its local components are the new day. Assert rows without a crossing have zero
   `isDayStart`.
6. **Reference index.** Changing `referenceIndex` to a sub-hour zone floors the columns to
   that zone's hour; assert the grid shifts accordingly and whole-offset rows then carry
   the `:30` minutes. (Documents the behavior; default reference is index 0.)

**Done when:** all six tests pass; `RibbonEngine.snapshot` is `public` and UI-free; no
SwiftUI/WidgetKit import anywhere in `Sources/Kit`.

**Stop for review.**

---

## Phase 2 — Solar engine (pure, no UI)

**Objective:** replace each slot's placeholder `period` with a real `.day` / `.twilight`
/ `.night`, computed from the sun's position at that slot's absolute instant and the
city's coordinate. Pure math, no network. In `Sources/Kit/`.

### 2.1 Approach — classify by solar elevation angle

Do **not** compute sunrise/sunset times and compare — that needs polar-edge branching.
Instead compute the **sun's elevation angle** directly at the slot instant and threshold
it. This "just works" at every latitude (at the poles the elevation simply stays above
or below the thresholds all day).

- `elevation ≥ -0.833°` → **day** (sun's disk at/above the horizon, incl. refraction)
- `-6° ≤ elevation < -0.833°` → **twilight** (civil twilight; covers both dawn and dusk)
- `elevation < -6°` → **night**

Use the standard low-precision NOAA / Meeus solar-position algorithm (accuracy ≈±1 min,
far more than enough): from the instant compute Julian date → solar mean longitude and
anomaly → ecliptic longitude → declination and equation of time → local hour angle from
longitude and time-of-day → `elevation = asin(sin φ·sin δ + cos φ·cos δ·cos H)`.

Elevation depends only on absolute time + coordinate, so use `slot.instant` directly;
timezone is irrelevant to the sun's position (it's already baked into the instant).

### 2.2 Public API

```swift
public struct SolarClassifier: Sendable {
    public init() {}
    /// Sun elevation in degrees at the given instant and location.
    public func elevation(at instant: Date, coordinate: GeoCoordinate) -> Double
    /// Day / twilight / night via the thresholds above.
    public func period(at instant: Date, coordinate: GeoCoordinate) -> DayPeriod
}
```

Wire it into the engine: extend `RibbonEngine.snapshot` to fill periods, with the
classifier injectable for testing —
`snapshot(now:cities:window:referenceIndex:classifier: SolarClassifier = .init())`.
P1's placeholder `.day` becomes the classifier's result per slot.

### 2.3 Tests

1. **Noon vs midnight.** Mid-latitude city (e.g. Warsaw): local solar noon → `.day`;
   local midnight → `.night`.
2. **Twilight window.** Scan elevation around a known sunset; assert the classification
   transitions day → twilight → night in that order and that the twilight band brackets
   the −0.833°/−6° crossings.
3. **Reference cross-check.** For one city/date, assert the computed sunrise crossing
   (elevation passes −0.833° upward) is within a few minutes of a published value.
4. **Polar safety.** High-latitude city (e.g. Longyearbyen) near summer solstice → all
   slots `.day`; near winter solstice → all `.night`/`.twilight`. No crash, no NaN.
5. **Elevation sanity.** Elevation peaks near local solar noon for a mid-latitude city.

**Done when:** all tests pass; classifier is pure and UI-free; the engine populates real
periods.

---

## Phase 3 — Formatting (pure, no UI)

**Objective:** turn a `Slot` + `City` into the strings the view renders — the two-line
slot label, the date slot, and the zone tag — all locale-correct. In `Sources/Kit/`.
Locale is a parameter (the UI passes `.current`) so it's fully testable.

### 3.1 Rules

- **12h vs 24h:** `DateFormatter.dateFormat(fromTemplate:"j", options:0, locale:)?.contains("a") ?? false`. Reflects both the region default and the system 24-Hour toggle when locale is `.current`.
- **Hour slot label** (`SlotLabel(primary, secondary)`), from the slot's local `hour`/`minute`:
  - 24h, whole hour → `("07", "")` (zero-padded, two digits — keeps columns optically even).
  - 24h, sub-hour → `("07:30", "")`.
  - 12h, whole hour → `("7", "am")` / noon `("12","pm")` / midnight `("12","am")` (no leading zero).
  - 12h, sub-hour → `("7:30", "am")`.
  - `am`/`pm` come from the locale (`DateFormatter.amSymbol`/`pmSymbol`), lowercased for display.
- **Date slot** (when `slot.isDayStart`): `primary` = localized day-of-month (`"16"`),
  `secondary` = localized short weekday (`"Thu"` / `"Do"` / `"czw"`), from a locale-aware
  formatter. Same number-over-label rhythm as hour slots.
- **Zone tag:** `tag = city.timeZone.abbreviation(for: instant)`. If it matches
  `^GMT[+-]\d` (no conventional abbreviation), reformat to `UTC±N` from
  `secondsFromGMT(for: instant)` (handle `:30`/`:45` → `UTC+5:30`). Otherwise use the
  abbreviation verbatim. Instant-based, so it's DST-correct (`CET`↔`CEST`). A non-nil
  per-city **manual override** wins over both.

### 3.2 Public API

```swift
public struct SlotLabel: Hashable, Sendable { public let primary, secondary: String }

public enum RibbonFormatter {
    public static func uses12HourClock(locale: Locale) -> Bool
    public static func slotLabel(for slot: Slot, locale: Locale, is12h: Bool) -> SlotLabel
    public static func zoneTag(for city: City, at instant: Date, override: String?) -> String
}
```

### 3.3 Tests

1. **Clock detection:** `en_US` → true; `pl_PL` / `de_DE` → false.
2. **Hour labels:** 24h whole `("07","")`; 12h `("7","am")`; noon/midnight edge cases;
   sub-hour includes the minute.
3. **Date slot:** an `isDayStart` slot yields `(dayOfMonth, shortWeekday)` in the given
   locale.
4. **Zone tag:** Warsaw at a summer instant → `CEST`, winter → `CET`; Singapore →
   `UTC+8`; Kolkata → `UTC+5:30`; with override → the override string.

**Done when:** tests pass; formatting is pure and locale-injectable.

---

## Phase 4 — Ribbon view (SwiftUI, hardcoded snapshot)

**Objective:** render a fully-resolved snapshot exactly per the design brief and mocks,
driven by hardcoded fixtures (no timeline yet). In `Sources/Widget/`. This is where the
structural rules in §6 become pixels — respect them literally.

### 4.1 Composition

- `RibbonView(snapshot:, is12h:, locale:)` — the whole widget content, sized for
  `.systemExtraLarge`.
- Per row: **left rail** (city name, tail-truncated to one line; zone tag beneath) +
  **ribbon**.
- **Ribbon layout (critical):** column x-position is `railWidth + index * stride` —
  computed from the index alone, so it is **independent of day boundaries** (invariant
  §6.2). Group a row's consecutive slots by local day into **segments**; render each
  segment as a rounded-capped container (rounded outer corners; the boundary notch is the
  small inset gap between two segments) that clips its slot cells. Slot content sits at
  the fixed per-index x. **Never insert width at a boundary** — the notch is carved from
  the two adjacent cells so centers don't move.
- **Slot cell:** period-shaded background; `SlotLabel.primary` over `.secondary`
  (number-over-label). Where `slot.isDayStart`, the label is the date slot's
  (day-of-month over weekday) — same cell, same baseline grid.
- **Now-frame:** a vertical rounded-rect stroke at `nowColumnIndex`, drawn **last** (on
  top), spanning all rows. Color = primary label color (adapts light/dark).
- **Palette:** `day` / `twilight` / `night` as named colors in `Colors.xcassets` with
  light + dark variants, lightness-ordered so day/night survives desaturation (§6.6).
  These are **placeholders** pending designer tokens — keep them in one file so they swap
  cleanly.

### 4.2 Previews (the acceptance surface for this phase)

`#Preview`s covering the design-brief matrix, all from hardcoded `RibbonSnapshot`
fixtures: **2, 3, 4, 5 rows**; **12h and 24h**; a row **with** an in-window boundary and
rows **without**; **light and dark**. Verify visually against the mocks, and verify the
boundary does **not** shift column centers.

**Done when:** previews match the mocks across the full matrix in both appearances, with
the fixed-stride/inset-notch behavior confirmed.

---

## Phase 5 — Timeline provider

**Objective:** feed the view over time. In `Sources/Widget/`. Uses a temporary default
city list; P6 swaps in the configuration.

- `struct RibbonEntry: TimelineEntry { let date: Date; let snapshot: RibbonSnapshot; let is12h: Bool }`
  (snapshot already carries resolved periods; the view formats labels with `.current`).
- `getTimeline`: floor now to the hour; bake **~24 hourly entries**, each with
  `date = hourStart + n·3600` and `snapshot = RibbonEngine.snapshot(now: date, cities: defaults)`.
  Reload policy **`.atEnd`** (≈1 scheduled reload/day). Because the now-frame is fixed and
  content changes only on the hour, hourly entries suffice and the reload budget is a
  non-issue (24 entries come from one `getTimeline`).
- `placeholder` and `getSnapshot`: a representative fixture for the gallery.

**Done when:** `getTimeline` returns 24 correctly-dated entries whose snapshots advance
hour to hour (unit-testable by calling it with a fixed `now`); the widget updates over
time in the simulator/desktop.

---

## Phase 6 — Configuration (native Edit Widget)

**Objective:** let the user pick cities through the system widget editor — no in-app
settings. In `Sources/Widget/`. Migrate the widget to `AppIntentConfiguration`.

- **`CityEntity: AppEntity`** + **`CityQuery: EntityQuery`** backed by `CityDatabase`
  (§5): `suggestedEntities()` returns popular cities; string search (`entities(matching:)`)
  ranked by population; `entities(for: ids)` resolves selections. This gives the native
  searchable picker ("type *Cairo*, tap it").
- **`TimeStripConfigurationIntent: WidgetConfigurationIntent`** with **fixed city slots**:
  `@Parameter city1 … city5: CityEntity?` (slot 1 defaulted to a sensible city; 2–5
  optional). Empty slot → hidden row. Optional `label1 … label5: String?` for the
  per-city manual override (§3 zone tag). Fixed slots (not a dynamic array) because the
  native editor renders a reorderable array poorly.
- **`Provider: AppIntentTimelineProvider`** reads the intent, resolves the ordered
  non-empty cities (slot 1 = reference/home row), and bakes the timeline as in P5.
- Now-baking uses the real dataset: land `tools/build_cities.py` and the generated
  `Resources/cities.json` here (replacing the P0 placeholder), with GeoNames CC-BY.

**Done when:** adding the widget and choosing **Edit Widget** shows five searchable city
slots; selections update the ribbon; empty slots hide their rows; overrides apply.

---

## Phase 7 — Host app

**Objective:** a minimal host so the extension has a home and the user knows what to do.
In `Sources/App/`.

- A single onboarding window: one screen explaining "Add the **Time Strip** widget at
  **Extra Large** from Notification Center or your desktop, then right-click → **Edit
  Widget** to choose your cities," a note that configuration lives in the widget (there's
  no in-app settings), and the **GeoNames CC-BY attribution**.
- No deep-link into the widget editor (no public API exists) — the guidance is
  instructional only.
- Plain windowed app (not an agent). It exists to host/embed the extension.

**Done when:** the app builds, runs, and shows the onboarding window with attribution.

---

## Phase 8 — Polish

**Objective:** the production niceties.

- **Desaturated / tinted rendering:** verify the palette and now-frame read in the
  desktop widget's Monochrome/Automatic (tinted) modes — day/night must carry on
  lightness alone. Apply `.widgetAccentable` where sensible; check `AccentedRenderingMode`.
- **Localization:** user-facing strings (onboarding) in a String Catalog; confirm slot /
  date / zone formatting follows locale; verify longer localized weekday and city-name
  truncation don't clip.
- **Accessibility:** a concise VoiceOver summary on the widget (e.g. "Warsaw 3 PM,
  London 2 PM, New York 9 AM") via `.accessibilityLabel`.
- **Edge / empty states:** fewer than 2 cities configured → a gentle "Choose cities"
  prompt; polar all-day/all-night rows render sensibly; no in-window boundary is fine.

**Done when:** monochrome proof is legible; strings localized; VoiceOver summary present;
empty-config and polar states handled.

---

## Appendix — v1 decisions locked

- macOS **15.0+**; SwiftUI + WidgetKit; no third-party deps; SF Pro only.
- **Extra Large** widget family only; **hourly** timeline (`.atEnd`).
- Shading = **solar elevation** (day ≥ −0.833° > twilight ≥ −6° > night), lightness-safe.
- Columns step by **absolute 3600 s**; boundary notch is **inset, never inserted**.
- 12/24h from **OS locale**; zone tag = **abbreviation else `UTC±N`**; per-city override.
- City data = bundled **GeoNames (CC-BY)** `cities.json`.
- **No App Group** in v1 (config lives in the widget intent).
- Open future items (not v1): condensed Large layout; optional working-hours overlay; a
  main-window ribbon (would motivate extracting a shared `TimeStripUI` framework).
