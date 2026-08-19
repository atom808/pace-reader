# Pace Reader — Product & Technical Spec

**Status:** Draft v0.7 — Phase 0 complete; Phase 1's data layer, file import, Session
Overview and lap time table built and verified against real data. Building it corrected two claims that v0.6 stated as confirmed
fact: §8.3's sector-3 formula (the sector splits are cumulative, and the stated formula
produced *negative* sector times) and §5.2's master-row mapping (off by up to 0.5 s on slow
channels). §15.2's decimation-performance question is answered on the query side.
**Owner:** Diego Pestana
**Last updated:** 2026-08-18

> §5 (Data Model) has been verified directly against three real `.duckdb` samples — one
> each of Practice, Qualify, and Race, across three different tracks/cars/classes — and is
> written as confirmed fact, with any remaining gaps called out explicitly rather than
> assumed. **Re-verification note (v0.6):** several §5 claims that read as "confirmed
> across all three samples" had in fact only been checked against the Race sample, and
> three of them were wrong when checked against the other two — the `origin` constant
> (§5.2), the exactness of `channelsList.frequency` (§5.2), and the Hypercar-exclusivity
> of the energy channels (§5.4). They are corrected in place below, and each now states
> *which* samples back it. Every channel and event name §5/§8 references was also checked
> to exist in the catalogs: all 100 of them do, with none misclassified channel-vs-event. §7 (Prior Art) has been verified directly against screenshots of two reference
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

> **v0.7 note.** The same pattern that produced v0.6's corrections repeated here, one level
> down: claims verified by *reading* the data were right about structure and wrong about
> semantics. Both v0.7 corrections (§8.3.1, §5.2) were caught only by checking a derivation
> against an independent ground truth — `Current Sector` transition timestamps for the
> sector splits, and the `1/hz` grid spacing for the row mapping — rather than by
> inspecting the schema more carefully. Worth remembering before the next "confirmed
> against real samples" claim: confirming that a column *exists and holds plausible
> numbers* is not the same as confirming what it *means*.

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
   `TrackName`, `TrackLayout`, `WeatherConditions`, `CarName`, `CarClass`, `CarSetup`, and
   `Version`. Exactly these 12 keys, in all three samples.
   - `Version` is `"1"` in all three — a **format version stamp the file carries about
     itself**, and the natural thing for §10's resilience requirement to gate on: an
     unrecognized `Version` is the earliest and cheapest point to fail with a clear
     "recorded by a newer/older LMU than this build understands" error, rather than
     discovering the mismatch later as a missing table or a wrongly-shaped column.
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
     `Ground Speed`, `Steering Pos`, per-corner tire-zone temps, etc.).
     - **Correcting v0.5:** the earlier claim that "there is no shared sample clock across
       channels — each is an independent fixed-rate array" is wrong, and the truth is more
       useful. Every channel is a **decimation of one shared 100 Hz master grid**: in all
       three samples, 54 of the 56 channel tables satisfy
       `rows == ceil(rows_of_100Hz_channel * frequency / 100)` exactly. So channels do
       share a clock, which is why channel-against-channel alignment is exact rather than
       approximate. The two exceptions matter and are covered in §5.2.
   - **Events** (listed in `eventsList`): sparse, with an explicit `ts DOUBLE` (elapsed
     seconds) + `value`/`value1`..`value4`, one row **per change**, not per fixed interval
     — e.g. `Gear` (758 rows across a 22.5-minute race), `Lap` (one row per lap start), `TC`/
     `ABS` (one row per activation edge, `BOOLEAN` value), and many driver-adjustable
     settings that end up with just a **single row** in a given file simply because they
     never changed during that session (`TCLevel`, `ABSLevel`, `Brake Bias Rear`,
     `Headlights State`, `Yellow Flag State` in these samples). This is the *common* case,
     not a footnote: **21–25 of the 42 event tables hold exactly one row** in each sample
     (Practice 22, Qualify 25, Race 21) — over half — and which ones varies by session
     (`ABS` and `Sector1/2/3 Flag` are single-row in the Qualify sample but not the others;
     `In Pits` is single-row in the Race sample). Any event-driven UI therefore has to
     treat "one row, never changed" as the norm and render it as a constant rather than an
     empty chart. Getting "value at time t" for an event means a backward/as-of lookup
     (latest row with `ts <= t`), not an equality/index lookup.
   - **No event table is ever empty** in any of the three samples — every one of the 42 has
     at least one row. Useful invariant: an as-of lookup always has *something* to resolve
     to, so the only unresolvable case is a `ts` earlier than the table's first row (see the
     ASOF caveat in §5.2).

### 5.2 Reconstructing a shared time axis

Because channels carry no timestamp, aligning multiple channels — or a channel against an
event — needs a synthetic clock: `elapsed_time = origin + row_index / frequency`, where
`frequency` comes from `channelsList` and `origin` is a shared start offset. `GPS Time` is
itself a 100 Hz *channel* (despite the name, it appears to just be the elapsed-seconds
master clock) and is the ground truth to check the derived formula against rather than
trusting it blindly.

