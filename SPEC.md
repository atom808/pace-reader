# Pace Reader — Product & Technical Spec

**Status:** Draft v0.5 — Phase 0 scaffold underway: project builds on macOS/Web, dart_duckdb validated against real data in an integration test
**Owner:** Diego Pestana
**Last updated:** 2026-08-03

> §5 (Data Model) has been verified directly against three real `.duckdb` samples — one
> each of Practice, Qualify, and Race, across three different tracks/cars/classes — and is
> written as confirmed fact, with any remaining gaps called out explicitly rather than
> assumed. §7 (Prior Art) has been verified directly against screenshots of two reference
> apps (GO FAST, MyLMU) rather than inferred from marketing copy. §8 (Features) and §9
> (Architecture) have been updated to match both. Treat this as a living document: update
> it in place rather than starting a new one as more data/examples arrive.

---

## 1. Overview

**Pace Reader** is a cross-platform Flutter desktop/web application for analyzing telemetry
recorded by **Le Mans Ultimate (LMU)** — a WEC-based endurance racing simulator. As of LMU
1.2, the game's native telemetry recorder exports session data as `.duckdb` files
(DuckDB's embedded analytical database format). Pace Reader opens these files locally and
turns raw per-sample telemetry into lap analysis, track maps, tire/fuel insight, and
driver/stint comparisons — entirely offline, with no server or account required.

## 2. Goals

- Open and analyze `.duckdb` telemetry files exported by LMU, fully offline.
- Turn raw telemetry into actionable insight for sim racers: lap time analysis, driver
  inputs, tire/brake/fuel behavior, and track position — the same class of analysis tools
  like MoTeC i2 provide, tailored to LMU's endurance-racing context (multi-driver stints,
  long fuel/tire runs, day/night and weather transitions).
- Run natively and well on **Windows, macOS, Linux, and Web** from a single codebase.
- Be fast with large files: endurance sessions can span hours at high sample rates. Query
  and render responsively without loading entire sessions into memory naively.
- Be a good local citizen: no telemetry data leaves the user's machine unless they
  explicitly export/share it.

## 3. Non-Goals (v1)

- **Live telemetry / HUD overlay.** LMU also exposes a real-time shared-memory API (the
  rFactor2 plugin used by tools like TinyPedal/RacePulse). That's a different data source,
  a different app shape (always-on overlay), and a different problem. Explicitly out of
  scope for v1; could be a future, separately-scoped app or module.
- **Cloud sync, accounts, or social/leaderboard features.** Tools like MyLMU already cover
  cloud-hosted sharing and community leaderboards. Pace Reader v1 is local-first and
  single-user. Revisit only if the user wants to compete with/complement that space.
- **Setup/tuning advice or AI-generated coaching.** v1 shows data, not recommendations.
- **Editing or writing back to `.duckdb` files.** Strictly read-only against game-exported
  files.
- **Mobile (iOS/Android).** Not a target platform per the request, even though the chosen
  data-access package happens to support it — worth keeping in mind as a cheap future
  option, not a v1 commitment.

## 4. Domain Context (Le Mans Ultimate)

LMU is built on the rFactor2 engine and models the FIA World Endurance Championship, so
the app's domain model needs to account for things a single-class sprint-racing sim
wouldn't:

- **Classes/categories:** Hypercar (LMH/LMDh), LMP2, LMGT3 — cars are compared within
  class, not just overall.
- **Multi-driver crews:** an endurance entry is shared by 2–3+ drivers across a session;
  telemetry and lap data need a driver dimension, not just car/session.
- **Long stints:** fuel and tire degradation trends over 30–60+ minute stints matter more
  than single hot laps.
- **Session variety:** practice, qualifying (sometimes multi-driver quali), race — races can
  span day/night transitions and changing weather within a single file.
- **Pit stops:** in/out laps, pit lane time, and stop-to-stop deltas are first-class events,
  not noise to filter out.
- **Tracks & car roster change over time** as LMU adds content — track/car metadata should
  be data-driven (read from the file or a small bundled reference table), not hardcoded
  enums that require an app update every time DLC lands.

## 5. Data Model (confirmed against real sample files)

Verified directly against three real `.duckdb` files: a **Practice** session (Autódromo
José Carlos Pace, GT3), a **Qualify** session (Circuit de Spa-Francorchamps, Hypercar), and
a **Race** session (Sebring International Raceway, GT3). All three expose the **exact same
101-table schema** regardless of session type, track, car, or class — strong evidence
it's stable enough to build against directly rather than defensively.

Filenames follow `"{TrackName}_{P|Q|R}_{RecordingTime}.duckdb"` (e.g.
`Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb`), where the session-type
letter and `RecordingTime` both match the `metadata` table's own `SessionType`/
`RecordingTime` values — the filename is redundant with, not a separate source from, the
file's own metadata. **Default on-disk folder (Windows, confirmed):**
`C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate\UserData\Telemetry`. This
is a Steam default-library path, not a fixed OS path — a user with Steam installed to a
different drive/library (common) will have it elsewhere, so the app should offer this as a
pre-filled suggestion/first guess for the Session Library's scan/watch folder (§8.1), not
assume it unconditionally; a "change folder" override is required regardless. LMU itself
only runs on Windows, so this auto-detect convenience is Windows-only by nature — macOS,
Linux, and Web builds of Pace Reader always rely on manual import (file picker/drag-drop/
upload) since there's no local game install to point at.

**One file = one continuous recording by a single driver/client**, not a multi-driver or
multi-car bundle (`metadata.DriverName` and `SteamID` are single fixed values per file).
A real endurance stint with driver swaps would produce **one file per driver/stint**, not
one file covering a whole multi-driver race — this resolves the old "file per session vs.
per stint" open question and reshapes §8.8 (Driver Comparison) below: it's a cross-*file*
comparison feature, not something derivable from a single file.

### 5.1 Three kinds of tables

1. **`metadata`** — a `(key VARCHAR, value VARCHAR)` table of session facts:
   `DriverName`, `SteamID`, `RecordingTime`, `SessionTime` (session **start time-of-day**,
   e.g. `"13:00:21"` — not a duration), `SessionType` (`Practice`/`Qualify`/`Race`),
   `TrackName`, `TrackLayout`, `WeatherConditions`, `CarName`, `CarClass`, and `CarSetup`.
   - `CarClass` raw values seen: `"GT3"`, `"Hyper"` — short codes, not the full
     "LMGT3"/"LMH" names. Treat as a data-driven string (as §4 already recommended), not a
     hardcoded enum — and expect the raw string to need a small display-label mapping.
   - `CarName` is one composite string (e.g. `"The Bend Team WRT 2025 #31:BRZ"`,
     `"AF Corse 2026 #83:WEC"`) bundling team, year, car number, and a short model code.
     No confirmed grammar for splitting it into structured fields yet — treat it as an
     opaque label (substring filter/search) rather than assuming a fixed pattern until more
     samples are seen.
   - `CarSetup` is a large embedded **JSON blob with the entire car setup** — brake
     bias/migration, ARBs, camber/toe, springs/dampers per corner, tire compound per
     corner, a `gearGraph` (per-gear top speed/shift RPM), wing angles, fuel/energy load,
     etc. This resolves the old "is setup data embedded?" question — yes, in full — and
     means a "Setup" viewer (§8.10) needs no extra parsing infrastructure beyond
     `json_extract` on this one column.
