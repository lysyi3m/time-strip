<h1 align="center">Time Strip</h1>

<p align="center">
  A native macOS widget that shows 2–7 time zones as day/night-shaded horizontal
  "ribbons," aligned so one vertical marker reads the same instant across every
  city. No third-party dependencies.
</p>

<!-- Add assets/icon.png and a screenshot here before release, e.g.:
<p align="center"><img src="assets/screenshot.png" alt="Time Strip widget" width="80%"></p>
-->

## What it is

Time Strip is a **widget** (there's no real app UI beyond a one-screen onboarding).
Each city is a horizontal ribbon over a `now −2h … +hours` window; every column is
one absolute instant, so a single vertical line reads the current time in each
zone at a glance. Time-of-day is shaded by a continuous night → day → dusk
intensity ramp, and the current hour is marked with a frosted-glass indicator.

- **Medium** widget — up to 4 cities.
- **Large** widget — up to 7 cities.
- Configure cities right on the widget (**Edit Widget**), with drag-to-reorder.

## Download

> **⚠️ Distribution note.** macOS only lets a **widget extension** register on a
> Mac when its containing app is trusted. A signed-and-**notarized** build (an
> Apple Developer Program membership) is required for the widget to appear on
> *other people's* Macs. Until this is notarized, the recommended way to run it
> is to **build it yourself** (below) — a downloaded, un-notarized build will
> open the app, but its widget may not show up in Edit Widgets.

Once notarized, download the latest `.dmg` from the
[**Releases**](https://github.com/lysyi3m/time-strip/releases/latest) page and
drag **Time Strip** into Applications.

## Add the widget

1. Open **Notification Center** (or right-click the desktop) → **Edit Widgets**.
2. Find **Time Strip** and add it at **Medium** or **Large**.
3. Right-click the widget → **Edit Widget** to choose and reorder your cities.

## Requirements

- macOS 15 (Sequoia) or later
- Xcode 16+ and `xcodegen` (to build)

## Build & run

```bash
brew install xcodegen         # one-time
make generate                 # regenerate "Time Strip.xcodeproj" from project.yml
open "Time Strip.xcodeproj"   # select your signing team, then ⌘R
```

To install the widget locally without Xcode, set your `DEVELOPMENT_TEAM` in
`project.yml` and run `make install` (builds signed → `/Applications` → registers
the widget). Run `make` to list all tasks (`generate`, `test`, `build`,
`install`, `dmg`, `clean`).

The Xcode project is generated from [`project.yml`](project.yml) — it is
gitignored and must not be hand-edited.

## How it works

The load-bearing part is the **absolute-time alignment**: every column across all
rows is one shared UTC instant stepped by a fixed 3600 s (not "add one clock
hour"), so `now` is a single straight vertical line and DST transitions / sub-hour
zones (e.g. UTC+5:30) never skew the grid. That grid math — plus solar-free
wall-clock coloring, locale-correct 12h/24h formatting, and the OS-sourced zone
catalog — lives in the UI-free, unit-tested `TimeStripKit` framework. The SwiftUI
ribbon layout is fully responsive: it fills whatever bounds the widget family
gives it, so Medium (short) and Large (tall) share one layout that differs only in
how many rows it shows.

City data comes entirely from the OS (`TimeZone.knownTimeZoneIdentifiers`) — there
is no bundled dataset and no attribution to carry.

## Project structure

| Path | Purpose |
| --- | --- |
| `Sources/Kit/` | `TimeStripKit` — UI-free core: time engine, formatter, zone catalog, models |
| `Sources/UI/` | `TimeStripUI` — SwiftUI ribbon view, palette, widget background |
| `Sources/Widget/` | WidgetKit extension: timeline provider + `AppIntent` configuration |
| `Sources/App/` | Minimal host app (onboarding window) |
| `Tests/` | Unit tests (`@testable import TimeStripKit` / `TimeStripUI`) |

## Testing

```bash
make test
```

No setup required — the tests build their own fixtures and zones come from the OS.

## License

MIT — see [LICENSE](LICENSE).