**`origin` is per-file, not a constant.** v0.5 described it as "~23.6 s in all three
samples"; that is the Race sample's value only. Measured: **Practice 381.0875 s, Qualify
34.5650 s, Race 23.5975 s** — a wide spread, consistent with "time since the telemetry
system was armed" rather than anything session-relative, and emphatically not a number to
hardcode or sanity-check against. What *is* confirmed across all three is the far more
useful property: `GPS Time`'s first value and `MIN(ts)` of **all 42 event tables** agree
with each other to the bit, in every sample (42/42, three times over). So the origin has
one unambiguous definition per file — read it, don't assume it.

**Three ways the naive formula goes wrong**, all measured, none hypothetical:

1. **`channelsList.frequency` is nominal, not exact, for two channels.** `Engine Oil Temp`
   and `Engine Water Temp` declare 7 Hz but actually sample at ~7.0171 Hz (they are the
   only 2 of 56 channels that break the master-grid identity in §5.1). Consequence:
   `origin + row_index / 7` walks *forward* of real time — by **+3.28 s at the end of the
   22-minute Race sample**, and it grows linearly with session length, so roughly +53 s
   over a 6-hour stint. The derived timestamp of the last sample lands after the recording
   itself ended, which is how it's provable rather than merely suspected. Every other
   channel's declared frequency reproduces its row count exactly.
2. **Recordings contain discontinuities.** `GPS Time` advances by exactly 0.01 s per row
   everywhere except at isolated gaps: **one 0.3875 s gap in the Practice sample (170 rows
   from the end) and one 0.3800 s gap in the Qualify sample (46 rows from the end); the
   Race sample has none.** A row-index clock cannot see a gap, so every sample *after* one
   is permanently offset by the gap's length — silently, with no error. In these three
   samples both gaps fall after the last lap boundary, so no lap-level analysis in them is
   affected; that is luck about where recordings were stopped, not a property to rely on. A
   long stint with garage returns or a mid-session stall could plausibly put gaps in the
   middle, and their offsets accumulate.
3. **Channels are gap-consistent with each other, but not with events.** Because all
   channels ride the same master grid (§5.1), a gap shifts every channel identically —
   channel-vs-channel alignment stays correct through a gap. Event `ts` values, however,
   are real elapsed time. So a discontinuity breaks **channel-vs-event** alignment
   specifically, which is exactly the `ASOF JOIN` path in §9.2.

**The robust derivation** — and what the repository layer should actually implement — is to
stop synthesizing the clock and read it: map channel row `i` to a master row and take that
row's `GPS Time` value as the timestamp. That is immune to all three failure modes at once
(a wrong declared frequency, a gap, and any future rate that isn't an integer divisor of
100 Hz), and it costs one extra join against a column the file already carries. Keep
`origin + row_index / frequency` as the fast path only where it has been checked to agree,
and keep `frequency` for display/labelling.

**Which master row, corrected in v0.7.** v0.6 specified `round(i * n_gpstime / rows)` for
every channel. Right instinct, imprecise formula: because `rows` is
`ceil(n_gpstime * hz / 100)`, that ratio sits slightly *below* the true stride and
compresses the axis. Measured, the last sample of a 1 Hz channel lands **0.41–0.50 s
early** (`Track Temperature`, `Wind Speed`), and the 2 Hz `Time Behind Next` — which
§8.9's race-pace chart plots directly — lands 0.32–0.41 s early. The error grows as the
channel's rate falls, so the channels it damages most are exactly the slow ones whose
samples are furthest apart.

The exact mapping is the **integer stride**, `i * (100 / hz)`. §5.1's identity
`rows == ceil(n_gpstime * hz / 100)` is precisely the row count of "keep every stride-th
master row starting at row 0", so wherever that identity holds the stride isn't an
approximation of the decimation — it *is* the decimation, inverted. Verified: mapped
timestamps land on an exactly `1/hz`-spaced grid, with **zero deviation** across the
gapless Race sample, and the only departures in the other two samples are precisely the
known recording discontinuities — which is the derivation working, since a correct clock
is *supposed* to see a gap.

The ratio formula survives as the fallback for exactly the two channels that need it:
`Engine Oil Temp`/`Engine Water Temp` declare 7 Hz, `100/7` isn't an integer, and no
stride model exists for them. There the ratio is both correct in spirit and the best of
the candidates measured (~0.04 s worst case). So the rule is: **integer stride where the
master-grid identity holds, row-count ratio where it doesn't** — and the identity is
already computed per channel, so choosing between them is free.

Two notes on measuring this. The lap-boundary check below **cannot** discriminate between
the two mappings at 10 Hz: they differ by 1–2 master rows there, far inside one 10 Hz
sample period. And the raw `ASOF`-based version of that check conflates alignment error
with sampling granularity — interpolating between the bracketing samples instead drops the
same measurement from 5.64 m worst case to **1.68 m**, which says most of that 5.64 m was
never alignment error at all.