2. **`channelsList`** (56 rows: `channelName`, `frequency` Hz, `unit`) and **`eventsList`**
   (42 rows: `eventName`, `unit`) — the catalog. Every one of the other ~98 tables is named
   after an entry in one of these two lists. **The repository layer should discover table
   names from these two catalog tables at runtime, not hardcode them** — a future LMU
   version could add/remove channels without breaking the app.
3. **~98 per-signal tables**, in one of two shapes:
   - **Channels** (listed in `channelsList`): fixed-rate, **no timestamp column at all**.
     Columns are just `value` (single-value channel, e.g. `Engine RPM`) or `value1`..
     `value4` (per-corner channel, e.g. `TyresPressure`, `Brakes Temp`, `RideHeights`) —
     row order is the sample sequence at that channel's own declared `frequency`, which
     ranges from 1 Hz (`Ambient Temperature`, `Track Temperature`) to 100 Hz (`Engine RPM`,
     `Ground Speed`, `Steering Pos`, per-corner tire-zone temps, etc.). **There is no shared
     sample clock across channels** — each is an independent fixed-rate array.
   - **Events** (listed in `eventsList`): sparse, with an explicit `ts DOUBLE` (elapsed
     seconds) + `value`/`value1`..`value4`, one row **per change**, not per fixed interval
     — e.g. `Gear` (758 rows across a 22.5-minute race), `Lap` (one row per lap start), `TC`/
     `ABS` (one row per activation edge, `BOOLEAN` value), and several driver-adjustable
     settings that end up with just a **single row** in a given file simply because they
     never changed during that session (`TCLevel`, `ABSLevel`, `Brake Bias Rear`,
     `Headlights State`, `Yellow Flag State` in these samples). Getting "value at time t"
     for an event means a backward/as-of lookup (latest row with `ts <= t`), not an
     equality/index lookup.

### 5.2 Reconstructing a shared time axis

Because channels carry no timestamp, aligning multiple channels — or a channel against an
event — needs a synthetic clock: `elapsed_time = origin + row_index / frequency`, where
`frequency` comes from `channelsList` and `origin` is a shared start offset (~23.6 s in all
three samples: the first value of the `GPS Time` channel and the first `ts` of every event
table agree on this exact number, despite being different tables — looks like time-since-
telemetry-armed rather than time-since-green-flag). `GPS Time` is itself a 100 Hz *channel*
(despite the name, it appears to just be the elapsed-seconds master clock) and can be used
to sanity-check the derived formula rather than trusting it blindly.

Practical consequences for the repository layer (§9.2):
- Use `row_number() OVER ()` over an unfiltered scan as the authoritative sample index per
  channel table. DuckDB doesn't formally guarantee scan order, but these files are written
  once and never mutated, so insertion-order scanning is safe in practice here.
- Aligning a fast channel (100 Hz) against a slow one (1–20 Hz) or against an event table
  is a resample/as-of problem, not an equality join — DuckDB's native `ASOF JOIN` ("latest
  matching row at or before this timestamp") is the right primitive here and should replace
  any hand-rolled backward-scan logic.
- Lap boundaries come from the `Lap` event table (`ts`, lap number, incrementing each lap
  start): slicing a channel into "lap N" means filtering its synthetic-time column between
  two consecutive `Lap` timestamps. `Lap Dist`/`Total Dist` (both channels, 10 Hz) give the
  distance axis for distance-based charts — combining them with a different-frequency
  channel needs the same synthetic-time alignment.

### 5.3 Per-corner value ordering (partially confirmed)

