# Time Strip — working rules for coding agents

Native macOS widget (WidgetKit + SwiftUI) that lines several time zones up on one grid, so a
single vertical marker reads the same instant in every city.

## Ground rules

Shared by `recogs`, `time-strip` and `pdf-unpack`. Where a repo-specific section below
contradicts a rule here, the repo-specific rule wins — and say so when you notice it.

- **One toolchain.** macOS 26+ (iOS 26+ where there is an iOS target), Swift 6 language mode,
  Xcode 27. CI pins the same Xcode, so code that builds locally must build there too.
- **XcodeGen owns the project.** `project.yml` is the source of truth. Never hand-edit the
  generated `.xcodeproj`. Never commit it, `Config/*.plist` or `Config/*.entitlements`. Run
  `make generate` after every `project.yml` change.
- **The Makefile is the entry point.** Run `make` to list targets. Prefer `make test` and
  `make build` over hand-written `xcodebuild` lines; the Makefile carries the flags that work.
- **No third-party runtime dependencies.** Apple frameworks only. Build tooling (XcodeGen,
  anything under `tools/`) is exempt because it does not ship. If you believe a runtime
  dependency is needed, stop and ask.
- **Logic lives in the `*Kit` framework.** `Sources/Kit` is UI-free and holds the testable
  core — no `SwiftUI`, `AppKit`, `UIKit` or `WidgetKit` imports there. App and extension
  targets stay thin.
- **Tests run offline, unsigned and unhosted.** They need no network, credentials or signing.
  A test that needs any of those belongs somewhere else.
- **Secrets never enter the repo.** No tokens, keys or Team IDs in tracked files. Each repo
  states where its own secrets live.
- **Signing reads `.env`.** Set `DEVELOPMENT_TEAM` in `.env` (copy `.env.example`).
  `make generate` projects it into the git-ignored `Config/Local.xcconfig`, which
  `Config/Base.xcconfig` includes, so `xcodebuild` and ⌘R sign with the same team. Never pass
  the team on the command line or commit it.
- **One slug per app.** Lowercase the app name and turn spaces into hyphens (`PDF Unpack` →
  `pdf-unpack`). The slug is the repo name, the App Store Connect SKU, and the last part of the
  bundle ID, `com.mlkshkvch.<slug>`; other targets append to it (`…<slug>.kit`). The bundle ID
  and SKU are permanent once a build is uploaded.
- **One word per concept.** The Terminology section is binding for UI strings, code
  identifiers and docs alike. Do not introduce synonyms for variety.

## Stack

- SwiftUI + WidgetKit. No iOS target.
- Four product targets: `TimeStripKit` (`Sources/Kit`, UI-free core), `TimeStripUI`
  (`Sources/UI`, shared SwiftUI views), `TimeStripWidget` (`Sources/Widget`, the extension),
  and `Time Strip` (`Sources/App`, the host app that embeds the widget).
- `Sources/UI` exists because a widget-extension target cannot host SwiftUI canvas previews on
  macOS. Keeping the views in a framework lets the app preview them.
- Two test bundles: `TimeStripTests` covers `TimeStripKit`, `TimeStripUITests` covers the
  public layout math in `TimeStripUI`.

## Terminology

- **City** — one selected time zone, rendered as one row. Identified by its IANA tzid.
- **Ribbon** — the shaded bar for one city.
- **Rail** — the fixed-width name column at the left of each row.
- **Column** — one hour cell. Every column is one absolute instant, shared by all rows.
- **Now-column** — the column holding the current hour.
- **Reference city** — the first configured city. The grid floors to its local hour.

## Invariants

These come from how the widget must render and stay correct. Do not "simplify" them away.

1. **Absolute-time column alignment.** Every column is one absolute instant, so *now* is one
   straight vertical line through every row. Rows share one column grid.
2. **Columns advance by a fixed 3600 s**, never by "add one clock hour". This is what keeps DST
   changes and sub-hour zones (UTC+5:30) from skewing the grid.
3. **A day boundary is marked by the date slot, not a gap.** `isDayStart` makes a slot render
   its date instead of its hour. Column centers never move.
4. **Static snapshot.** No hover, press, scrub or animation — it is a widget.
5. **Responsive layout.** The ribbon fills whatever bounds the widget family provides, matching
   Apple's content margins, rather than scaling a fixed design. Cells stay landscape: when the
   height would make a cell taller than its width, rows are centered instead of stretched.
6. **The rail is a fixed share of the width**, hard-capped at half, never "whatever is left
   after the name". A long city name shrinks or truncates within the rail and never squeezes
   the cells.
7. **Shading is a pure function of local clock hour.** The engine carries no solar or
   coordinate data, and the shading must stay readable from lightness alone, in light and dark.

## Secrets

Nothing sensitive ships in this repo. The Apple Team ID lives in `.env`, per the ground rule.

## Housekeeping

- **Quote the project path** in every command — `"Time Strip.xcodeproj"` contains a space.
- **A widget only registers when the bundles are Team-signed and sandboxed.** An ad-hoc
  signature does not register with `chronod`, and macOS requires the App Sandbox entitlement on
  both the extension and its container app. Never re-sign a built app ad hoc: it drops the
  entitlements.
- **`make install` needs one prior Xcode ⌘R.** With a free or personal team, the development
  provisioning profile that activates the widget is only created by running from Xcode once.
  After that, `make install` is the fast way to push rebuilds.
- **The widget configuration caps at 7 cities** (`TimeStripConfigurationIntent.maxCities`). How
  many actually render depends on the family: fewer on `.systemMedium`, more on `.systemLarge`.
- Tests build their own fixtures and read zones from the OS. Never hardcode an offset or a
  magic number that `TimeZone` or `Calendar` could drift away from.