**Independently validated.** Using `Lap Dist ≈ 0` at each `Lap` event timestamp as external
ground truth — a lap boundary *is* the start/finish line, so a correctly aligned
channel-vs-event join must place the car at the line — the derivation resolves all 26 lap
boundaries across the three samples to within **5.64 m worst case, 2.4 m mean**. One 10 Hz
`Lap Dist` sample at 200 km/h covers 5.6 m, so that is sub-sample-period accuracy: the
approach is sound, and §15.3's confirmation stands. (Lap 0 must be excluded from this
check — it starts in the garage, not at the line.)

Practical consequences for the repository layer (§9.2):
- Use `row_number() OVER ()` over an unfiltered scan as the authoritative sample index per
  channel table. DuckDB doesn't formally guarantee scan order, but these files are written
  once and never mutated, so insertion-order scanning is safe in practice here.
- Aligning a fast channel (100 Hz) against a slow one (1–20 Hz) or against an event table
  is a resample/as-of problem, not an equality join — DuckDB's native `ASOF JOIN` ("latest
  matching row at or before this timestamp") is the right primitive here and should replace
  any hand-rolled backward-scan logic.
  - **`ASOF JOIN` is inner by default, and that silently drops rows.** Every event table's
    first `ts` equals `origin` (§5.2), so any channel sample timed *before* `origin` — which
    is what happens if the derivation forgets to add `origin`, or if a gap shifts samples
    backwards — finds no match and vanishes from the result instead of erroring. A query
    that looks like it works can be missing its first N seconds. Use `ASOF LEFT JOIN` and
    treat a null as an explicit "no value yet", so the failure is visible rather than
    cosmetic. (The Phase 0 spike shipped exactly this bug — see §14.)
- Lap boundaries come from the `Lap` event table (`ts`, lap number, incrementing each lap
  start): slicing a channel into "lap N" means filtering its synthetic-time column between
  two consecutive `Lap` timestamps. `Lap Dist`/`Total Dist` (both channels, 10 Hz) give the
  distance axis for distance-based charts — combining them with a different-frequency
  channel needs the same synthetic-time alignment.
  - **`Lap` values are 0-based, and its row count is not the lap count.** Measured: values
    run `0..N-1` (Practice 0–3, Qualify 0–4, Race 0–19). Row 0 marks the recording start
    with the car in the garage/pits, not a start/finish crossing, and the final row opens a
    lap that the file has no closing boundary for. So `COUNT(*)` on `Lap` gives **at most
    N-1 complete, timeable laps**, and any lap number shown to a user needs `+1` or it will
    read "Lap 0". This affects §8.2's lap count and §8.3's lap table directly.

### 5.3 Per-corner value ordering (partially confirmed)

