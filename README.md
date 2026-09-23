<p align="center">
  <img src="assets/icon.png" alt="Time Strip" width="128" height="128">
</p>

<h1 align="center">Time Strip</h1>

<p align="center">
  A macOS widget that lines several time zones up on one grid, so a single
  marker reads the same instant in every city. Native macOS, no third-party
  dependencies.
</p>

<p align="center">
  <a href="https://github.com/lysyi3m/time-strip/actions/workflows/ci.yml">
    <img src="https://github.com/lysyi3m/time-strip/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
</p>

<p align="center">
  <img src="assets/screenshot-light.png" alt="Time Strip widget, light mode" width="49%">
  <img src="assets/screenshot-dark.png" alt="Time Strip widget, dark mode" width="49%">
</p>

## Features

- **Two to seven time zones**, each a horizontal day/night-shaded ribbon.
- **Absolute-time alignment** — every column is one instant, so *now* is a single vertical line across every city.
- **Medium and Large** sizes — up to four cities on Medium, seven on Large.
- **Configure on the widget** — right-click ▸ *Edit Widget* to choose cities and drag to reorder.
- **12- or 24-hour** clock, following your system setting.
- **Light and dark**, with continuous time-of-day shading and the current hour marked.

## Requirements

- macOS 26 or later
- Xcode 26 or later and XcodeGen, to build

## Build & run

```bash
brew install xcodegen        # one-time
cp .env.example .env         # one-time; set DEVELOPMENT_TEAM to your Apple Team ID
make generate                # regenerate "Time Strip.xcodeproj" from project.yml
open "Time Strip.xcodeproj"  # then press ⌘R
```

To install the widget without Xcode, run `make install`: it builds signed, copies the app
to `/Applications`, and registers the widget.

Run `make` to list the other tasks (`test`, `build`, `install`, `uninstall`, `clean`).

`Time Strip.xcodeproj` is generated from [`project.yml`](project.yml); it is gitignored and must not
be hand-edited. `make generate` projects `DEVELOPMENT_TEAM` from `.env` into
`Config/Local.xcconfig`, so Xcode and `xcodebuild` sign with the same team.

## How it works

Every column across all rows is one shared UTC instant, stepped by a fixed
3600 s rather than "add one clock hour" — so *now* stays a single straight line
and DST changes or sub-hour zones (e.g. UTC+5:30) never skew the grid. That grid
math, the locale-aware 12/24-hour formatting, and the OS-sourced zone catalog
live in the UI-free, unit-tested `TimeStripKit` framework. The SwiftUI ribbon is
fully responsive, filling whatever bounds each widget family provides.

## Project structure

| Path | Purpose |
| --- | --- |
| `Sources/Kit/` | `TimeStripKit` — UI-free core: time engine, formatter, zone catalog, models |
| `Sources/UI/` | `TimeStripUI` — SwiftUI ribbon view, palette, widget background |
| `Sources/Widget/` | WidgetKit extension: timeline provider + `AppIntent` configuration |
| `Sources/App/` | Minimal host app (onboarding window) |
| `Tests/` | Unit tests (`@testable import TimeStripKit` / `TimeStripUI`) |
| `Config/` | `Base.xcconfig`; `make generate` writes the rest (git-ignored) |

## Testing

No setup required — the tests build their own fixtures and pull zones from the OS:

```bash
make test
```

## License

The code is MIT — see [LICENSE](LICENSE). The app's name and icon are reserved; see
[TRADEMARKS.md](TRADEMARKS.md).
