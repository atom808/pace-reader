# Pace Reader

Telemetry analysis for **Le Mans Ultimate** — lap analysis, track maps, and stint insight,
fully offline.

LMU exports each session as a `.duckdb` file. Pace Reader opens one locally and turns raw
per-sample telemetry into lap times, driver-input traces, and track position. Nothing leaves
the machine.

See [SPEC.md](SPEC.md) for the product and technical spec — it is the source of truth for
what the data actually contains, and it is written as confirmed fact checked against real
recordings rather than as assumption.

## Status

Phase 1 (MVP) is complete: file import, Session Overview, the lap table, the single-lap
telemetry trace, and the 2D track map, on desktop and web. Phase 2 is under way — the
Events Log (§8.12), the reference-lap overlay with its delta trace (§8.4) and the
fuel/energy view (§8.7) are built; tires/brakes, per-lap trend charts and the session
library index are still to come. See SPEC.md §14.

## Toolchain

The project tracks the newest Flutter stable and the newest package majors, on purpose.
`.fvmrc` pins the exact SDK release, `pubspec.yaml`'s `environment` holds the same minor
release as a floor, and `pubspec.lock` is committed.

The SDK comes from [FVM](https://fvm.app), so this project can run ahead of whatever a
machine's global `flutter` is pinned to for other work:

```bash
brew install fvm   # once
fvm install        # the release .fvmrc pins
```

Every command below then runs as `fvm flutter …` / `fvm dart …`. Plain `flutter` is fine
on a machine whose global SDK already matches `.fvmrc`. Point an IDE's Flutter SDK path at
`.fvm/flutter_sdk`. The first `fvm install` on a machine mirrors Flutter's whole git
history and is slow; unzipping the official archive for the pinned release into
`~/fvm/versions/<version>` is the fast path.

Moving to the newest releases:

```bash
fvm use stable --pin                        # newest stable → .fvmrc
fvm flutter pub upgrade --major-versions
fvm flutter pub upgrade --tighten           # floors match what was resolved
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze && fvm flutter test
```

Raise `environment` in `pubspec.yaml` when the minor release changes. A new engine usually
moves text antialiasing by a few hundred pixels per screen, so expect to regenerate the
goldens (below) — and look at them. CI's weekly `latest-stable` job runs the same upgrade
against the newest releases and warns when `.fvmrc` is behind; Dependabot opens the
package PRs.

UI code imports `package:material_ui`, not `package:flutter/material.dart`. Material now
ships as its own package, Flutter 3.47 carries a `dart fix` to migrate off the framework's
copy, and `go_router` 18 already depends on the new one. A dependency still importing the
old library resolves `Theme.of` against that library's defaults rather than this app's
theme — `fl_chart` 1.2.0 does so only in its candlestick chart, so give it explicit styles
and it renders the same.

## Running it

```bash
flutter run -d macos     # or windows, linux
```

Web needs its DuckDB-Wasm assets vendored once first — see [web/README.md](web/README.md):

```bash
python3 tool/fetch_web_deps.py
flutter run -d chrome
```

**macOS note:** App Sandbox is deliberately off in both entitlements files — a sandboxed
build cannot open an arbitrary file path at all, and the Mac App Store is not a target
(SPEC.md §13). They still declare `com.apple.security.files.user-selected.read-only`,
which grants nothing outside the sandbox but is what `file_picker_darwin` checks for
before it will open a panel at all. Drop it and "Open file" stops opening anything;
`test/macos_entitlements_test.dart` exists to keep that from happening twice.

## Tests

```bash
flutter test
```

runs the whole device-free suite — unit, widget, and golden. Anything holding a real DuckDB
connection can only run compiled, because `dart_duckdb`'s native library is not linked into
the test-runner process:

```bash
flutter test integration_test/data_layer_test.dart -d macos --dart-define=PROJECT_ROOT="$(pwd)"
```

One file per run: given the whole `integration_test/` directory, every app after the first
fails to launch ("the log reader stopped unexpectedly").

That split is deliberate rather than incidental: SQL construction and every derivation are
pure functions specifically so the highest-risk logic sits in the surface CI can always
run. See `lib/data/README.md`.

Golden baselines live in `test/goldens/images/` and are committed, so `flutter test` is
self-contained. Regenerate with `flutter test --update-goldens test/goldens/` and **look at
the PNGs** — the images are the artifact, the diff is only the alarm.

They are pixel images generated on macOS and will not match another platform's text
rendering, so they carry the `golden` tag. Run everything else with:

```bash
flutter test --exclude-tags golden
```

## Layout

```
lib/
  app/        routing, theme wiring
  core/       formatting, error types
  data/       DuckDB access, models, shared repositories   → lib/data/README.md
  features/   one folder per SPEC.md §8 feature
  widgets/    design system, chart core                    → lib/widgets/charting/README.md
tool/         fixture generators, web asset vendoring
```