Multi-value channels/events use `value1`..`value4` with no embedded labels. Cross-checking
asymmetric setup values (e.g. `TyresPressure`'s four values consistently pair up as
(1,2) ≈ front vs. (3,4) ≈ rear; same pairing in `RideHeights`) confirms a **front-pair,
then rear-pair** grouping, consistent with the common rFactor2 wheel-order convention
(front-left, front-right, rear-left, rear-right). **The left/right assignment within each
axle is not independently confirmed from data alone** — verify against a setup with known
asymmetric left/right values (or the rF2 shared-memory plugin's documented wheel order)
before labeling any per-corner chart. Mislabeling FL/FR would be a subtle, easy-to-miss bug.

**The resolution path is cheaper than it looks, though: the answer key is already inside
the file.** The embedded `CarSetup` JSON (§5.1) names corners *explicitly* — keys like
`WM_PRESSURE-W_FL`, `-W_FR`, `-W_RL`, `-W_RR`, across **15 per-corner setup groups** in
every sample. So no external rF2 reference is needed: one telemetry file whose setup has
any left-right asymmetry (different pressures, camber, or spring rates side to side)
resolves the ordering by direct cross-reference against the matching `value1`..`value4`
channel. The blocker is only that **all 15 groups are left/right symmetric in all three
samples on hand** — a symmetric setup is the norm on a road circuit, so this may need a
deliberately asymmetric test setup rather than waiting for one to turn up. Cheap to close
(one practice out-lap with, say, 2 psi of cross split), and worth closing before any
per-corner chart ships a corner label.

### 5.4 Notable domain-specific channels

- **Hypercar energy management**: `SoC`, `Virtual Energy`, `Regen Rate` (separate from
  `Fuel Level`). **Correcting v0.5**, which read these as Hypercar-specific because they
  were spotted in the Spa Qualify sample (`CarClass = "Hyper"`): the schema is *identical*
  in all three files (§5), so all three carry all three tables — presence proves nothing
  about class. What differs is the contents, and only partly as expected:
  - `SoC` and `Regen Rate` are **degenerate in the GT3 files** — every row is exactly `0.0`
    (1 distinct value across 6.5k–26.8k rows), versus 6,631 and 13,721 distinct values in
    the Hypercar file. These two are effectively Hypercar-only *in content*.
  - `Virtual Energy` is **populated and meaningful in GT3 too** (Practice 91.5→100.0 over
    4,688 distinct values; Race 5.6→47.0 over 19,272), alongside a normally-varying
    `Fuel Level`. It is not a Hypercar-only signal.
  - Consequence for §8.7: **branch on `metadata.CarClass`, never on table presence**, and
    guard each energy channel with a degenerate-series check (single distinct value ⇒ don't
    plot it) so a GT3 session doesn't render a flat zero line labelled "State of Charge".
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
- Observed file sizes: Practice (Interlagos, GT3) 8.8 MB over 5.5 min recorded, Qualify
  (Spa, Hyper) 13.6 MB over 9.8 min, Race (Sebring, GT3, 20 `Lap` rows ⇒ 19 complete laps,
  22.3 min recorded) 25.4 MB. Per recorded minute that is **1.13 / 1.39 / 1.61 MB** — so
  the rate is a **range of ~1.1–1.6 MB per minute, not the single ~1.1 MB/min v0.5 quoted
  from the Race sample alone**, and shorter sessions sit at the expensive end (fixed
  per-table overhead amortizes worse over less driving). Extrapolating on the **upper**
  bound rather than the lower one, since designing against the cheapest sample is the wrong
  direction for a memory ceiling: a ~6 h race lands at ≈0.4–0.6 GB and a 24 h race at
  **≈1.6–2.3 GB** — a real number to design around in §9.5/§10, not a hypothetical
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
import every time. Keep a local index (track, **layout**, car, class, session type, date, best lap — all read
straight from `metadata`) so the library list doesn't need to re-open every file on every
launch (see §9.6). Recent files, search/filter by track/car/class.

**`TrackLayout` is a load-bearing dimension, not a display detail**, and the samples prove
it: the "Sebring International Raceway" Race sample is `TrackLayout = "Sebring School
Circuit"` — a 3.08 km layout, roughly half the 6.0 km full course, with lap times to match.
Index and group on `(TrackName, TrackLayout)`; keying on `TrackName` alone would silently
compare laps from different circuits in the same "best lap" column, which is the kind of
wrong that looks like a plausible number rather than an error.

### 8.2 Session Overview
Track, car, class, session type, driver, weather (`metadata`), duration and lap count
(derived from the `Lap` event table — note its 0-based values and that `COUNT(*)` counts
lap *starts*, so completed laps is one fewer; see §5.2), best lap / theoretical best
(`Best LapTime`, `Best Sector1/2`).

### 8.3 Lap Time Analysis
Lap time table with sector splits (`Current/Last/Best Sector1/2`, `Sector1/2/3 Flag`),
delta to personal best and to a chosen reference lap, consistency (std. dev., outlier laps
flagged), lap time trend across a stint or full session. Annotate laps affected by
`Yellow Flag State`, `LastImpactMagnitude`, or `WheelsDetached` so a slow lap's cause is
visible, not just its time.

#### 8.3.1 Lap and sector event semantics (corrected in v0.7)

Four things about how laps and sectors are actually recorded, each measured against all
three samples. v0.6 got the third one wrong in a way that produced negative sector times.

1. **A lap's time is reported at its *end* boundary.** `Lap Time`, `Last Sector1` and
   `Last Sector2` are emitted when a lap completes — the same instant as the *next* lap's
   `Lap` event. So the time of the lap starting at `ts` is the `Lap Time` row at
   `lead(ts)`. Every one of those timestamps is *exactly* equal to some `Lap` timestamp
   (0 orphans, all three samples), so this is an equality join, not an `ASOF` one — and it
   has to be: laps legitimately have no `Lap Time` row at all (an untimed out-lap; the
   Practice and Qualify samples both start with one), and `ASOF` would resolve those to
   the *previous* lap's time instead of to nothing, silently attributing one lap's pace to
   another.
2. **`0.0` means "not recorded", not a zero-second lap or sector.** The game writes it for
   invalidated laps (2 of 19 in the Race sample, 1 of 4 in Qualify) and for sectors it
   didn't time (3 of 19 Race laps record S1 but write `0.0` for S2, while keeping a
   perfectly valid lap time). Taken at face value it produces a fastest lap of `0.000`. A
   missing sector split must **not** disqualify the lap time it belongs to.