Multi-value channels/events use `value1`..`value4` with no embedded labels. Cross-checking
asymmetric setup values (e.g. `TyresPressure`'s four values consistently pair up as
(1,2) ≈ front vs. (3,4) ≈ rear; same pairing in `RideHeights`) confirms a **front-pair,
then rear-pair** grouping, consistent with the common rFactor2 wheel-order convention
(front-left, front-right, rear-left, rear-right). **The left/right assignment within each
axle is not independently confirmed from data alone** — verify against a setup with known
asymmetric left/right values (or the rF2 shared-memory plugin's documented wheel order)
before labeling any per-corner chart. Mislabeling FL/FR would be a subtle, easy-to-miss bug.

### 5.4 Notable domain-specific channels

- **Hypercar energy management**: `SoC`, `Virtual Energy`, `Regen Rate` (separate from
  `Fuel Level`) — confirmed present in the Spa Qualify sample (`CarClass = "Hyper"`).
  §8.7 (Fuel & Stint Strategy) should branch by class: fuel-based for GT3/LMP2,
  energy/SoC-based for Hypercar.
- **Race-relative pace**: `Time Behind Next` (gap to car ahead, 2 Hz) — enables a
  gap-to-competitor-over-race chart without needing another car's telemetry.
- **Flags & incidents**: `Yellow Flag State`, `Sector1/2/3 Flag` (integer/bitmask codes,
  not self-describing — e.g. observed values `0`, `1`, `11` with no confirmed meaning yet;
  needs a small decode reference table before use), `LastImpactMagnitude`,
  `WheelsDetached` (per corner) — good candidates for annotating "why was this lap slow" on
  the lap-time chart and track map (§8.3, §8.5).
- **Tire model is richer than assumed**: not one temperature per corner, but
  `TyresCarcassTemp` (5 Hz), `TyresRubberTemp` (10 Hz), `TyresRimTemp` (50 Hz), plus three
  tread-zone temps — `TyresTempLeft`/`Centre`/`Right` (100 Hz each, per corner), i.e.
  inner/middle/outer tread temperature per tire — the same shape MoTeC-style tire analysis
  expects.
- **Mid-session-adjustable values are modeled as events** (`TC`/`ABS` on-off, `TCLevel`,
  `ABSLevel`, `Brake Bias Rear`, `Brake Migration`) specifically because they *can* change
  during a session (e.g. a brake-bias migration dial), even though none of them changed in
  these three particular samples.

### 5.5 Implementation note: identifiers & file size

- Every channel/event-derived table and column name is a human-readable string that can
  contain spaces (`"Engine RPM"`, `"Track Temperature"`) — always double-quote identifiers
  when building SQL dynamically, and treat `channelsList`/`eventsList` as the source of
  truth for which quoted names are valid.
- Observed file sizes: Practice (Interlagos, GT3) 8.8 MB, Qualify (Spa, Hyper) 14 MB, Race
  (Sebring, GT3, 20 laps / ~22.6 min on track) 25 MB — roughly **~1.1 MB per driven
  minute** for the Race sample. Extrapolated, a full-length endurance stint could produce
  files from the low hundreds of MB (a ~6 h race, ≈0.4 GB) up to **multi-gigabyte** (a
  24 h race, ≈1.6 GB) — a real number to design around in §9.5/§10, not a hypothetical
  "millions of rows" hand-wave.

The data-access layer is still written against a `TelemetryRepository` abstraction
(§9.2) so that any remaining unknowns (flag/enum decoding, exact left/right wheel order)
only touch the SQL/mapping behind that interface, not UI or feature code.

## 6. Personas

- **The solo sim racer** reviewing their own practice/race sessions to find lap time, brake
  later, or manage tires/fuel better.
- **The endurance team engineer/strategist** comparing multiple drivers sharing a car
  across a long race, planning stints and pit windows.
- **The setup nerd** cross-referencing brake bias, tire pressures, and aero balance against
  lap time and tire degradation trends.

## 7. Prior Art

Two of these have now been reviewed directly via screenshots (§7.1, §7.2), not just
inferred from marketing copy — replacing the earlier guesswork with concrete, UI-verified
detail. None of these tools are Flutter-based, so there's no architectural precedent to
copy, but their feature sets are a strong, now-confirmed signal for what LMU sim racers
expect to see (§8).

### 7.1 GO FAST — Race Engineer
A multi-tab app (Dashboard / Setups / Race Engineer / Leaderboard) built around comparing
two drivers' laps side by side:
- A "Waiting for session" tab alongside per-car session tabs reads as **live-session
  capable**, not purely a post-session file viewer — the first concrete evidence in this
  research of a product spanning both live and post-session analysis. Doesn't change the
  Non-Goals decision to exclude live telemetry from v1 (§3), but confirms that's a
  deliberate scope cut against a real adjacent product, not a blind spot.
- Dual-driver header: both drivers' name, current stint/lap, lap time, throttle/brake %,
  speed, and RPM shown side-by-side and kept in sync — the concrete UI shape for §8.8.
- Main visualization is a stylized third-person "road ahead" view (not a flat top-down
  map), with a highlighted racing line and both drivers' cars on it, plus a small
  full-circuit minimap with numbered corners.
- Segment-by-segment navigation — finer-grained than the 3 official timing sectors — with
  prev/next controls and a per-segment time delta between the two drivers.
- Stacked, synced multi-channel strip charts (delta, throttle, brake, speed, steering,
  gear, RPM) plus a separate 8-panel per-corner tyre view (4× pressure, 4× temperature).
  Each chart renders one driver as a solid filled trace and the other as a dotted
  reference line, with a floating value readout at the scrub cursor. A Distance/Time axis
  toggle and a play/scrub bar with delta and lateral-gap readouts complete the view.

### 7.2 MyLMU
Confirms most of what §8 already assumed (file library with track/car/session filters, 2D
top-down track map, per-corner tyre panel) and surfaces several patterns/features not
previously planned for:
- **Community Best Laps**: a leaderboard scoped to track/class with a "Compare" action per
  entry that loads that lap as an overlay reference. Cloud/social, so out of scope per
  §3's Non-Goals — but the "browse laps → load as comparison reference" interaction is
  exactly the local, cross-session equivalent §8.8 already calls for.
- **N-way comparison, not just 2-way**: its "Pit Wall" view has independent *Base /
  Compare 1 / Compare 2 / Community* lap slots — worth explicitly designing §8.8 around
  3–4 simultaneous laps, not just a pair.
- **Two distinct chart modes, not one**: most views are within-lap distance/time traces
  (what §9.5 already designs around), but a "Thermal" tab shows **per-lap aggregate trend
  charts** instead — one point per lap (brake/tyre temp vs. lap number, a
  start-vs-stabilized-pressure bar chart per corner) — a materially smaller, differently
  shaped dataset that needs neither decimation nor cursor-sync.
- **Derived driving-technique metrics**, not just raw channels: trail-braking overlap %,
  shift discipline (% time in the power band, shift count, avg/max shift RPM), coasting
  distance/percentage, and a G-G diagram (peak combined G, grip utilization). None of this
  is a raw channel from §5 — it's computed from the throttle/brake/gear/G-force traces.
- **Derived car-behavior metrics**: ride-height distribution histograms (front/rear),
  damper velocity split into low-speed/high-speed % bins with peak velocity, and an
  aero-balance-shift trend across laps. Same story — computed, not raw.
- **A raw Events log**: a plain filterable table (time, lap, channel, value, unit) dumping
  the event tables directly — incidentally a strong validation of §5's schema reading
  (values shown for things like `Brake Bias Rear` and `Finish Status` match what direct
  inspection of the sample files found).
- **Segment/corner navigation with numbered minimaps** appears in both apps' track views —
  a UX convention this genre treats as close to mandatory, not optional polish.

None of this changes the core architecture decisions in §9, but it meaningfully expands
§8's feature list (new §8.12–§8.14) and surfaces one open question: corner/segment
numbering isn't present anywhere in the confirmed schema (§5), so both reference apps must
be sourcing it from somewhere else — a bundled per-track reference, or geometric
auto-detection from the position/steering trace. Flagged in §15.

## 8. Feature Set (v1 target)

Grounded directly in the confirmed channels/events of §5 rather than assumed sim-telemetry
conventions.

### 8.1 Session Library
Import `.duckdb` files (file picker on desktop; upload on web, since browsers can't browse
an arbitrary filesystem path). On Windows, pre-fill/suggest LMU's default telemetry folder
(§5) as a scan/watch location — overridable, since Steam library location varies per user —
so new sessions can be picked up automatically instead of requiring a manual per-file
import every time. Keep a local index (track, car, class, session type, date, best lap —
all read straight from `metadata`) so the library list doesn't need to re-open every file
on every launch (see §9.6). Recent files, search/filter by track/car/class.

### 8.2 Session Overview
Track, car, class, session type, driver, weather (`metadata`), duration and lap count
(derived from the `Lap` event table), best lap / theoretical best (`Best LapTime`,
`Best Sector1/2`).

### 8.3 Lap Time Analysis
Lap time table with sector splits (`Current/Last/Best Sector1/2`, `Sector1/2/3 Flag`),
delta to personal best and to a chosen reference lap, consistency (std. dev., outlier laps
flagged), lap time trend across a stint or full session. Annotate laps affected by
`Yellow Flag State`, `LastImpactMagnitude`, or `WheelsDetached` so a slow lap's cause is
visible, not just its time.

### 8.4 Telemetry Traces
Multi-channel time/distance-based charts — `Ground Speed`, `Engine RPM`, `Throttle/Brake
Pos`, `Steering Pos`, `Gear`, `G Force Lat/Long/Vert`, etc. — for a single lap or overlaid
across multiple laps, with a synced scrub cursor across all channels and the track map
(§8.5). Channels at different native frequencies are aligned via the synthetic-time/ASOF
approach in §5.2 before charting, not assumed to share a clock.

### 8.5 Track Map
2D circuit map built from `GPS Latitude`/`GPS Longitude` (or `Lap Dist`/`Total Dist` +
`Path Lateral` for a distance-based lane view), colored by a selected channel (speed,
throttle, brake), with a synced cursor following the trace view. `Path Lateral` and
`Track Edge` directly support an off-track/track-limits overlay — a capability that
wasn't assumed at spec time but is available for free from real channels. 3D is a stretch
goal, not v1. Both reference apps (§7) also show a numbered-corner minimap and support
segment-by-segment navigation finer than the 3 official sectors — worth adopting as a UX
convention, but corner/segment boundaries aren't in the confirmed schema (§5), so this
needs either a bundled per-track reference or geometric auto-detection from the position/
steering trace (open question, §15).

### 8.6 Tires & Brakes
Full per-corner tire model: `TyresPressure`, `Tyres Wear`, and three tread-depth
temperature readings — `TyresCarcassTemp`, `TyresRubberTemp`, `TyresRimTemp` — plus
inner/middle/outer tread-zone temps (`TyresTempLeft`/`Centre`/`Right`), richer than
originally assumed. Brake side: `Brakes Temp`, `Brakes Air Temp`, `Brakes Force`, `Brake
Bias Rear`, `Brake Migration`. Trends across a stint, not just a single-lap snapshot.

### 8.7 Fuel & Energy Strategy
Branches by class (§5.4): fuel-based (`Fuel Level`) for GT3/LMP2, energy-based (`SoC`,
`Virtual Energy`, `Regen Rate`) for Hypercar. Per-lap consumption, estimated laps/time
remaining in a stint, pit stop markers (`In Pits`) with in/out-lap deltas.

### 8.8 Driver/Stint Comparison
Since one file = one driver's continuous recording (§5), this is a **cross-file**
comparison feature, not something derivable from a single session: load two or more
`.duckdb` files (e.g. two drivers' stints from the same endurance race) and compare pace,
consistency, and delta-traces between them. Reframed from the original single-file
assumption. Both reference apps (§7) converge on the same shape for this: an **N-way
comparison** (2 up to ~4 simultaneous laps/files, not just a pair), a side-by-side header
per driver/lap (name, lap time, live stats), a compact sector-delta table, and a
solid-trace-for-primary / dotted-trace-for-reference convention on every synced chart —
adopt this as the concrete UI target rather than inventing a different comparison model.

### 8.9 Race Pace & Gaps
Race-session-specific: `Time Behind Next` gives gap-to-car-ahead directly, enabling a
pace/gap-over-race-distance chart without needing another car's telemetry file.

### 8.10 Setup Viewer
Read-only view of the embedded `CarSetup` JSON (§5.1) — brake bias/migration, ARBs,
camber/toe, springs/dampers per corner, gearing (incl. the `gearGraph` per-gear top
speed/shift RPM), tire compound, wing angles. Not in the original spec draft; added
because the data turned out to already be fully present, at no extra parsing cost beyond
`json_extract`.

### 8.11 Export
Export a chart as an image; export a lap or session summary as CSV. MoTeC `.ld` export is
a candidate for a later phase (§14), given the existing community tool suggests demand,
but adds real complexity (reverse-engineering or depending on an undocumented format) so
it shouldn't gate v1.

### 8.12 Events Log
A plain, filterable table over the raw event tables (§5.1) — time, lap, channel, value,
unit — for users who want to see exactly what the game recorded rather than a curated
chart. Directly inspired by MyLMU's Events tab (§7.2). Cheap to build straight off the
`eventsList` catalog (§9.2) and doubles as a debugging/verification tool during
development, since it's a direct window onto the same data the rest of the app derives
everything else from.

### 8.13 Driving Technique Analysis
Derived metrics computed from raw channels, not read directly from any single table:
trail-braking overlap (throttle/brake overlap %), shift discipline (% time in the power
band, shift count, average/max shift RPM — using `Gear`, `Engine RPM`, and
`CarSetup.gearGraph`), coasting distance/percentage (neither throttle nor brake applied),
and a G-G diagram (`G Force Lat`/`G Force Long` scatter, peak combined G, grip
utilization). Inspired by MyLMU's Driver tab (§7.2) — not in the original spec draft.
Needs its own derivation layer on top of the repository (§9.2), not just query/decimate,
so it's a later-phase feature (§14), not MVP.

### 8.14 Car Behavior Analysis
More derived metrics, this time about the car rather than the driver: ride-height
distribution (histogram of `FrontRideHeight`/`RearRideHeight` samples), damper velocity
split into low-speed/high-speed bins (from `Susp Pos`/`Front3rdDeflection`/
`Rear3rdDeflection`), and an aero-balance-shift trend across laps. Inspired by MyLMU's Car
tab (§7.2). Same reasoning as §8.13 — meaningful derivation logic, later phase.

## 9. Architecture

### 9.1 High-level layers

Feature-first folder structure, layered clean-architecture style within each feature, with
one important deviation: telemetry **repositories are shared, not per-feature**, because
most features query the same underlying session/lap/telemetry tables. Duplicating query
logic per feature would drift quickly.

```
lib/
  app/                 # App widget, theming, routing wiring, DI (Riverpod ProviderScope)
  core/                # Cross-cutting utils, error types, logging, constants
  data/
    duckdb/            # Connection lifecycle, schema mapping, SQL
    repositories/       # SessionRepository, LapRepository, TelemetryRepository
    models/            # Freezed models: Session, Lap, Stint, Driver, TelemetrySample...
  features/
    session_library/
    session_overview/
    lap_analysis/
    telemetry_trace/
    track_map/
    tires_brakes/
    fuel_energy_strategy/
    driver_comparison/
    race_pace/
    setup_viewer/
    events_log/
    driving_technique/
    car_behavior/
    settings/
      <feature>/
        application/    # Riverpod notifiers / view-state, use-case-level logic
        presentation/   # Screens, widgets
  widgets/
    design_system/     # Tokens + reusable primitives (§9.7): color/radius/duration/curve
                        #   tokens, SquircleCard, GlassSurface, AppButtonStyles,
                        #   Skeleton/ShimmerBox, AsyncValueView, AppPageTransitions,
                        #   custom hooks (useShimmer, useFadeInOnMount), Hoverable/Pressable
    charting/          # Custom CustomPainter chart core (§9.5): viewport/transform math,
                        #   decimation helpers, painters, shared cursor/sync controller
    fl_chart_theme/    # Thin theme wrapper so fl_chart output matches the custom core
    common/            # Shared UI: empty/error states, layout shells
```

Each feature's `application/` layer composes the shared repositories rather than talking
to DuckDB directly — keeps the DB/schema knowledge in one place.

### 9.2 Data access layer: DuckDB

Use **[`dart_duckdb`](https://pub.dev/packages/dart_duckdb)** (verified publisher,
production-ready, actively maintained) rather than hand-rolled FFI bindings. It's the one
package that already covers every required target — Windows, macOS, Linux, and Web — plus
mobile for free if that's ever revisited:

- **Desktop (Windows/macOS/Linux):** native FFI bindings to the bundled DuckDB engine;
  open the file directly from the path returned by a file picker or drag-and-drop.
- **Web:** backed by DuckDB-Wasm + Apache Arrow, loaded via `<script>`/import-map entries
  in `web/index.html`. Browsers can't open an arbitrary filesystem path, so the flow is
  different from desktop: the user picks/drops a file, we read its **bytes**, and register
  those bytes as a virtual file in DuckDB-Wasm before opening — this asymmetry should be
  isolated behind a single `TelemetryRepository.openSession(...)` factory so feature code
  never branches on platform.

Push computation into SQL wherever possible (aggregations for lap summaries, window
functions for deltas, filtering/sampling for chart data) instead of pulling raw rows into
Dart and computing client-side — this is both a DuckDB-idiomatic pattern and the key to
staying fast on multi-hour sessions (§9.5).

Schema-specific responsibilities this layer owns (see §5 for the full reasoning):

- **Catalog-driven table discovery**: read `channelsList`/`eventsList` at open time rather
  than hardcoding table names, and always double-quote identifiers when building SQL —
  every channel/event name can contain spaces (`"Engine RPM"`).
- **Synthetic time derivation**: channels have no timestamp column, so this layer computes
  `elapsed_time = origin + row_index / frequency` per channel (§5.2) and exposes already
  time-aligned results to feature code — features should never need to know a given
  channel's native Hz or that it lacks a `ts` column.
  - **This must be validated as an assumption before it's load-bearing.** §5.2 makes a
    scan-order argument for why `row_number() OVER ()` is safe here, but that's inference
    from three sample files, not a guarantee from LMU. The Phase 0 spike (§14) should
    specifically cross-check the derived synthetic time against `GPS Time` (the one
    channel that carries real elapsed seconds) across all three samples before any chart
    depends on it.
- **Event-to-channel alignment**: use DuckDB's native `ASOF JOIN` to answer "what was this
  event's value as of this channel sample's time" — e.g. resolving `Gear` or `TC` state at
  each `Engine RPM` sample — rather than a hand-rolled backward scan.
- **Lap slicing**: derive lap boundaries from the `Lap` event table and expose a
  "channel data for lap N" query as a first-class repository method, since nearly every
  feature (§8.3–§8.9) needs it.

### 9.3 State management

**Riverpod** (`flutter_riverpod` + `riverpod_generator`), for:

- Compile-time-safe DI without a separate service locator.
- `AsyncNotifier`/`FutureProvider` map naturally onto "open session → run query → derive
  chart data" flows, including loading/error states.
- Family providers keyed by session/lap id for per-session state; `keepAlive` for
  long-lived DB connections.
- First-class testability (override providers in widget tests).

Bloc is a reasonable alternative for teams preferring stricter event-driven structure, but
Riverpod better fits the async-heavy, derived-data-shaped state this app deals with, and is
the current default recommendation for new Flutter apps.

**`hooks_riverpod`, scoped narrowly.** Adopted specifically for ephemeral, widget-local
state that needs a `Ticker`/dispose lifecycle — `AnimationController`s above all (§9.7.4),
where `useAnimationController()` removes the usual `StatefulWidget` +
`TickerProviderStateMixin` + manual-dispose boilerplate. This is **not** a replacement for
the notifier-based architecture above: Riverpod notifiers/providers remain the single
source of truth for domain and app state; hooks own local widget lifecycle plumbing only.
Keeping that boundary explicit avoids the "hooks vs. Riverpod" confusion that comes up when
teams reach for hooks as a second, competing state-management layer instead of a
complement to the first.

### 9.4 Navigation

**`go_router`** — declarative routing, works uniformly across desktop and web (including
proper browser URL/back-button support on web), supports deep-linking into a specific
session/lap view later if needed.

### 9.5 Rendering telemetry: charts, track map, and performance

**Decision: hybrid.** The boundary is drawn by *behavior*, not by "simple vs. complex"
chart type:

- **Custom `CustomPainter` core** (`widgets/charting/`) for anything that participates in
  cross-chart interaction: telemetry trace charts, the track map, multi-lap overlay, and
  the distance/time axis toggle. These all share one scrub cursor and one
  viewport/zoom state across panels — that's exactly the kind of cross-cutting concern a
  general-purpose chart library isn't built around, so it's built once as a shared module:
  - `viewport.dart` — pan/zoom/transform math, shared across every chart + the track map.
  - `decimation.dart` — turns a DuckDB query result at the current viewport into
    render-ready points (see decimation strategy below); pairs directly with the
    repository layer (§9.2) rather than living in the widget tree.
  - `painters/` — line-trace painter, track-map painter, shared cursor/overlay painter.
  - `sync/` — the shared cursor/viewport controller (Riverpod) that every synced chart and
    the track map subscribe to.
- **`fl_chart`** for genuinely standalone charts that never need to join that synced
  system — e.g., a lap-time bar/line chart, a fuel-per-lap trend. Used directly in the
  owning feature's `presentation/` layer, wrapped by a small shared theme
  (`widgets/fl_chart_theme/`) so colors, fonts, tooltips, and animation timing match the
  custom-painted views rather than looking like a bolted-on library.

**Two chart modes, confirmed by both reference apps (§7)**: within-lap distance/time
traces are one shape of chart (the synced/custom-core case above); §8.13/§8.14's **per-lap
aggregate trend charts** (one data point per lap — e.g. brake temp vs. lap, a
start-vs-stabilized pressure bar per corner) are a different, much smaller dataset with no
decimation or cross-chart cursor-sync need at all. These land squarely in the `fl_chart`
bucket per the same behavior-based rule above — not because they're "simpler," but because
they genuinely don't participate in the synced system.

**Known migration risk of the hybrid split:** a chart that starts out standalone can later
grow a sync requirement (e.g., "click a lap in the lap-time chart to load it into the
trace view") — at that point it graduates from `fl_chart` into the custom core. Treat that
as an expected, named migration path when scoping a feature, not a surprise refactor.

**Performance strategy (applies regardless of which renderer draws a given chart):** in the
confirmed samples (§5.5), a ~22.6-minute Race recording holds up to 134,059 rows for a
100 Hz channel; linearly extrapolated, a 6-hour endurance stint would put a single 100 Hz
channel around 2.16M rows, and there are roughly 15 channels at 100 Hz — so a "load
everything" approach is off the table well before a full-length race, not just a
theoretical concern. No renderer should ever be handed a full-resolution multi-hour trace
at once. Query DuckDB for **decimated/aggregated data at the current viewport** (e.g.,
min/max/avg bucketing per pixel-column, or an LTTB-style downsample), and only re-query at
higher resolution as the user zooms into a smaller distance/time window. Event tables, by
contrast, are sparse (single digits to low thousands of rows even over a full race) and can
be loaded in full without decimation.

**Still to validate in Phase 0 (§14):** the library choice is decided, but the
decimation/viewport strategy itself needs a short spike against a real sample file to
confirm bucket sizes and query latency actually deliver smooth scrubbing — the risk moved
from "which library" to "does our own decimation approach perform," which is arguably the
harder and more important question anyway.

### 9.6 Local app storage (not the telemetry itself)

Maintain a small local app database (`drift`, i.e. SQLite) separate from the imported
`.duckdb` files, to index imported sessions (path, track, car, class, date, best lap) for
the Session Library (§8.1) and cross-session personal-best tracking without re-opening
every large file on every app launch. Populate/update this index at import time.

### 9.7 Design System

Material 3, dark theme as default (telemetry/dashboard apps are typically used in dim
sim-rig environments — matches genre convention from the prior-art tools), adaptive layout
for resizable desktop windows and variable-width browser windows. Multi-pane layouts
(trace + track map + lap table visible together) matter more here than on mobile, so lean
into desktop-class layout (resizable panels, dockable-feeling panes) rather than a
phone-first responsive design. A working direction for the sub-sections below was
prototyped as a static HTML preview (color/shape/glass/motion together, built from the
real Sebring sample) — not shipped code, but the concrete reference the decisions here
describe.

#### 9.7.1 Color

Primary is a wine-leaning purple, generated from a single Material 3 seed rather than a
hand-picked multi-hue palette — `ColorScheme.fromSeed(seedColor: ..., brightness:
Brightness.dark)` derives the full tonal set (containers, surfaces, contrast-safe text
pairs) from one value. Prototype seed: `#9B3F6B`, with `#5A2145` as the deeper
filled/pressed tone — a starting point to validate in-context (contrast, WCAG) rather than
a permanent lock. Differentiation from MyLMU (orange brand) and GO FAST (green/red) is
already solid on hue alone; shape (§9.7.2) and selective glass (§9.7.3) carry more of the
distinction than color does.

**Channel colors are a separate system from the brand color, on purpose.** Both reference
apps (§7) converge on the same charting visual language — a solid, filled-area trace for
the "primary" driver/lap and a thin dotted line for a reference/comparison one; one color
per **channel type**, not per driver; charts stacked in a vertical strip sharing a single
scrub cursor; a floating value readout anchored to that cursor on every chart — worth
adopting as a starting point rather than inventing one from scratch. But since our brand
color is now purple, `delta` — purple in both reference apps — is reassigned to a cool
blue, keeping throttle/brake/speed/RPM in their conventional green/red/teal/amber, so a
delta trace never reads as brand chrome. This maps directly onto the custom chart core's
`sync/` and `painters/` modules (§9.5).

#### 9.7.2 Shape

`ContinuousRectangleBorder` — Flutter's built-in iOS-style continuous-curvature corner,
i.e. an actual squircle, not a circular-arc approximation — costs zero new dependencies
and is the default shape for buttons, inputs, and cards. A small radius scale (`sm`/`md`/
`lg`/`xl`) is defined once as shared tokens (§9.7.6) rather than each widget picking its
own value, and `StadiumBorder`/pill shapes are explicitly avoided so nothing ever rounds
into a circle. (`figma_squircle` is a possible later upgrade if we ever need
Figma-parity corner-smoothing control — not needed to start.)

#### 9.7.3 Glassmorphism (selective)

`BackdropFilter` forces an extra blur render pass — a real cost stacked on top of §9.5's
whole "smooth 60 fps scrubbing" performance budget. The boundary is drawn the same way as
the chart hybrid decision (§9.5): glass on static or infrequently-redrawn chrome (top bar,
modals/popovers, the session card, floating panels) — **never** on the live trace charts
or track map, which redraw every frame during scrubbing and sit directly on the
performance-critical path. Also worth being more conservative on Web specifically, where
blur is proportionally more expensive than on desktop — a plain tinted surface (no blur)
is an acceptable Web fallback for the same visual slot if a spike shows it's needed.

#### 9.7.4 Motion & animation

"Cupertino-like" is adopted as an *easing/feel* — a smooth deceleration slide+fade curve
(e.g. `Curves.easeOutCubic`/a custom curve close to `cubic-bezier(.16,1,.3,1)`) — not the
literal iOS edge-swipe-to-dismiss gesture, which is a mobile-platform convention that
doesn't map to desktop/web (and mobile is out of scope per §3 regardless). Concretely:
- Route transitions: a shared `AppPageTransitions` helper wraps `go_router` routes in a
  `CustomTransitionPage` using the standard slide+fade curve, applied once rather than
  per-route.
- Shimmer/skeleton loading: a small in-house `Skeleton`/`ShimmerBox` widget rather than the
  `shimmer` package, since it needs to clip to our squircle shape tokens (§9.7.2)
  specifically, not a generic box.
- Widget-state transitions: a standard `AsyncValueView` widget bridges a Riverpod
  `AsyncValue` (§9.3) directly to a consistent cross-fade between skeleton / error / data —
  every feature screen uses this instead of hand-rolling its own loading/error branches.
- All animation respects `prefers-reduced-motion`-equivalent platform accessibility
  settings.

#### 9.7.5 Hooks: scope and boundary

See §9.3 for the full reasoning — `hooks_riverpod` is scoped to ephemeral, widget-local
animation/lifecycle state (`useAnimationController()` and similar), not to domain or app
state, which stays in Riverpod notifiers. A small set of custom hooks
(`useShimmer()`, `useFadeInOnMount()`) wrap the raw `AnimationController` boilerplate
behind the standardized durations/curves from §9.7.4, so animation timing is consistent
app-wide rather than each screen picking its own.

#### 9.7.6 Reusable primitives catalog

Lives in `widgets/design_system/` (§9.1):

| Primitive | Purpose |
|---|---|
| Token constants | Color seed/tonal refs, radius scale, duration/curve constants — single source of truth for §9.7.1–9.7.4 |
| `SquircleCard` | Base card applying shape + elevation + padding tokens |
| `GlassSurface` | The selective glass wrapper (blur + tint + border) — used only on designated static chrome (§9.7.3) |
| `AppButtonStyles` | Centralized `ButtonStyle` factory (squircle shape, brand color mapping) shared by every button variant |
| `Skeleton` / `ShimmerBox` | Squircle-shaped shimmer loading placeholder (§9.7.4) |
| `AsyncValueView` | Riverpod `AsyncValue` → skeleton/error/data cross-fade, standard across all feature screens |
| `AppPageTransitions` | Shared `go_router` `CustomTransitionPage` builder (§9.7.4) |
| `useShimmer` / `useFadeInOnMount` | Custom hooks wrapping standardized animation timing (§9.7.5) |
| `Hoverable` / `Pressable` | Desktop/web hover-and-press micro-interaction wrapper (subtle scale/elevation), reused by session-library cards, lap rows, etc. |

Also worth naming explicitly: the chart core's `sync/` cursor controller (§9.5) is itself
a reusable *behavior*, not just a rendering concern — scrubbing/cursor-sync is a pattern
other future interactions could reuse, not something coupled one-to-one with charts.

#### 9.7.7 Typography

Two type roles, not one font for everything:

- **UI voice**: General Sans (Indian Type Foundry, distributed via Fontshare) — free for
  personal and commercial use, weights Extralight (200) through Bold (700) plus italics,
  with a variable-font version available. Used for headings, buttons, navigation, and body
  text. Bundled as static font assets (`assets/fonts/`) rather than a web-font CDN link —
  self-hosting matches the offline-first requirement (§10) and avoids a network dependency
  on desktop specifically, where there's no guarantee of connectivity at launch.
- **Numeral/data voice**: the system-monospace stack (SF Mono/Cascadia Code/JetBrains
  Mono/Consolas/monospace) with tabular figures enabled (Flutter's
  `FontFeature.tabularFigures()`) for every numeral — lap times, telemetry values, cursor
  readouts, stat cards. General Sans does **not** support tabular figures, which matters
  here specifically: digit-for-digit column alignment on ticking/updating numeric displays
  is a real requirement for this app, not a nice-to-have, so numerals are deliberately kept
  on a typeface that has proper tabular-figure support rather than General Sans.
- **License**: confirmed via Fontshare's "Closed Source" ITF FFL license — app/software
  embedding of any kind is explicitly permitted, not just website `@font-face` use (§15).
  The only real restriction is against redistributing the raw font files themselves as a
  standalone product, which doesn't apply to bundling them to render our own app's UI.

## 10. Non-Functional Requirements

- **Performance:** interactive frame rate while scrubbing/zooming telemetry traces even on
  multi-hour sessions (see §9.5). Session import/open should not block the UI thread.
- **Offline-first:** no network access required for core functionality.
- **Cross-platform parity:** the same feature set on Windows/macOS/Linux/Web; the only
  sanctioned difference is *how* a file gets opened (path vs. bytes, §9.2), not what
  analysis is available afterward.
- **Resilience:** a malformed/unexpected schema in a `.duckdb` file should produce a clear
  error, not a crash. The schema is now confirmed (§5) and stable across the 3 samples
  checked, but LMU could still evolve the format in a future game update — catalog-driven
  table discovery (§9.2) already absorbs additive changes; missing/renamed catalog entries
  should degrade to a clear error, not a crash.
- **Accessibility:** standard Flutter a11y (semantics labels, sufficient contrast even in
  the dark theme, keyboard navigation on desktop/web).

## 11. Tech Stack Summary

| Concern | Choice | Notes |
|---|---|---|
| Language/framework | Flutter (stable channel) | Targets listed: Windows, macOS, Linux, Web |
| State management | `flutter_riverpod` + `riverpod_generator` | §9.3 |
| Ephemeral widget/animation state | `hooks_riverpod` (`flutter_hooks`) — scoped to `AnimationController`-style lifecycle state only | §9.3, §9.7.5 |
| Routing | `go_router` (custom `CustomTransitionPage` for route motion) | §9.4, §9.7.4 |
| Telemetry data access | `dart_duckdb` | §9.2 — covers all 4 target platforms |
| Local app cache/index | `drift` (SQLite) | §9.6 |
| Charts (synced/interactive) | Custom `CustomPainter` core (shared viewport, decimation, cursor sync) | §9.5 |
| Charts (standalone summary) | `fl_chart`, themed to match the custom core | §9.5 |
| Track map | Custom `CustomPainter` (shares viewport/cursor sync with trace charts) | §9.5 |
| Design tokens & primitives | In-house `widgets/design_system/` (color/shape/motion tokens, `GlassSurface`, `SquircleCard`, `AsyncValueView`, shimmer) | §9.7 |
| Typography | General Sans (UI voice, self-hosted asset) + system monospace w/ tabular figures (numeral voice) | §9.7.7 |
| File selection | `file_picker`, `desktop_drop` (drag-and-drop on desktop) | |
| Models | `freezed` + `json_serializable` | |
| Lint | `flutter_lints` (or `very_good_analysis`) | |
| Testing | `flutter_test`, `mocktail`, golden testing (`alchemist` or `golden_toolkit`), `integration_test` | §12 |
| CI | GitHub Actions, matrix build across windows-latest/macos-latest/ubuntu-latest + web | §13 |

## 12. Testing Strategy

- **Unit tests** for repository/query logic, run against small fixture `.duckdb` files
  (trimmed versions of the 3 real samples, e.g. first N laps only, to keep them small and
  checked into the repo) — this is the highest-value test surface given how much logic
  lives in SQL/mapping (synthetic time derivation, ASOF alignment, lap slicing).
- **Widget tests** for individual screens/components with Riverpod provider overrides
  supplying fixture data (no real DB needed).
- **Golden tests** for chart and track-map rendering, since visual regressions here are
  easy to introduce and hard to eyeball-catch.
- **Integration tests** (`integration_test`) covering the import → analyze golden path on
  each desktop platform plus web.

## 13. CI/CD & Distribution

- GitHub Actions matrix: build + test on `windows-latest`, `macos-latest`, `ubuntu-latest`,
  plus a web build job.
- Distribution (later, not needed for early dev):
  - Windows: MSIX packaging.
  - macOS: signed/notarized `.app`/`.dmg` (Gatekeeper will otherwise block a locally-built
    app reading user files). **App Sandbox is deliberately off** (both entitlements
    files) — confirmed during the Phase 0 spike that a sandboxed macOS build cannot open
    an arbitrary file path at all (`Operation not permitted`), and we're not targeting the
    Mac App Store, so there's no reason to take on security-scoped-bookmark plumbing for a
    restriction that doesn't apply to us.
  - Linux: AppImage and/or Flatpak.
  - Web: static hosting (e.g., GitHub Pages/Cloudflare Pages/Firebase Hosting) — trivial
    since the app has no backend.

## 14. Phased Roadmap

- **Phase 0 — De-risk:** ~~project scaffold~~, ~~lint~~, ~~theme~~, ~~routing skeleton~~ —
  done: feature-first structure (§9.1), design system (§9.7) wired into a real `ThemeData`,
  a `go_router` shell with all 13 feature placeholders navigable, `flutter analyze` clean.
  ~~Spike `dart_duckdb` against a real sample~~ — done, and it's the single biggest de-risk
  of this phase: an `integration_test` (not a plain `flutter test` — dart_duckdb's native
  library is only linked into a real compiled app, not the bare test-runner process) opened
  a trimmed real fixture (`test/fixtures/sebring_race_lap1.duckdb`) on macOS and confirmed
  metadata/catalog reads work, **the synthetic time-axis formula from §5.2/§9.2 matches
  `GPS Time` to sub-millisecond precision**, and DuckDB's `ASOF JOIN` correctly resolves an
  event's value as of a channel sample. §15.3 is resolved. Still open from the original
  Phase 0 list: web memory behavior with a large/synthetic file, CI wiring for the
  integration test on Windows/Linux runners, and the chart core's decimation/viewport
  strategy (that's Phase 1 work now that a chart core exists to spike).
- **Phase 1 — MVP:** single-file import (desktop + web), Session Overview, lap time table,
  single-lap telemetry trace (speed/throttle/brake/gear vs. distance), basic 2D track map.
- **Phase 2:** multi-lap overlay + delta trace, tires/brakes view, fuel/stint view, Session
  Library with local index/cache, Events Log (§8.12 — cheap, direct off the catalog),
  per-lap aggregate trend charts (§7.2/§9.5).
- **Phase 3:** N-way driver/stint comparison (§8.8), export (image/CSV), cross-session
  personal-best tracking, Driving Technique Analysis (§8.13).
- **Phase 4 (stretch, explicitly not committed):** MoTeC `.ld` export, Car Behavior
  Analysis (§8.14), 3D track view, live telemetry overlay as a separate module.

## 15. Risks & Open Questions

**Resolved, kept here for traceability:**

- Schema (table/column names, units, sample rates) — confirmed, identical across all 3
  samples (§5).
- Car setup embedded — yes, in full, as JSON (§5.1).
- One file per session vs. per stint — confirmed one file = one continuous single-driver
  recording (§5), which reframed §8.8 into a cross-file comparison feature.
- Typical file size/row counts — confirmed and extrapolated in §5.5/§9.5.
- Default on-disk folder (Windows) — confirmed:
  `C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate\UserData\Telemetry`
  (§5), though it must stay a user-overridable suggestion rather than a hardcoded path,
  since Steam library location varies per install.
- General Sans license scope — confirmed. Fontshare's "Closed Source" ITF FFL license
  (fontshare.com/licenses/itf-ffl) explicitly permits personal and commercial use in apps,
  video, products, and "any other digital or physical format," with no restriction on the
  type of work or number of users — app-bundle embedding is squarely inside the permitted
  use, not just website `@font-face`. The one real restriction is on redistributing the
  *font files themselves* as a standalone product (uploading to another font directory,
  bundling them in something sold as a template/font pack, or modifying and
  redistributing them) — irrelevant to using the font to render our own app's UI (§9.7.7).
  Caveat: this reading is via search-engine summaries of the license page, since it's a
  client-rendered page neither `curl` nor a fetch tool could retrieve raw text from — worth
  a final human read of the actual "Limitations of Usage" section before a release build.
- **Synthetic time-axis derivation** — confirmed. A Phase 0 `integration_test` against the
  real Sebring sample validated `origin + row_index / frequency` against `GPS Time` to
  sub-millisecond precision (§9.2, §14), and confirmed DuckDB's `ASOF JOIN` correctly
  resolves event-to-channel alignment. Residual, much lower-priority: this was validated
  against ~172s of data (one lap); accumulated floating-point drift over a multi-hour file
  hasn't been checked and would be worth a spot-check once a longer real sample exists —
  but at 100 Hz over even 24h, drift on the order of double-precision float error is many
  orders of magnitude below one sample period, so this is a "confirm eventually," not a
  live doubt.
- **dart_duckdb on macOS requires App Sandbox off** — confirmed during the same spike
  (§13); a sandboxed build can't open an arbitrary file path at all.

**Still open:**

1. **Web memory ceiling vs. real file sizes** — §5.5 extrapolates full-length endurance
   files into the multi-gigabyte range (~1.6 GB for 24 h). `dart_duckdb`'s web path loads
   the whole file's bytes into the browser before DuckDB-Wasm can open it (§9.2) — needs a
   concrete test with a large synthetic or real file, not just the small samples on hand,
   since browser tabs have materially less addressable memory than a desktop process.
2. **Chart/decimation performance at scale** — needs an early spike against a realistic
   multi-hour file (still don't have one — the samples are all short sessions), using the
   concrete row-count extrapolation in §9.5 rather than a guess. Now that the chart core
   has an actual home (`widgets/charting/`, scaffolded but not yet implemented), this is a
   Phase 1 spike rather than a Phase 0 one.
3. **Flag/enum decoding** — `Sector1/2/3 Flag`, `Finish Status`, `SurfaceTypes` store
   integer codes with no confirmed meaning (§5.4). Needed before flag/incident annotations
   (§8.3) can be built.
4. **FL/FR/RL/RR left/right order** — front-vs-rear pairing is confirmed from data, but
   left/right within each axle is not (§5.3). Needs a sample with known asymmetric
   left/right setup values, or an authoritative rF2 API reference.
5. **`CarName` structure** — composite string with no confirmed parsing grammar (§5.1);
   only matters if/when the app wants structured team/car-number/model fields rather than
   opaque-string filtering.
6. **Schema stability across untested combinations** — confirmed identical across these 3
   samples (different tracks, GT3 and Hypercar), but not verified for every class (e.g.
   LMP2) or a multiplayer/league context.
7. **Hybrid chart boundary drift** — a chart built standalone in `fl_chart` may later need
   to join the synced cursor/viewport system (§9.5); watch for this during feature scoping
   so it's a planned migration, not a late-discovered rewrite.
8. **Corner/segment numbering** — both reference apps (§7) show numbered corners and
   finer-than-sector segment navigation, but nothing in the confirmed schema (§5) carries
   corner definitions. Needs a decision between a bundled per-track reference (accurate,
   matches "official" numbering, needs manual upkeep as LMU adds tracks) and geometric
   auto-detection from position/steering data (no external dependency, degrades gracefully
   to new tracks, not guaranteed to match official numbering) before building §8.5's
   segment navigation.
9. **Any ToS/legal consideration** reading LMU's telemetry export format — existing
   community tools suggest it's fine, but worth the user's own confirmation.
10. **CI wiring for `integration_test`** — the Phase 0 spike proved the pattern locally on
    macOS; still need to wire `flutter test integration_test/... -d <platform>` into the
    GitHub Actions matrix (§13) for windows-latest/ubuntu-latest too, where the native
    library download/link step may behave differently.

## 16. Next Steps

1. ~~User shares sample `.duckdb` file(s)~~ — done: 3 samples (Practice/Qualify/Race)
   inspected directly with DuckDB; §5 and §8 updated from assumption to confirmed fact.
2. ~~Reference-app screenshots~~ — done: GO FAST and MyLMU reviewed directly (§7); §8
   expanded with 3 new features (Events Log, Driving Technique Analysis, Car Behavior
   Analysis) and §8.5/§8.8 refined with concrete UI patterns (N-way comparison, segment
   navigation, solid/dotted overlay convention).
3. Resolve the still-open items in §15 that are cheap to close now (flag/enum decoding,
   FL/FR/RL/RR order, corner/segment numbering approach) before they block feature work.
4. Scaffold the Flutter project (Phase 0) and spike DuckDB access + chart rendering
   against the real samples — including a large/synthetic file for the web memory
   question (§15.1), since all 3 samples on hand are short sessions.