3. **`Last Sector2`/`Current Sector2` are *cumulative* splits, not sector durations.**
   `Last Sector1` is S1's duration, but `Last Sector2` is elapsed time at the S2/S3
   boundary (S1+S2). v0.6 specified `s3 = lap - s1 - s2`, which double-subtracts S1 and is
   wrong by up to **33.4 s** — it yields *negative* sector-3 times (-5.371 s and -4.406 s
   on the Practice sample), which is how it's provable rather than merely suspected. The
   correct derivations, verified against `Current Sector` transition timestamps across all
   16 timed laps in the three samples to within **0.014 s** (one event-timestamp tick):

   ```
   s1_duration = Last Sector1
   s2_duration = Last Sector2 - Last Sector1
   s3_duration = Lap Time     - Last Sector2
   ```

   `Current Sector` is the ground truth that settles it, and its codes cycle **1 → 2 → 0**,
   so **code 0 is sector 3** rather than a missing value.
4. **Never derive a lap time from boundary timestamps.** On the Race sample's lap 0 the
   game reports 71.241 s while the wall-clock span between `Lap` events is 172.222 s,
   because the span covers garage and grid time and the game times only from the start.
   The span is a useful diagnostic and nothing more. Lap 0 is the garage lap in every
   sample and must be excluded from pace statistics (§5.2 already excludes it from
   alignment checks for the same reason).

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
Branches by class (§5.4) on **`metadata.CarClass`, not on which tables exist** — all files
carry all energy tables. `SoC`/`Regen Rate` are all-zero in GT3 files and should be hidden
there; `Fuel Level` and `Virtual Energy` are both live for GT3 *and* Hypercar. Per-lap
consumption, estimated laps/time remaining in a stint, pit stop markers (`In Pits` — note
it is single-row in the Race sample, so "no pit stop recorded" is a normal case to render,
not an error) with in/out-lap deltas.

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
- **Time-axis derivation, read rather than synthesized**: channels have no timestamp
  column, so this layer owns producing one and exposes already time-aligned results to
  feature code — features should never need to know a given channel's native Hz or that it
  lacks a `ts` column. Per §5.2 the derivation **maps channel row `i` to a master row and
  reads that row's `GPS Time` value**, rather than computing
  `origin + row_index / frequency` and trusting it. That choice is not
  defensive-programming taste; it is the only version that survives the three measured
  failure modes in §5.2 (two channels whose declared frequency is wrong by 0.25%, isolated
  recording gaps that a row-index clock cannot see, and the fact that channel gaps and
  event `ts` disagree). `origin` is read from the file, never assumed.
  - **Which master row** is the integer stride `i * (100 / hz)` wherever §5.1's
    master-grid identity holds, falling back to `round(i * n_gpstime / rows)` only for the
    two channels where it doesn't — see §5.2's v0.7 correction, and note the ratio formula
    alone costs up to 0.5 s on a 1 Hz channel.
  - **Regression-test the derivation, don't just spike it once.** The invariant worth
    asserting per file is the master-grid identity from §5.1 —
    `rows == ceil(n_gpstime * frequency / 100)` — which holds for 54 of 56 channels and
    names the exact two that need the mapped path. Plus the external check from §5.2:
    every lap boundary must resolve to `Lap Dist ≈ 0`. Both are cheap enough to run on
    every fixture, and either one would have caught the two bugs §14 describes.
- **Event-to-channel alignment**: use DuckDB's native `ASOF JOIN` to answer "what was this
  event's value as of this channel sample's time" — e.g. resolving `Gear` or `TC` state at
  each `Engine RPM` sample — rather than a hand-rolled backward scan. Use the **`LEFT`**
  variant: a plain `ASOF JOIN` is inner and silently discards pre-`origin` samples instead
  of surfacing the misalignment (§5.2, §14).
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
confirmed samples (§5.5), a ~22.3-minute Race recording holds 134,059 rows for a
100 Hz channel; linearly extrapolated, a 6-hour endurance stint would put a single 100 Hz
channel around 2.16M rows, and there are **20 channels at 100 Hz** (counted in all three
samples — v0.5's "roughly 15" understated the budget by a third; the 20 are `Clutch RPM`,
`Engine RPM`, `FFB Output`, `Front3rdDeflection`, `FrontRideHeight`, `GPS Time`,
`Ground Speed`, `Rear3rdDeflection`, `RearRideHeight`, `Regen Rate`, `RideHeights`,
`Steering Pos`, `Steering Pos Unfiltered`, `Steering Shaft Torque`, `Susp Pos`,
`Turbo Boost Pressure`, `TyresTempCentre`, `TyresTempLeft`, `TyresTempRight`,
`Wheel Speed`, four of which are per-corner and so carry 4 values per row) — so a "load
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
`.duckdb` files, to index imported sessions (path, track, **layout**, car, class, date,
best lap) for the Session Library (§8.1) and cross-session personal-best tracking without
re-opening every large file on every app launch. Populate/update this index at import time.
Personal bests must be scoped per `(TrackName, TrackLayout)` for the reason in §8.1.

Worth recording two other cheap things at import time, since the file is already open and
both are otherwise invisible later: the file's `metadata.Version` (§5.1), so an unreadable
future format is caught at import rather than mid-analysis, and the count of recording
discontinuities found by the master-clock scan (§5.2), so a session whose timing needs the
mapped derivation is flagged rather than quietly trusted.

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
- **Numeral/data voice**: **JetBrains Mono, bundled as a font asset** (not the
  system-monospace stack v0.5 specified), with tabular figures enabled via Flutter's
  `FontFeature.tabularFigures()`, for every numeral — lap times, telemetry values, cursor
  readouts, stat cards. General Sans does **not** support tabular figures, which matters
  here specifically: digit-for-digit column alignment on ticking/updating numeric displays
  is a real requirement for this app, not a nice-to-have, so numerals are deliberately kept
  on a typeface that has proper tabular-figure support rather than General Sans. Changed
  from a system stack to a bundled asset during Phase 0 for the same reason General Sans is
  self-hosted: a system stack resolves to a *different* face per platform (SF Mono on macOS,
  Consolas on Windows, whatever the distro ships on Linux, unpredictable on Web), which
  means different digit widths and different golden-test output on every target — directly
  at odds with §10's cross-platform-parity requirement and §12's golden tests. JetBrains
  Mono is OFL-1.1, so bundling is unrestricted.
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
| Typography | General Sans (UI voice) + JetBrains Mono w/ tabular figures (numeral voice) — both self-hosted assets | §9.7.7 |
| File selection | `file_picker`, `desktop_drop` (drag-and-drop on desktop) | |
| Models | `freezed` + `json_serializable` | |
| Lint | `flutter_lints` (or `very_good_analysis`) | |
| Testing | `flutter_test`, `mocktail`, golden testing (`alchemist` or `golden_toolkit`), `integration_test` | §12 |
| CI | GitHub Actions, matrix build across windows-latest/macos-latest/ubuntu-latest + web | §13 |

## 12. Testing Strategy

- **Unit tests** for repository/query logic, run against small fixture `.duckdb` files
  (trimmed versions of the 3 real samples, e.g. first N laps only, to keep them small and
  checked into the repo) — this is the highest-value test surface given how much logic
  lives in SQL/mapping (time-axis derivation, ASOF alignment, lap slicing). Note that
  `samples/` is git-ignored (real telemetry, hundreds of MB), so fixtures are the *only*
  data CI ever sees: whatever a fixture gets wrong, CI cannot catch.
  - **A trimmed fixture must preserve the master-grid identity from §5.1**
    (`rows == ceil(n_gpstime * frequency / 100)` per channel), or it stops being
    representative of the thing under test. The original hand-trim did not: it truncated
    each channel by `elapsed * its own frequency`, which over-kept 4–5 rows on every
    sub-100 Hz channel and left **36 of 56 channels in the fixture inconsistent with its own
    `GPS Time` row count** — manufacturing timing errors up to +3.74 s that do not exist in
    the source file, in the exact dimension the fixture was created to validate. Trim
    against the master grid instead: keep `ceil(kept_gpstime_rows * frequency / 100)` rows.
    `tool/make_fixture.py` implements this and is checked in so the fixture is reproducible
    rather than a one-off artifact described only in prose.
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
  a trimmed real fixture (`test/fixtures/sebring_race_laps0_3.duckdb`) on macOS and confirmed
  metadata/catalog reads work, the time-axis derivation from §5.2/§9.2 matches `GPS Time`,
  and DuckDB's `ASOF JOIN` resolves an event's value as of a channel sample. §15's
  time-axis-derivation question is resolved (the "Still open" list is renumbered, so it is
  named rather than numbered here) — but the v0.5 write-up of this spike claimed more than
  the spike actually tested, and the audit that produced v0.6 found three concrete problems, all now fixed:
  - **It validated on the one sample that couldn't fail.** The fixture is lap 1 of the Race
    file — the only one of the three with no recording discontinuity, and 172 s of a
    1,341 s recording. "Sub-millisecond precision" was true and also unfalsifiable: the
    Practice and Qualify samples each contain a gap after which the same formula is off by
    ~0.38 s, and two channels in *every* sample drift by 0.25% (§5.2). Re-verifying across
    all three samples is what surfaced those.
  - **The `ASOF JOIN` test carried a real bug**: its channel grid was
    `(row_number() - 1) / 100.0` with **`origin` omitted**, so it joined a 0-based clock
    against event timestamps that start at `origin` (23.6 s in that file). It passed only
    because a plain `ASOF JOIN` is inner — the ~2,360 unmatched samples were silently
    dropped and the surviving rows still held plausible gear numbers. A test that would have
    failed loudly with `ASOF LEFT JOIN` instead passed quietly. Now fixed, and §5.2/§9.2
    both call out the inner-join trap.
  - **The fixture itself was mis-trimmed** in a way that breaks the very property it was
    used to check — 36 of 56 channels inconsistent with its own `GPS Time` row count (§12).
    Regenerated via the now-checked-in `tool/make_fixture.py`.
  The spike now asserts the master-grid identity, scans for discontinuities, checks declared
  frequencies against row counts, and verifies lap boundaries land on the start/finish line
  (§9.2) — the four checks that turn "we spiked it once" into a regression net.
  Still open from the original Phase 0 list: web memory behavior with a large/synthetic
  file, CI wiring for the integration test on Windows/Linux runners, and the chart core's
  decimation/viewport strategy (that's Phase 1 work now that a chart core exists to spike).
  Also still unbuilt, though §9.1/§15 imply otherwise: `lib/data/` (repositories, models,
  DuckDB layer), `widgets/charting/`, and `widgets/fl_chart_theme/` are empty directory
  placeholders — Phase 1's first task, not existing code.
- **Phase 1 — MVP:** single-file import (desktop + web), Session Overview, lap time table,
  single-lap telemetry trace (speed/throttle/brake/gear vs. distance), basic 2D track map.
  ~~`lib/data/` (models, DuckDB layer, shared repositories)~~ — done, and it corrected two
  §5/§8 claims in the process (§8.3.1's cumulative sector splits, §5.2's master-row
  mapping), both of which shipped as wrong formulas that real data refuted. What exists:
  `freezed` models, catalog-driven discovery, the time-axis derivation, min/max
  decimation, lap/sector derivation, and `SessionRepository`/`LapRepository`/
  `TelemetryRepository`, behind a `TelemetryQueryExecutor` seam. Verified by 77 unit tests
  (`flutter test`, no device) plus 24 `integration_test` cases against the real fixture.
  - **The SQL builders are pure functions on purpose.** `dart_duckdb`'s native library
    only links into a compiled app, so anything holding a real connection can only run
    under `integration_test` — which on CI means "not without a device". Keeping SQL
    construction and every derivation pure puts the highest-risk logic inside the test
    surface a plain `flutter test` can always execute; the integration suite then checks
    that the SQL actually runs and agrees with the file's own ground truth.
  - **Both platforms `ATTACH` rather than open directly.** A `.duckdb` file *is* a
    database, so the web path can't hand DuckDB-Wasm a registered buffer to open;
    unifying on `ATTACH` + `USE` means desktop and web run byte-identical SQL instead of
    one carrying schema-qualified names. `READ_ONLY` also makes §3's "no writing back to
    game files" unviolatable rather than merely intended — verified, including that a
    failed open leaves no file behind.
  - **The fixture now covers laps 0–3, not lap 0.** A lap-0-only fixture contains no
    *flying* lap at all (lap 0 is the garage lap), so CI could not check any per-lap
    derivation on the case that actually occurs — which is precisely how §8.3's sector bug
    would have survived. Costs ~3 MB; see `test/fixtures/README.md`.
  ~~Import, Session Overview, and the lap time table~~ — done. `file_picker` +
  `desktop_drop` feed one `TelemetrySource` into the providers; §8.2 and §8.3 are built on
  top. Verified end-to-end by `integration_test/app_flow_test.dart`, which imports the real
  fixture through the real controller and reads the rendered values back out. Total suite:
  104 unit tests, 37 integration cases.
  - **Which session is open is app state, not a route parameter.** A route parameter can't
    express both platforms — on web a session is a byte buffer with no path to put in a URL
    (§9.2) — so encoding it in the path would make navigation work differently per target.
    Deep-linking to a session is therefore a desktop-only capability if it's ever wanted,
    not something the route shape should assume.
  - **The lap table shows every lap, including the ones that aren't comparable**, each
    marked with *why* (out lap / no time / partial sectors / incomplete). Hiding them would
    make lap numbering skip for no visible reason, and "why is lap 6 missing?" is a worse
    question than "why is lap 6 greyed out?". They're excluded from the statistics, not
    from the view.
  - Still to do in Phase 1: the web wiring is **not** done — `web/index.html` has no
    DuckDB-Wasm/Arrow script setup, so the bytes path is written but unexercised, and the
    upstream setup loads both from a CDN, which needs self-hosting to satisfy §10's
    offline-first requirement. Then `widgets/charting/`, the single-lap trace, and the 2D
    track map.
- **Package upgrade (v0.7):** Riverpod 2→3, `freezed` 3→4, `file_picker` 11→12,
  `riverpod_generator` 2→4. Three things came out of it worth recording:
  - **Riverpod 3 retries failed providers automatically**, doubling the delay up to 6.4 s
    and never giving up. That is wrong for every failure this app produces — a corrupt
    file, an unsupported format version, a schema mismatch are all *deterministic*, so
    retrying re-reads the same broken file on a timer forever. Every data provider now opts
    out via `retry: _neverRetry`. Found because a test hung for ten minutes: the pending
    retry timer meant the app never reached an idle frame.
  - **`TelemetrySource` needs value equality**, because it is the key of the family that
    owns the open DuckDB connection. Without it, a widget rebuilding
    `TelemetrySource.path(samePath)` produces a key the family has never seen and the same
    file is reopened — catalog re-read and clock re-scanned — on every rebuild.
  - **`build.yaml` is no longer a workaround.** The old pinned `analyzer` (language 3.9.0)
    crashed on Dart 3.13's dot-shorthand syntax; `analyzer` 13.3.0 fixed it. The file stays
    as a build-time optimisation (7 inputs instead of 116) and is now scoped to all of
    `lib/**` rather than to specific directories, since a narrower include silently
    generates *nothing* for an annotation added elsewhere.
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
- **Time-axis derivation** — confirmed, but by a different route than v0.5 recorded, and
  the residual risk it named was the wrong one. Validated across **all three samples in
  full** (not one lap of one file) against two independent ground truths: `GPS Time`, and
  `Lap Dist ≈ 0` at all 26 lap boundaries (worst case 5.64 m — inside one 10 Hz sample
  period). `ASOF JOIN` does resolve event-to-channel alignment correctly, in its `LEFT`
  form. The derivation that is confirmed is the master-clock mapping in §5.2, *not* the
  naive `origin + row_index / frequency`, which measurably fails in three ways (nominal
  frequency on two channels, recording discontinuities, and channel-vs-event divergence
  across a gap).
  - v0.5's stated residual — accumulated floating-point drift over a multi-hour file — is
    a non-issue and was never the real risk: double-precision error at 100 Hz over 24 h
    stays many orders of magnitude below one sample period. The real risks were the three
    measured ones above, which a single-sample spike structurally could not surface.
- **dart_duckdb on macOS requires App Sandbox off** — confirmed during the same spike
  (§13); a sandboxed build can't open an arbitrary file path at all.

**Still open:**

1. **Web memory ceiling vs. real file sizes** — §5.5 extrapolates full-length endurance
   files into the multi-gigabyte range (~1.6 GB for 24 h). `dart_duckdb`'s web path loads
   the whole file's bytes into the browser before DuckDB-Wasm can open it (§9.2) — needs a
   concrete test with a large synthetic or real file, not just the small samples on hand,
   since browser tabs have materially less addressable memory than a desktop process.
2. **Chart/decimation performance at scale** — *query* side answered in v0.7, *render*
   side still open. Min/max-per-bucket decimation was measured against the real Race
   sample and against synthetic tables built to the §9.5 extrapolation: **~4 ms** for a
   real 22-minute session at 1200 buckets, **~42 ms** at 6 h (2.14M rows), **~156 ms** at
   24 h (8.7M rows), and **~24 ms** for a zoomed 60-second window of that 24-hour table.
   So a full-session overview is a one-shot cost at open/viewport-change, not a per-frame
   one, and interactive zooming stays comfortably inside a frame budget — scrubbing
   re-queries nothing, since the cursor moves over already-fetched points. Two caveats
   before this is closed: the numbers are from DuckDB itself and exclude Dart result
   marshalling, and nothing has yet *rendered* those points, so the remaining risk moved
   from the query to `widgets/charting/`, which is still an empty directory.
3. **Flag/enum decoding** — `Sector1/2/3 Flag`, `Finish Status`, `SurfaceTypes` store
   integer codes with no confirmed meaning (§5.4). Needed before flag/incident annotations
   (§8.3) can be built.
4. **FL/FR/RL/RR left/right order** — front-vs-rear pairing is confirmed from data, but
   left/right within each axle is not (§5.3). **Now known to be closable without any
   external reference**: the embedded `CarSetup` JSON names corners explicitly
   (`WM_PRESSURE-W_FL`/`_FR`/`_RL`/`_RR`, 15 per-corner groups), so one file with an
   asymmetric left/right setup resolves it by cross-reference. All 15 groups are symmetric
   in all three samples on hand, so this needs a deliberately asymmetric test setup — one
   out-lap with a cross split — rather than more waiting. Blocks any per-corner *label*
   (§8.6), not per-corner data.
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
    library download/link step may behave differently. Worth noting there is **no
    `.github/workflows/` in the repo yet** — §13's matrix is a plan, not a pipeline, so
    nothing currently runs `flutter analyze`/`flutter test` on push.
11. **Recording discontinuities: how common mid-session?** — §5.2 measured one ~0.38 s gap
    in 2 of 3 samples, both landing *after* the last lap (recordings being stopped). Whether
    a long stint puts gaps mid-session — garage returns, ESC, a frame-time stall — decides
    whether the master-clock mapping is merely correct-by-construction or actively
    load-bearing. Answerable with the first real endurance file, and cheap to instrument now:
    count gaps at import time and surface them on the Session Overview (§8.2).
12. **Why do `Engine Oil Temp`/`Engine Water Temp` declare 7 Hz but sample at ~7.0171 Hz?**
    — measured identically in all three samples (§5.2), so it's systematic, not jitter. The
    mapped derivation makes it harmless, but the cause is unknown, and an unexplained
    systematic error is worth a second look in case it signals something about how LMU
    writes sub-100 Hz channels generally. Low priority, low cost.

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
