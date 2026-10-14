# Pace Reader — Product & Technical Spec

**Status:** Draft v0.11 — **Phase 2 complete.** Tires & brakes, the persistent Session
Library, lap-pace trend with incident annotations, race pace and gaps, and the setup viewer
join v0.10's reference-lap delta, fuel view and Events Log; §14 has what came out of
building them. v0.11 also closed two of §15's oldest open items from data rather than by
waiting for it: the per-corner wheel order (§5.3, FL/FR/RL/RR, three independent ways) and
the frame cost of scrubbing (§15.3, zero frames over budget in profile mode). And it found
that the export swaps `G Force Lat` and `G Force Long` (§5.4).

**v0.10:** the Events Log, the reference-lap
overlay with its delta trace, and the fuel/energy view. v0.10 also moved
the project onto the newest Flutter stable and every package's newest major on purpose, and
wired CI — including a weekly job that checks it would still pass on the next releases —
so staying current is now the maintained state rather than an occasional chore (§11, §13,
§14). The delta trace is checked against the one number the file can confirm about it, the
difference between two laps' own `Lap Time`s, and lands within 0.0154 s of it on every pair
of laps the samples hold (§8.4).

**Phase 1 (v0.8.1):** the chart core, the single-lap telemetry
trace, the 2D track map and the web wiring are built and verified, joining the data layer,
file import, Session Overview and lap table from v0.7. Building them produced four findings
that are recorded below rather than in a commit message: §8.5's GPS channels are a *local*
frame, not a geographic one, and need a cosine-of-latitude correction that a naive
projection gets wrong by 69%; §9.5's re-query-per-viewport requirement is not load-bearing
at single-lap scope and the arithmetic says why; §9.7.1's channel palette fails an
all-pairs categorical check on a pre-existing pair, which is safe only because §9.5 stacks
one channel per panel; and `dart_duckdb`'s documented web setup contains a latent type
error that only surfaces once the readiness promise is actually awaited.

A fifth arrived from using the app rather than testing it: on macOS the file chooser never
opened at all, because `file_picker` 12 gates it behind an entitlement an unsandboxed build
has no other reason to declare (§13, §15). Recorded here because it is the shape of defect
this spec keeps meeting — one that only a human clicking the real button can reach.
**Owner:** Diego Pestana
**Last updated:** 2026-10-13 (§8.13 specified; another driver's recordings, §15.7)

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
     `"AF Corse 2026 #83:WEC"`) bundling team, season, car number, and a pack tag.
     **Corrected 2026-10-14:** the suffix is not a model code. Across 709 recordings it is
     a series or event pack (`LM` 440, `WEC` 137, `ELMS25` 17, `BRZ` 13, `ELMS` 12, `LGC` 9,
     `BL` 2, none 79), and a custom livery reads `<code> Custom Team <season> #397`. **No
     recording names its make or model**, and neither does the setup JSON. The model comes
     from Pace Reader's catalog, which reads the entry by team, season and class (§15
     item 6). The raw string stays the key for everything that groups or compares.
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
   - **The split between the two lists is not fixed across game builds (2026-10-13).**
     Another driver's two Le Mans recordings from 13 October list 58 channels and 40
     events. `TC` and `SurfaceTypes` are channels there: `TC` is a 100 Hz `BOOLEAN`
     `value`, and `SurfaceTypes` a 5 Hz `value1..4` of `UTINYINT`, with no `ts`. Every
     one of the user's 707 recordings, including those from the same night, has them as
     events. There are still 101 tables, and `Version` is still "1". Code that asks the
     catalog "is `X` an event?" has to handle `X` being a channel (§15.7).
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
approach is sound, and §15's time-axis entry stands. (Lap 0 must be excluded from this
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

### 5.3 Per-corner value ordering (confirmed in v0.11: FL, FR, RL, RR)

**Resolved in v0.11, without the asymmetric setup this section used to call for.** `value1`..
`value4` are **front-left, front-right, rear-left, rear-right**, established three independent
ways across all three samples, each agreeing:

1. **Wheel-speed kinematics — the decisive one.** In a turn the outside wheels travel a longer
   arc, and over one closed lap the heading turns by exactly ±2π, so the per-lap integral of the
   left-minus-right wheel speed is the track width times that angle — no GPS noise, no curvature
   estimate. Measured `∫(value1 − value2) dt` per lap: **−10.56 / −10.58 m** on anti-clockwise
   Interlagos, **+10.26 / +10.24 m** on clockwise Spa, **+10.57 to +10.63 m on all 18** flying
   laps of clockwise Sebring. That is a track width of **1.68 m** (GT3) and 1.63 m (Hypercar)
   with `value1` on the left, and a physically impossible −1.7 m with it on the right. The sign
   flips with circuit direction exactly as it must, and the rear pair (`value3 − value4`)
   matches to 2%. The circuits' directions are checked in the data rather than assumed: the
   projected GPS path winds anti-clockwise at Interlagos (signed lap area +0.396 km²) and
   clockwise at Spa (−0.927 km²), which is reality, so the §8.5.1 frame is not mirrored.
2. **Tyre heat, pressure and wear by circuit direction**, which needs no GPS frame at all: the
   outside tyres of a circuit's dominant turn run hotter and wear faster. Clockwise Sebring,
   lap 18 carcass FL 93.4 °C vs FR 83.3 °C, and front-left wear 99.39 → 92.12% over the stint
   against 94.67–95.04% on the other three; anti-clockwise Interlagos runs the right side hotter
   (FR 65.0 vs FL 58.8 °C).
3. **Roll**: `RideHeights` value1 minus value2 against lateral acceleration puts value1 on the
   inside of left turns (corr +0.95 to +0.99).

The setup could not have settled it, as the older text below anticipated: all 15 per-corner
groups are left/right identical in every sample, and each `CarSetup` also carries a top-level
`"symmetric": true`, which suggests the game enforces it. The paragraphs below are kept for
the reasoning; their conclusion is superseded.

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
  - `Regen Rate` is in **watts**, positive while harvesting and negative while deploying
    (2026-10-13, closing §15.15). Its change tracks `SoC` at r = 0.97. It averages
    +138 kW under braking and −24 kW at full throttle. The harvest peak is
    0.97 × `VM_REGEN_LEVEL` on ten Hypercars (164.9 kW at 170, 193.6 at 200). The deploy
    peak is the class limit, not `VM_ELECTRIC_MOTOR_MAP`: −52 kW on LMDh, −196 kW on LMH.
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
- **`G Force Lat` and `G Force Long` are swapped in the export (v0.11).** `G Force Long` is the
  *lateral* acceleration, positive to the left: it correlates with `Steering Pos` at −0.81 to
  −0.85 and tracks the GPS path's lateral acceleration with slope 1.005, while `G Force Lat`
  correlates with steering at 0.03–0.12. `G Force Lat` is the *longitudinal* one, positive when
  slowing: correlation with `Brake Pos` +0.67 to +0.88, slope against the speed derivative
  −1.00. Measured on all three samples, consistent with rF2's local axes exported under each
  other's names. §8.13's G-G diagram is the first thing this would have broken — a friction
  circle plotted from the names is a plot of braking against lateral load's noise. `Steering
  Pos` is positive to the right.
- **Four per-corner channels carry the wrong unit or meaning in the catalog (v0.11).**
  `TyresTempLeft`/`Right` are the tyre's *car-frame* edges, not inside/outside: the inner edge
  runs 4–13 °C hotter on every wheel, as negative camber predicts, which makes it `Right` on the
  left-hand wheels and `Left` on the right-hand ones. `Brake Thickness` declares `%` and is disc
  thickness in centimetres, equal to the setup's `WM_BRAKEDISC` (3.56 front / 3.20 rear on the
  GT3s) and constant to 10⁻⁴ cm over a session. `Brakes Force` declares `%` and is a 0–0.56
  fraction — pedal × brake-pressure setting × the axle's share, whose front share at full
  pedal reproduces the setup's brake balance (0.505 against 50.5:49.5). `Tyres Wear` is percent
  *remaining*, 100 new. And `Wheel Speed` never shows longitudinal slip (rear/front at full
  throttle 1.00003), so it is contact-patch ground speed rather than ω·r and cannot drive a
  lock-up or wheelspin view.
- **Mid-session-adjustable values are modeled as events** (`TC`/`ABS` on-off, `TCLevel`,
  `ABSLevel`, `Brake Bias Rear`, `Brake Migration`) specifically because they *can* change
  during a session (e.g. a brake-bias migration dial), even though none of them changed in
  these three particular samples. Across the user's library they do change: `TCLevel`
  moves mid-session in 5 GT3 and 24 Hypercar files (§8.13.1).
- **Several driver-input channels are not pure inputs** (measured for §8.13, 2026-10-13, on
  the user's 678 recordings; numbers and checks in §8.13.1):
  - `Throttle Pos` is the throttle reaching the engine: it carries traction-control cuts, a
    40 ms cut on every upshift and the game's auto-blip on downshifts. `Throttle Pos
    Unfiltered` is the pedal.
  - `Brake Pos` equals its Unfiltered twin on racing laps. ABS shows only in `Brakes Force`.
  - `Steering Pos` is a fraction (−1…+1) in every recording before April 2026 and a
    percentage after. The newest recordings are the reference, and older files are
    converted to match. It also scales with a non-default steering lock, where
    `Steering Pos Unfiltered` does not.
  - `OverheatingState` never turns on in 708 recordings.
  - `Gear` passes through 0 on every shift, for exactly the game's shift time.
  - `Engine Max RPM` is 1.25 × the rev limiter on GT3, not the limit.
  - `G Force Vert` excludes gravity but includes banking.
  - `TC` and `ABS` switch in 10–20 ms pulses.
  - `Yellow Flag State` never changes.

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

**Built in v0.11.** Two lists: *Open now* — this run's sessions, the current one lit, each
closable (closing now releases the DuckDB connection; dropping a session from the list
alone had left the file open until quit) — and *Library*, the persistent index (§9.6),
newest recording first. Search is word-wise and accent-folded across track, layout, car
(the file's entry and the catalog's model, §15 item 6, so "porsche" finds the Iron Dames'
911 GT3 R), class and driver; filter chips (session type, class, car by model, track +
layout) exist only for values present and carry counts. Rows name the car by its model,
then the entry ("Porsche 911 GT3 R · Iron Dames #85"). The personal-best badge is keyed on **(`TrackName`,
`TrackLayout`, `CarClass`)** and computed over the whole library whatever the filters:
layout for the reason above, and class because it is the same mistake one dimension over —
a Hypercar lap would take the badge from every GT3 session at the circuit. (None of the
samples shares a layout across classes, so that half of the key is structural, not
measured.) A row reopens after a stat check, and a missing, changed or uploaded file says
so in words; *Remove from library* forgets the row, with Undo, and never touches the file.
*Add folder* (the LMU default suggested on Windows) and *Refresh* index a folder
sequentially, opening each file read-only just long enough for metadata, laps and the
clock scan — never through the kept-alive session provider, which would hold every
connection open — and skip files whose size and modification time match. Measured on the
samples: **~30 ms a file whatever its size** (29, 32, 31 ms for 8.8, 13.6, 25.4 MB), 257 ms
for all three cold, 3 ms for a rescan that finds nothing new. There is no watcher,
deliberately: it would index a recording LMU is still writing. Also fixed: a card in the
Phase 1 list navigated to the Overview without making its session current, so with two
open, choosing the second showed the first.

**Corrected after v0.11: closing did not release the file.** It invalidated the session's
provider while the *Open now* card and the shell's session switcher were still on screen
watching it, and Riverpod rebuilds an invalidated provider that has listeners — so each
close disposed the connection and reopened the file in the same frame, and the new
connection, kept alive with nothing left to close it, held the file until quit. Logged on
the first Windows run of the integration suite: three opens and two disposes across two
closes, and a closed recording Windows refused to delete. macOS unlinks an open file, which
is how it passed there, and the test checked only that the *old* handle had closed. A
closed session's provider now holds `SessionClosedException` — a state rather than an
invalidation, so no watcher can turn it back into an open file — and only an explicit open
resets it. The integration test asserts that state, which every platform can see.

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

**Trend and annotations built in v0.11.** The chart plots each lap's **delta to the fastest
lap**, not its time: the Race's 16 timed laps span 63.941–64.701 s, so bars of absolute
time from zero would all stand within 1.2% of one height, and bars from a raised floor would
lie about ratios. A delta starts at zero honestly and *is* this section's "delta to personal
best". The fastest lap is a 4 px cap in the tertiary — the lap table's "fastest" colour —
the median is a dashed line (+0.267 s), and consistency is stated (±0.235 s). An untimed lap
keeps its slot as a hollow circle with its reason in the tooltip: a zero-height bar would say
"as fast as the fastest". A bar or row selects that lap for the trace and the map.
Incidents are read session-wide once and cut into laps in Dart, then shown as badges in the
table and glyphs under the chart, both built from one list so they cannot disagree.
**`LastImpactMagnitude` is a boolean with no magnitude, and a *row* is the impact**: the Race
sample reads `false`, then `true` at 213.8 s, `false` at 508.1 s — two contacts, confirmed
by `Ground Speed` stepping +3.51 and +7.91 km/h inside 0.06 s at exactly those times
(nothing else in the 22 minutes steps more than +2.05). Counting the `true` *state* would
blame laps 3–5 for a lap-2 impact. The count is a lower bound and cannot tell a kerb from a
wall. `Yellow Flag State` and `WheelsDetached` are one all-zero row in every sample, so
their paths are verified on constructed series only; sector flag codes stay undecoded
(§15.4).

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

**Built (Phase 1)** for a single lap: six stacked panels — `Ground Speed`, `Throttle Pos`,
`Brake Pos`, `Steering Pos`, `Engine RPM` and `Gear` — sharing one axis, one viewport and
one scrub cursor with each other and with the track map beside them. **Reference-lap
overlay and the delta trace built in v0.10** (§14): a chosen reference lap is drawn dotted
over every panel, and a delta panel heads the stack.

**The delta is time-at-distance, measured from each lap's own line crossing.** At each of
the lap's `Lap Dist` samples it is the lap's elapsed time minus the reference's elapsed time
at the same distance — comparing at equal *times* would line a corner entry up with a
straight the moment either lap gains a tenth. Both laps are timed from their `Lap` event
rather than from their first `Lap Dist` sample, which lands 0–4.4 m after the line. The file
confirms it at one point: the trace must end at the difference between the laps' own `Lap
Time`s. Measured on all 16 pairs of the samples' timed flying laps against each session's
best, it ends within **0.0154 s** of it and starts within 0.02 s of zero; anchoring on the
first shared distance sample instead measured 0.020 s. Only the stretch both laps recorded
is compared, and a lap whose distance runs backwards anywhere (the garage lap) has no delta
at all, because a distance that occurs twice has no single time.

**One channel per panel, never overlaid.** Two signals with unrelated units sharing a pair
of axes produce crossings that are artefacts of the scaling rather than facts about the
car, and that is the single most common way a telemetry chart misleads. Stacked panels
against a shared x-axis say the same thing without inventing any of it — and it is also
what makes §9.7.1's channel colours safe (see §9.7.1's note on the palette check).

**`Gear` is an event, not a channel** (§5.1), so it is drawn as held steps: interpolating
between two gear values would render a shift as a ramp through gears the car was never in.
Its window read always includes the last change *before* the window, because an event that
never changed inside one still has a value throughout it — in the checked-in fixture `Gear`
has 36–44 rows in each of laps 0–3 and **zero** in lap 4.

Multi-channel time/distance-based charts — `Ground Speed`, `Engine RPM`, `Throttle/Brake
Pos`, `Steering Pos`, `Gear`, `G Force Lat/Long/Vert`, etc. — for a single lap or overlaid
across multiple laps, with a synced scrub cursor across all channels and the track map
(§8.5). Channels at different native frequencies are aligned via the synthetic-time/ASOF
approach in §5.2 before charting, not assumed to share a clock.

### 8.5 Track Map
2D circuit map built from `GPS Latitude`/`GPS Longitude` (or `Lap Dist`/`Total Dist` +
`Path Lateral` for a distance-based lane view), colored by a selected channel (speed,
throttle, brake), with a synced cursor following the trace view.

#### 8.5.1 The GPS channels are a local frame, not a geographic one (v0.8)

Two things about these channels, both measured while building the map, and the second is
the kind of error that produces a plausible-looking wrong picture rather than a crash.

1. **They are not where the circuit is.** The Sebring Race sample sits at latitude
   59.99996°, longitude ≈0 — the North Sea — while Sebring is at 27.45°N, 81.35°W. LMU
   emits a local frame dressed in lat/lon units, and the latitude is *exactly* 60°, which
   reads as a chosen origin rather than a coincidence. Consequence: these channels support
   a **shape**, and never a basemap, a real-world coordinate readout, or a distance to
   anywhere. Nothing in the app should label them as geographic.
2. **A degree of longitude is a degree of latitude times cos(latitude), and at this origin
   that factor is almost exactly ½.** A projection that treats the two axes alike stretches
   the circuit east-west by 2×, which makes every corner the wrong shape. The file carries
   its own ground truth to settle it — summing the projected polyline over Race lap 1
   against the `Lap Dist` the game reports for the same lap:

   | projection | polyline length | vs. `Lap Dist` 3080.7 m |
   |---|---|---|
   | without cos(latitude) | 5193.6 m | **+69%** |
   | with cos(latitude) | 3043.3 m | −1.1% |

   The residual 1.1% is **not** the projection and not polyline chording: re-summing the
   same lap at every second sample changes the total by 1.1 m (0.04%), so the 10 Hz
   segments are already straight enough that halving them buys nothing. It is the driven
   line differing from the track path `Lap Dist` is measured along — `Path Lateral` spans
   ±11 m on that lap, which is exactly the room a driver has to shorten a corner. Worth
   knowing before anyone "fixes" the remaining percent.

   Only the *aspect ratio* is load-bearing for drawing a map, and that is what the cosine
   fixes; the metre scale comes along for one constant and is what makes the check above
   expressible in the unit the file already reports. The same check runs on every fixture
   in `integration_test/data_layer_test.dart`, for the same reason the lap-boundary check
   guards the time axis (§5.2): a derivation confirmed once is a derivation that regresses
   silently. `Path Lateral` and
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

**Built in v0.11**, on §5.3's corner order. It answers two questions in the order a driver
asks them. *How were the tyres on that lap?* Four corner cards in the car's own layout,
nose up, for one lap (default: the last complete one): hot pressure beside the setup's cold
value (Sebring FL 177.3 kPa, cold 136, +41.3), the tread as inner / centre / outer on a
single-hue ramp spanning the whole session, carcass with rim, tread left with what the lap
took, and brake peak with mean. *Inner* and *outer* are decided once, by the `Corner`
model, never by a screen: `TyresTempLeft`/`Right` are car-frame (§5.4), so a left wheel's
strip reads outer → inner and a right wheel's the reverse — which is also how the tyres sit
seen from above. *How did they get there?* One metric at a time drives four small multiples
on **one shared scale**, so corners compare honestly. Pressure and temperatures are not
anchored at zero, so they are never bars: `PerLapTrendChart` draws the lap mean as a dot on
a line with the lap's range as a band. Wear per lap uses the fuel view's differencing and
its bar chart. Measured on the samples: Sebring wear is 0.23–0.51% a lap on every corner,
the clockwise circuit loading the left side (carcass FL 93.4 vs FR 83.3 °C by lap 19, FL
also the most worn); the inner edge is hotter than the outer on every corner of every
racing lap of all three files (+3.8 to +14.6 °C), as negative camber predicts; a race starts
on pre-heated tyres (171.7 kPa on the first sample against 136 cold) while the Spa
qualifying run starts at ambient; and the Spa lap-3 spin takes 9.6 points of rear-right
tread in one lap against 1.3–3.8 elsewhere. Each per-corner channel is read in one scan of
four columns (`lapStatsSql` over several columns — identical to four single reads lap for
lap, 3.4–4.6× faster). Not built: a rubber-temperature view (rim trails carcass by 1.3–9.5
°C on every lap, so it is a caption). `TyresCompound` was first shown only as "changed or
not", since its value is `0` on every corner of every sample. It is an index into the
session's compound list (§15.20), and since 2026-10-14 the setup card lists each change by
the lap it came in, named through the game's order where the file allows ("Lap 4: Wet").

### 8.7 Fuel & Energy Strategy
Branches by class (§5.4) on **`metadata.CarClass`, not on which tables exist** — all files
carry all energy tables. `SoC`/`Regen Rate` are all-zero in GT3 files and should be hidden
there; `Fuel Level` and `Virtual Energy` are both live for GT3 *and* Hypercar. Per-lap
consumption, estimated laps/time remaining in a stint, pit stop markers (`In Pits` — note
it is single-row in the Race sample, so "no pit stop recorded" is a normal case to render,
not an error) with in/out-lap deltas.

**Built in v0.10**, minus the in/out-lap deltas (§14). What a lap "uses" is the level at its
first sample minus the level at the next lap's first sample — both 20 Hz readings the game
wrote, within 0.05 s of the line. The per-lap average counts every *racing* lap: not the
garage lap, no time in the pit lane, closed by the recording, level going down. An
**invalidated** lap counts — a track-limits penalty voids the time, not the fuel burnt
driving it, and the Race sample invalidates two of nineteen. On that sample the car uses
**1.79 L and 2.14% of virtual energy a lap**, ends with 6.13 L and 5.59%, and so runs out of
*energy* first — 2.6 laps against 3.4 — which the view leads with: on this car and track
the energy allocation, not the tank, is what ends a stint. `Fuel Level` and `Virtual
Energy` are both 20 Hz, in L and %; `In Pits` gives the pit-lane visits, and both the
Practice and Qualify samples *start* in the pit lane (in at the first sample, out 21 s and
51 s later), which is simply what leaving the garage looks like.

**The fuel ratio is in the setup (measured 2026-10-13).** `VM_FUEL_LEVEL`'s `stringValue`
is the litres of fuel loaded per 1 % of virtual energy. It equals `VM_FUEL_CAPACITY` ÷
`VM_VIRTUAL_ENERGY` in all 672 setups that carry it (574 Hypercar, 98 GT3). The ratio a
car actually burns has to be measured: the litres used per % of VE used. That burn ratio
does not depend on the driver: 0.906–0.924 for one driver and 0.895–0.937 for another in
the same Alpine at Le Mans. It does depend on the session's energy allocation: the Ferrari
499P at Daytona burns about 3 L a lap in every session, but its burn ratio was 0.84–0.87
where 100 % lasted 28.6 laps and 0.60 where it lasted 20. So which of fuel and energy ends
a stint, and how much surplus fuel the car carries, follows from the setting against the
burn ratio, and the view can state both. `docs/PACE-FACTORS.md` keeps the per-car figures
and how fuel, energy, tyres, temperatures and tape relate to pace.

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

**Built in v0.11.** What the channel means had to be measured first, because its name
does not say which way round it is. **`Time Behind Next` is a signed timing-line offset to
the car one place ahead, negative when that car is ahead**: across the Race sample's 18
closed racing laps the lap-to-lap change in gap regresses on lap duration at −1.44 s/s
(r = −0.68), which fixes both the sign and whose gap it is. It moves in timing steps (median
0.014 s, p99 0.113 s), is *held* rather than zeroed when nothing is timed (the first 42.5 s
on the grid read −0.1879 throughout, the last 10.5 s after the flag −6.9584), and a step of
0.4 s or more is a **change of car ahead**: the Race has exactly three, each after the gap
closed to within 0.11 s, between an ordinary maximum of 0.293 s and a smallest change of
0.572 s. A lap's gained/lost is the gap's movement less those steps, so the three passes of
lap 1 read +0.97 s gained rather than −2.33 s lost, and the sample's net is −3.47 s over 19
laps. The view is five figures, a session chart (1,000 min/max buckets for drawing, the
full-resolution series for the changes so no 0.5 s step hides inside a bucket), a signed
per-lap bar chart, the list of changes and a table. **Race-only, measured rather than
assumed**: Qualify and Practice flip sign 41 and 72 times with steps up to 24 s and 81 s —
consistent with the game ranking by best lap outside a race, which is worded as the
inference it is. Not established: what the channel reads in the pit lane, or for a leader.

### 8.10 Setup Viewer
Read-only view of the embedded `CarSetup` JSON (§5.1) — brake bias/migration, ARBs,
camber/toe, springs/dampers per corner, gearing (incl. the `gearGraph` per-gear top
speed/shift RPM), tire compound, wing angles. Not in the original spec draft; added
because the data turned out to already be fully present, at no extra parsing cost beyond
`json_extract`.

**Built in v0.11**, parsed in Dart from the metadata already read (no SQL of its own). All
three samples carry the same 172 keys — 110 vehicle-level `VM_*`, 60 per-wheel
`WM_<NAME>-W_<CORNER>`, `gearGraph` and `symmetric` — grouped into nine sections a setup
engineer expects, unknown keys kept under *Other* rather than dropped. Four things about the
fields had to be measured, and two of them contradict their names:

- **`value` is a step index**, not a quantity (`minValue` is 0 in all 510 settings);
  `stringValue` is the game's rendering of that step and is what the view shows.
- **`lastSavedStringValue` is not the saved setup.** It is the rendering of the *lowest*
  step (`-5.00 deg`, `0 (Off)`, `57.0:43.0`), equal to `stringValue` exactly where `value`
  is 0. Sebring's brake balance reads 51.2:48.8 against a "last saved" 57.0:43.0, and
  51.2:48.8 is what the `Brake Bias Rear` event recorded (0.4875). So no "changed since
  saved" marker exists: one built on this field would flag nearly every setting.
- **`available` means the car has no such slot** (gears past `numForwardGears`), and
  under-reports "N/A": 58/38/54 settings read N/A, most of them available.
- **`isFreeSetting` is "adjustable in this session"**: 170 of 170 in Practice and Qualify,
  27 in the fixed-setup Race.

`gearGraph` renders as a shift diagram and a table (peak and post-shift rpm, nominal top
speed per gear); its figures check out against each other (8.5k × 119.6/154.7 ≈ 6.57k, the
recorded 6.568k). Per-wheel settings sit FL FR / RL RR — safe independently of §5.3, since
here the corner is in the key's name.

#### 8.10.1 Cooling and brake-duct tape (planned; measured 2026-10-13, not built)
The user's idea, to keep for the setup feature: how each track's and car's air temperature
should set how much tape goes on the water radiator, the oil radiator and the brake ducts.
Brake temperature may feed into tyre temperature too.

**What the file holds.**
- Setup keys, read from `stringValue`:
  - `VM_WATER_RADIATOR`, `VM_OIL_RADIATOR`, `VM_BRAKE_DUCTS` and `VM_BRAKE_DUCTS_REAR`;
  - "Open"/"No tape" is 0 and "Closed" is 100. Some GT3 ducts are sized in mm and are not
    pooled with percentages.
- Channels:
  - `Ambient Temperature` (1 Hz);
  - `Engine Water Temp` and `Engine Oil Temp` (7 Hz);
  - `Brakes Temp` (50 Hz, per corner);
  - `TyresRimTemp`, `TyresCarcassTemp` and `TyresRubberTemp`;
  - `OverheatingState` (2 Hz).
- In the library: Hypercars run every tape step from 0 to 100 %. LMP2 runs 0–50 %. Every
  timed GT3 session ran untaped, so GT3 has nothing to estimate from yet.

**What tape and air temperature do.** Hypercar, 172 sessions with ≥ 3 timed laps, compared
within the same car at the same track (26 groups). Standard errors in brackets.

| Temperature | Per °C of air | Per 25 % tape |
|---|---|---|
| Water, p95 | +1.05 (0.06) | +2.6 (0.36) radiator tape |
| Oil, p95 | +1.18 (0.13) | +0.9 (0.9) oil-radiator tape: not detectable |
| Front brakes, median / p95 | +2.8 / +1.3 | +29 (10) / +38 (9) front duct tape |
| Rear brakes, median / p95 | +4.0 / +3.0 | +28 (7) / +30 (6) rear duct tape |
| Front tyres: rim / carcass / rubber | +1.2 / +1.0 / +0.8 | +1.5 (2.4) / +0.1 (2.5) / −0.1 (1.8) |
| Rear tyres: rim / carcass / rubber | +1.3 / +1.1 / +1.0 | +3.7 (2.0) / +2.4 (1.9) / +1.7 (1.5) |

LMP2 water agrees in direction: +4.4 (0.6) °C per 25 % and +1.25 (0.24) per °C of air, but
on only 9 sessions.

**Re-fitted 2026-10-13 with both tapes in one model** (183 Hypercar sessions, 34
car × track groups). Water: +1.04 (0.06) per °C of air, +2.9 (0.6) per 25 % radiator tape,
−0.2 (0.7) per 25 % oil tape. Oil: +1.14 (0.13) per °C, −0.9 (1.6) per 25 % oil tape, and
+2.3 (1.5) per 25 % *water* tape. So oil may follow the water radiator's tape rather than
its own. On the Alpine at Le Mans, going from 50 % to 75 % water tape with oil tape fixed
at 25 % moved oil +4 °C (108 → 112). That is suggestive, not established: the two tapes
move together (r = 0.83), and no session tapes oil alone. Details in `docs/PACE-FACTORS.md`
§7.

So water temperature responds cleanly to radiator tape and to air temperature, and brake
temperature to duct tape. The brake-to-tyre link the user expects is not established here:
no tyre figure clears two standard errors. The rear rim, next to the brake, comes closest.

**What is missing: the target.** `OverheatingState` was false in every one of the 708
recordings, and the hottest water reading was 102.7 °C. The data says how temperatures
*move*, not where the limit is. Water and oil limits, and brake and tyre windows, have to
come from a per-class reference table or from the user, labelled as such (§15.21).

**The planned tool.**
- Per car, from the user's own sessions, it fits water and brake temperature against air
  temperature and tape, as above.
- Given an expected air temperature, it shows the predicted temperature for each tape step
  against the target. The expected air temperature is the measured `Ambient Temperature`
  the library holds for that track, never the `WeatherConditions` label (Compare §4), or a
  value the user types.
- It marks the most tape that keeps the prediction under the target, by a margin equal to
  the fit's own scatter (water: 2.8 °C).
- A car whose sessions never varied the tape gets "not enough variety in your sessions to
  estimate", not a guess.
- Tyre temperatures are shown alongside as observed, with no claimed cause.

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
**Specified 2026-10-13 from measurements, and built the same day** (§14, Phase 3, has
what came out of building it; §8.13.9 describes the code as built). One screen of per-lap, per-segment
and per-corner measures of how a lap was driven: the pedals, the shifts, the friction
circle, the driver aids and the slides the driver caught. A conditions lens adds how
wetness, compound and electronics changes moved each segment. Everything is derived from
raw channels, not read from any one table. Inspired by MyLMU's Driver tab (§7.2). Every number below was
measured on recordings in the user's own LMU Telemetry folder: 678 readable files from
February to October 2026, covering GT3, Hypercar, LMP2_ELMS and LMP3 on 16 tracks. Where
the file has a second, independent channel, each definition was checked against it before
it was kept. Where it has none, the section says so.

Three things the stub this replaces assumed were wrong:
- the channel named `Throttle Pos` is not the pedal;
- `Engine Max RPM` is not the rev limit;
- a raw "peak combined G" measures kerbs and impacts, not grip.

Like Compare (§8.8), this screen reports and never advises. It says "68 % of braking time
with the wheel turned", never "trail-brake more". Unlike Compare, its measures are per-lap
shares and counts read against the same session's other laps, so they do not need
Compare's pair-level sign-stability floors. What they need instead is a measured
relationship with lap time before any is presented as going with pace, and most have none
(§8.13.4).

#### 8.13.1 What the input channels actually carry
Each family was measured on 12–22 files, then on the whole folder where a scan was cheap.
§5.4 carries the summary.

- **`Throttle Pos` is the throttle reaching the engine; `Throttle Pos Unfiltered` is the
  pedal.**
  - On racing rows the filtered value sits more than 0.5 below the pedal on 4.5–13.4 % of
    samples. Of those, 64–93 % fall inside a `TC` intervention and 6–21 % within 0.3 s of
    an upshift. The upshift cut is 40 ms to 0 (p90 60 ms), on 155 of Sebring Race's 156
    upshifts, while the pedal stays down. On Hypercars, 8–21 % have neither cause within
    those windows (§15.17).
  - Widening the windows explains most of that remainder. On six Hypercar sessions the
    cuts break down as:
    - TC active at the sample: 59–81 %;
    - TC within ±0.5 s: 5–14 %;
    - a `Gear` row within ±0.5 s: 6–17 %;
    - pedal below 20 %, where the engine gets less than the pedal (a low-end throttle map,
      inferred): 1–13 %;
    - unexplained: 0.3–4.9 %, all small trims of 1–4 points.

    No recording gap (a `GPS Time` step over 15 ms) falls within 1 s of any cut. A pedal
    signal frozen for 1 s appears only at 100 %, where flat out is expected. So nothing
    looks like a connection loss or a disconnected pedal.

    The largest "unexplained" episode was the pit lane. At the start of Imola's Hypercar
    race, the car sat at 59–60 km/h for 13 s with the pedal at 99 % and the engine at 21 %.
    `In Pits` and `Speed Limiter` had switched on before that lap began, so a filter that
    looked only at rows inside the lap missed them (§8.13.2).
  - It sits *above* the pedal on 0.1–1.3 % of samples. 86–98 % of those are inside a
    downshift with the pedal at 0 and the brake on: the game's **auto-blip**, on 42–54 %
    of downshifts.
  - So every pedal measure here reads `Throttle Pos Unfiltered`. Overlap on the filtered
    channel counts the blips (Sebring Race 1.55 % against 0.80 %). Coasting on it counts
    the upshift cuts (+8.6 % to +117 %, with Interlagos Practice the extreme). Compare's
    Throttle panel draws the pedal for the same reason (comparison proposal, D3).
- **`Brake Pos` equals `Brake Pos Unfiltered` on every racing row of all 12 files.** They
  differ only when the car is stationary, where the filtered one reads 100 (the game
  holding the car). ABS does not show in either; it shows in `Brakes Force` (§8.13.3).
- **Thresholds.**
  - A pedal counts as applied above 2 %. Values in (0, 2] are transits, median one 20 ms
    sample.
  - Full throttle is the pedal at ≥ 98 %, not = 100, because late in long races the pedal
    stops reaching 100.0. On Imola's 127-lap GT3 race, the share of flat-out time spent at
    99–<100 grows from 2 % (lap 64) to 50–60 % (laps 102–120). COTA's Hypercar race is at
    exactly 100 for 31.5 % of racing time but at ≥ 99 for 45.7 % (§15.19). Thresholds of
    98 and 99 differ by under one point everywhere.
- **`Steering Pos` changed unit in April 2026; the newest recordings are the reference.**
  - All 154 scanned recordings from February and March store it as a fraction, −1 to +1.
    Every later one stores a percentage, −100 to +100. Pedals are 0–100 throughout.
  - The rule for any channel whose representation changed between game updates: **the
    newest recordings define it, and older files are converted to match**. A later update
    is more likely to have fixed a channel than broken it. `metadata.Version` stays "1"
    across this change, so the conversion is triggered by the data's own range, never by
    a version number.
  - It is the same signal scaled by 1/100: its correlation with lateral G is the same
    (median −0.61 against −0.65).
  - No timed lap is ambiguous. Every file with a timed lap has a session maximum
    |Steering Pos| either ≤ 1.0 (all 64 timed February–March files) or ≥ 30 (all 234 timed
    later ones). So the read multiplies a file by 100 when its maximum is ≤ 1.0. The 12
    later files with a maximum under 30 have no timed lap, so no measure is ever computed
    on a misread file.
  - `Steering Pos Unfiltered` equals `Steering Pos` exactly in 603 of the 613 scanned files
    with steering rows. In the other ten, `Steering Pos` is a constant multiple of it, and
    the multiple follows the setup's steering lock, not the date:
    - Every LMP2 file at the usual 336° (13° at the front wheels) is identical. All six at
      240° (9.3°) scale by 0.714976. That sits between 240/336 = 0.7143 and 9.3/13 = 0.7154,
      as the rounded labels allow.
    - The four Porsche GT3 files, all at 540° (18.8°), scale by 0.924372. That puts the
      car's reference at 20.34° of front-wheel lock.
    - Recent files show it too (the LMP2 ones are from 25 September), so it is a setup
      effect, not a version change.

    The reading that fits: `Steering Pos Unfiltered` is the driver's wheel as a percentage
    of its set rotation, and `Steering Pos` is the front-wheel angle as a percentage of a
    fixed reference per car (inferred; §15.16). §8.13 reads **`Steering Pos`**: it measures
    the front wheels, so a lock change in the setup does not rescale it.
  - Positive is right. Because the scale differs per car (240–584° of wheel lock across the
    library), steering-based shares are compared within a car only.
  - On straights, |steer| has p99 1.2–3.5 %, so "turned" means ≥ 5 %.
- **The G channels are swapped (§5.4), aligned, and unusable as raw peaks.**
  - The swap holds on all four classes (22 files). `G Force Long` follows the projected
    GPS path's lateral acceleration at r 0.990–0.998, slope 0.99–1.04. `G Force Lat` follows
    the Ground Speed derivative at r −0.94 to −0.994.
  - G sample i sits on master row 10i: the correlation with the speed derivative peaks at
    zero offset in every file.
  - `G Force Vert` reads 0 at rest (sd 0.0006), so gravity is removed. It does carry
    banking: +0.96 G on Daytona's banking against +0.01–0.03 elsewhere on the lap.
  - The raw maximum of combined G runs 5.2–21.4 G per session (21.4 is COTA's Hypercar
    race), with a per-lap coefficient of variation up to 68 %. Kerbs and impacts put
    single-sample spikes in it, so it is unusable.
- **`Gear` passes through 0 on every shift.**
  - Every change in all 678 files goes old → 0 → new. There is no direct gear-to-gear row
    and no consecutive duplicate. A shift is therefore a change between consecutive
    *non-zero* values; counting raw value changes doubles the count.
  - On upshifts the 0 row lasts exactly the game's shift time: 42.5 ms on GT3 (913 of
    913), 37.5 ms on Hypercar (3909 of 3910) and LMP2 (1583 of 1586).
  - Auto-shift (`VM_GEAR_AUTOUPSHIFT`/`AUTODOWNSHIFT`) is Off in every file.
  - `Engine RPM` starts falling within 0–20 ms of the new-gear row on every GT3 and
    Hypercar upshift measured (913 and 3909), and at exactly +10 ms on 1514 of 1586 LMP2
    ones. That is an independent check of §5.2's channel-against-event alignment, between
    two tables that share nothing but the clock.
- **`Engine Max RPM` is not the rev limit.**
  - It is one row per file, at exactly 1.25 × the setup's `VM_REV_LIMITER` on all 98 GT3
    files (9375 against 7500). The ratio is 1.267–1.269 on Hypercars, 1.311 on LMP2 and
    1.263 on LMP3.
  - The limit is `VM_REV_LIMITER`. `CarSetup.gearGraph`'s per-gear peak equals it to
    0.4 rpm on GT3, Hypercar and LMP3, so gearGraph's "peak" is the limiter, not a power
    peak. LMP2's gearGraph peaks vary per gear (8685–8805) and sit 185 rpm above its
    `VM_REV_LIMITER`.
  - Session-maximum `Engine RPM` sits at the limiter (GT3 +0 to +90 rpm).
  - The file has no torque or power curve, so the stub's "power band" cannot be computed.
    §8.13.3 substitutes what can be.
- **`TC` and `ABS` are pulse trains.**
  - They switch in 10–20 ms pulses with 2.5–10 ms gaps: 101–259 ABS edges and 117–908 TC
    edges per lap. They are merged (gaps ≤ 0.25 s) before anything is counted.
  - ABS exists on GT3 only, active in 94 of 98 GT3 files. Hypercars carry a single row and
    LMP2/LMP3 none, matching the setup's `VM_ANTILOCK_BRAKES` of "N/A". TC is active in
    every class.
  - On all 12 files checked, the `TCLevel`/`TCCut`/`TCSlipAngle`/`ABSLevel` events carry
    the setup's `VM_TRACTIONCONTROLMAP`/`POWERCUTMAP`/`SLIPANGLEMAP`/
    `ANTILOCKBRAKESYSTEMMAP`. They change mid-session in 5 GT3 and 24 Hypercar files, so
    the level in force is read per lap as an event, never from the setup.
  - **In a newer game build `TC` is a 100 Hz channel, not an event** (§5.1, 2026-10-13).
    It still pulses: the median run of `true` samples is one sample (10 ms) and the p90 is
    four, 3,509 runs over a 45-minute race, so the 0.25 s merge still applies. Its active
    time agrees in size with the event-built figure (6.7–8.9 s a lap on that Alpine
    against 4.5–7.1 s for the user's Alpine races). The screen first read `TC` only as an
    event, so on such a file it showed no TC time and no TC episodes, silently, as if the
    car had none. **It now reads either kind** (2026-10-13):
    - The pedal frame takes the channel's row at master row 2i, the tick the event is read
      at.
    - Episodes take their edges from the rows where the value changes, found in row order
      and timestamped only then (7,019 edges of 265,740 rows), then merge as the event's
      do.
    - On the fixture re-recorded with `TC` as a channel
      (`test/fixtures/sebring_race_tc_channel_laps0_3.duckdb`), TC time and episodes
      equal the event's on every lap.
    - On that Le Mans race's nine racing laps TC reads 6.6–9.0 s and 17–21 episodes a
      lap.
    - `ABS` is still an event in that build and is still read as one.
- **What is not in the file.**
  - No yaw rate, so a slide is visible only when the driver corrects it (§8.13.3).
  - No torque curve.
  - `Wheel Speed` shows no slip (§5.4), so lock-ups and wheelspin are visible only through
    ABS and TC.
  - `Yellow Flag State` is a single 0 row in all 675 files that carry it, so caution laps
    cannot be excluded.

#### 8.13.2 Which laps, and how they are read
Measures are computed on **racing laps**: lap > 0, a positive `Lap Time` (§8.3.1), closed,
and never in the pit lane or on the speed limiter at any moment of the lap. That includes a
state switched on before the lap began and still on, which is Compare's `pitLaneDuring`
rule, reused.

A first version of these queries checked only for rows *inside* the lap, and that missed
real pit laps. Imola's Hypercar race switched `In Pits` and `Speed Limiter` on 60 s before
lap 1 started and off 13.5 s into it, and that pit-exit lap counted as racing. With the
fix, braking's correlation with lap time went from positive in 11 of 12 races to 12 of 12,
and the countersteer cost below was re-measured.

Each measure family is one SQL query, aggregated inside DuckDB to one row per lap by
`lapStatsSql`'s aggregate-before-timestamping rule (§9.5):
- The pedal frame is the three 50 Hz pedal channels joined positionally, since they are
  row-aligned.
- `Steering Pos` joins at row 2i and the G channels at row i/5.
- Each pedal row is timestamped once, through master row 2i, and events are joined `ASOF
  LEFT` on that time. `TC`, where a newer build records it as a channel, joins at row 2i
  (§8.13.1).

Two checks come free:
- A lap's 50 Hz sample count equals 50 × its `Lap Time` to within 0.9 samples on every
  racing lap of Imola's 127-lap race (121 of them) and of Sebring's Race. The lap
  assignment cannot be off by even one sample.
- The checked-in fixture (`test/fixtures/sebring_race_laps0_3.duckdb`) reproduces the full
  recording's laps 1–3 exactly on every pedal, aid and shift measure below.

The pedal query costs 75 ms on Sebring's Race and 0.48–0.52 s on Imola's 300 MB, 127-lap
race. The G-G family took 78–919 ms per file.

The 5 Hz Dart lap fixtures (`sebring_lap1.dart`) cannot test any of this: overlap episodes
last a median 0.10 s, half a 5 Hz sample.

#### 8.13.3 The measures
Each measure is shown per lap against the session's other racing laps, and per segment
(§8.13.5). Ranges are per-session values over the measured files.

**Pedals** (50 Hz pedal frame)
- **Braking**: the share of lap time with the brake applied. Sebring Race runs 17.0–19.8 %
  per lap. Validation: with the throttle off above 100 km/h, the pedal correlates with
  longitudinal G at 0.92–0.99. `G Force Lat` against −dv/dt has slope 0.98–1.005 on all
  12 files.
- **Pedal overlap**: the share of lap time with both pedals applied. It is 0.64–4.87 % of
  racing time over 12 files (Sebring Race 0.40–1.39 % per lap). Episodes last a median
  0.10–0.16 s (p90 0.14–0.49 s). They are classified by what the pedals did before and
  after:
  - *entry*: on the throttle, with the brake coming on before it lifts, at 155–258 km/h and
    the wheel nearly straight. 26–89 % of overlap time.
  - *exit*: the brake still on as the throttle picks up, at 100–150 km/h. 5–39 %.
  - *dab*: the brake touched while on the throttle, which stays on. 4–44 %.

  The stub's "trail-braking overlap" is not trail braking, which is the brake with the
  wheel turned (next item). On these cars most overlap is the entry transition.
- **Trail braking**: the share of braking time with |steer| ≥ 5 %. It is 46–71 % across
  files (Sebring Race 67–75 % per lap), with a median brake pressure at turn-in of
  33–58 %. Validation: on 95–100 % of braking-and-turning samples the steering sign is
  opposite lateral G's. So "turned" means turning into the corner, not a correction.
- **Coasting**: the share of lap time with neither pedal touched at all (pedal exactly 0
  and brake 0), and its distance in `Lap Dist` metres. It is 0.66–9.76 % of racing time
  over 15 files.
  - Coast spans are classified by their neighbours. Throttle → coast → brake, the
    lift-and-coast shape, holds 40 % of coast time (median span 0.38 s, p90 1.6 s). Brake →
    coast → throttle, mid-corner, holds 34 % (median 0.24 s).
  - Races coast more than practice or qualifying at the same track and class in all 4
    pairs measured: COTA Hypercar 7.40 % against 6.05 %, Daytona Hypercar 9.76/7.09,
    Sebring GT3 5.11/3.66, Spa Hypercar 4.26/2.31. Daytona's Hypercar race holds 173
    lift-and-coast spans of median 1.16 s over 57 laps. That is consistent with fuel or
    energy saving, which the file does not label (inferred).
  - Validation: above 100 km/h, longitudinal G while coasting averages 0.17–0.34 G of
    deceleration (drag and rolling resistance). That compares with 0.79–1.40 G under
    braking and −0.24 to −0.40 G on the throttle (12 files).
  - Distance comes from `Lap Dist`, not integrated speed. Ground Speed integrates to 1.3 %
    less over a lap (Sebring 3040 against 3081 m): the driven line against the track path,
    the same difference §8.5.1 found in the GPS polyline.
- **Full throttle**: the share of lap time with the pedal at ≥ 98 %. Sebring Race runs
  61–66 % per lap.

**Shifts** (`Gear` rows, `Engine RPM`, setup)
- **Count**: upshifts and downshifts per lap. Stable, with per-session sd 0.41–1.04 over
  six races (Sebring GT3 9–10 upshifts, Spa Hypercar 27–30).
- **Upshift point against the limiter**: shift RPM is the maximum `Engine RPM` in the 0.3 s
  before the neutral row, read against L = `VM_REV_LIMITER` in four bands.

  This replaces the stub's "% time in the power band", which needs a torque curve the file
  does not have. Each band is graded by what the shift did to acceleration. da is Ground
  Speed's acceleration over the 0.25 s after the neutral row, minus the 0.25 s before, at
  full throttle on racing laps (14,440 shifts on 13 files). Mean da in km/h per s, with n:

  | Upshift at | GT3 | Hypercar | LMP2 |
  |---|---|---|---|
  | ≥ L − 20 | +0.10 (32) | +0.66 (96) | +2.58 (88) |
  | L − 200 … L − 20 | +0.03 (217) | −0.99 (695) | −1.37 (400) |
  | L − 500 … L − 200 | −0.11 (139) | −1.39 (1031) | −2.22 (419) |
  | L − 1000 … L − 500 | −1.07 (237) | −1.36 (874) | −2.52 (300) |

  A GT3 loses nothing measurable shifting up to 500 rpm early; a Hypercar or LMP2 loses
  from 200 rpm. Sessions differ by intent. Sebring's GT3 race shifts at L − 100 to L − 300
  with da ≈ 0. Daytona's GT3 race shifts at L − 500 to L − 800 on every shift, with da −0.4
  to −2.4: short-shifting, presumably to save fuel (inferred). The screen states the band
  and the measured da. It does not call an early shift a mistake.
- **Limiter dwell**: time on the limiter before an upshift. Median 0.045 s on GT3, 0.078 s on
  Hypercar, 0.24 s on LMP2.

`Clutch Pos` is non-zero in nearly every file (94/98 GT3, 544/552 Hypercar, 26/26 LMP2),
but only at starts and in the pit lane. On paddle-shift cars it is not a technique signal
(inferred), so it is not shown.

**Friction circle** (10 Hz G frame)
- **G-G diagram**: lateral G (`G Force Long`, + left) against longitudinal G (`G Force
  Lat`, + braking). The axes are labelled by what the channels are, never by the export's
  names.
  - One lap is 640–2,244 points, drawn as a scatter.
  - A session is up to 133,924 racing samples but at most 5,720 distinct 0.05 G cells,
    drawn as a density grid under the selected lap.
- **Sustained peak**: the lap's maximum of combined G's 0.3 s (three-sample) rolling
  minimum.
  - Per-lap coefficient of variation is 2.6–8.4 %, against up to 68 % for the raw maximum.
  - Medians: GT3 1.96–2.28 G, Hypercar 2.18–3.42, LMP2 2.91–3.15.
- **Envelope**: the session's p99 in each direction over racing samples.

  | Direction | GT3 | Hypercar | LMP2 |
  |---|---|---|---|
  | Braking | 1.79–2.12 G | 2.07–2.45 G | 2.39–2.60 G |
  | Traction | 0.61–0.73 G | 0.87–1.12 G | 0.81–0.91 G |
  | Lateral | 1.57–1.84 G | 1.89–2.89 G | 2.05–2.76 G |

  The envelope depends on speed. On every class, braking p99 is 1.32–1.86 G below
  150 km/h against 1.76–2.79 G above 200. Hypercar lateral grows from 2.0–2.4 G at
  60–160 km/h to 2.5–3.6 G at 180–280 km/h (Spa). So the envelope is drawn per speed band
  (< 150, 150–200, ≥ 200 km/h) as well as overall.
- **Grip utilisation**: a lap's mean of combined G ÷ E, over its samples with combined
  G ≥ 0.5 G. E is the session's p99 of combined G over racing laps.
  - Its Spearman correlation with lap time is negative in 16 of 16 sessions with ≥ 5
    racing laps, median −0.79 (range −0.53 to −1.00). With full throttle and braking
    (§8.13.4), it is one of only three measures here that consistently go with pace.
  - Variants measured the same or worse: E at p98 −0.79, a speed-binned envelope −0.74,
    direction-binned −0.71, all samples rather than ≥ 0.5 G −0.76 (one file +0.49), and the
    share of time above 90 % of E −0.47.
  - Per-lap values sit in a narrow band (Sebring Race 0.597–0.618), and E is the session's
    own. So utilisation is a within-session trend, never compared across sessions, cars
    or tracks.

**Driver aids** (`TC`, `ABS` and their level events)
- **TC and ABS time**: seconds per lap with the aid active, from merged pulses, plus
  episodes per lap (merged at 0.25 s; median 8–22). Each lap shows the level in force.

  | Car and conditions | Active per lap (median) |
  |---|---|
  | GT3 ABS | 1.6–5.4 s |
  | GT3 TC | 2.3–7.2 s |
  | Hypercar TC, dry | 5.1–8.0 s |
  | Hypercar TC, wet | 13.5–18.2 s (Daytona's storm and wet races, Interlagos in drizzle) |
  | LMP2 TC | 2.4 s (Spa) to 10.7 s (Daytona) |

  Daytona's wet Hypercar race went from TC 7 to TC 9, and from 3.6–4.0 to 16.7 s per lap.
- **Validation, TC**: the engine throttle is below the pedal on 97–99.7 % of TC samples,
  by 19–30 points.
- **Validation, ABS**: with the brake above 20 %, at least one wheel's `Brakes Force` falls
  below 97 % of its normal share on every ABS sample. The weakest wheel has a median
  0.46–0.63 of normal. The same happens on 8–36 % of samples without ABS, and 95–100 % of
  those lie within 50 ms of an ABS pulse (97–100 % within 250 ms). The game cuts brake
  force around ABS and nowhere else.
- **Where they fire**:
  - ABS sits at 100–157 km/h, with the brake on for 91–99.8 % of its samples.
  - TC sits at 82–117 km/h on the throttle, in gears 1–2, at 1.3–1.8 G lateral: corner
    exits.
  - 51–94 % of each session's activity falls in the busiest tenth of its 50 m stretches, so
    per-segment placement is the useful view.
- Shown only for aids the car has: there is no ABS row for a car whose setup says "N/A".

**Caught slides** (steering against lateral G, 10 Hz)
- **Countersteer episode**: steering against the turn. The rule:
  - |steer| ≥ 5 %, with its sign the *same* as lateral G's (in a turn they are opposite,
    §8.13.1);
  - |lateral G| ≥ 0.5 G;
  - above 60 km/h;
  - for at least three consecutive 10 Hz samples, peaking at ≥ 20 % lock.
- **Ground truth**: the one known incident in the three original samples, Spa qualifying's
  lap 3 (the lap with no `Lap Time`).
  - Through a right-hander at 126 km/h, lateral G holds −1.2 to −1.6 G. Steering goes from
    +7 % to −81.5 % (opposite lock) in 0.7 s and is back near zero 1.1 s after it crossed,
    while speed falls to 98 km/h.
  - That is one 11-sample episode, and the file's clean lap has none.
  - Sebring's Race has none in 17 laps.
- **Lap-time cost**: across 5 race sessions, the 39 racing laps with an episode ran a median
  0.53–2.54 s slower than their session's median lap. Laps without one ran −0.02 to
  −0.21 s.
- It finds slides the driver corrected, not oversteer in general. A slide that is not
  caught, and understeer, need a yaw rate the file lacks (§15.18).
- Episodes are listed per lap with their station, and marked on the lap-trend chart the
  way §8.3's incidents are.

#### 8.13.4 Which measures go with pace
Spearman correlation of each per-lap measure with lap time, within session. The data is 12
races of 16–117 racing laps (GT3, Hypercar, LMP2), using the query and lap rule of
§8.13.2:

| Measure | Sign | Median | Range |
|---|---|---|---|
| Full throttle | − in 12 of 12 | −0.59 | −0.35 … −0.76 |
| Braking | + in 12 of 12 | +0.40 | +0.06 … +0.66 |
| Pedal overlap | + in 11 of 12 | +0.40 | −0.23 … +0.83 |
| Coasting | − in 8 of 12 | −0.22 | −0.81 … +0.31 |
| Trail braking | mixed | −0.07 | −0.36 … +0.12 |
| TC time | mixed | −0.03 | −0.42 … +0.58 |
| ABS time (4 GT3 races) | mixed | +0.09 | −0.30 … +0.63 |
| Grip utilisation (16 sessions, all types) | − in 16 of 16 | −0.79 | −0.53 … −1.00 |

The race signs for overlap and trail braking did not hold on a mixed set. On the 12-file
pedal set, which mixes short practice and qualifying sessions with races, overlap ranged
−1 to +0.81 and trail braking −0.77 to +0.71.

A within-race correlation mixes technique with traffic, fuel load, tyre wear and mistakes.
A lap spent behind a slower car has less full throttle and more braking without the driver
doing anything differently. So **no measure is labelled good or bad, and none is combined
into a score.** Coasting shows why. It leans toward *faster* laps in 8 of 12 races, which
read naively says "coast more". What it more likely says is that slow race laps are spent
in traffic, where there is no room to coast (inferred). The screen shows each measure as a
per-lap trend beside lap time and leaves the reading to the driver.

#### 8.13.5 Where on the lap: segments and corners
Two frozen tables locate everything, one inside the other. They answer different questions,
so the screen draws them differently (§8.13.7).

**Segments: where the time goes.** Segments come from Compare's segment table (comparison
proposal §5; `SegmentTable` in `lib/features/driver_comparison/domain/segments.dart`).
- Each is a braking zone, a corner and the straight after it.
- They are detected once per (TrackName, TrackLayout) from a canonical lap's speed minima,
  then frozen, so "Seg 4" means the same metres here as on Compare.
- Segments tile the lap, so their times add up to the lap. Measured with the same rule on
  16 Sebring laps, segment times sum to `Lap Time` within 14 ms (median 5 ms).
- **Every time figure on this screen is per segment, never per corner.**

**Corners: what the road does.** Corners are detected from path geometry, once per
(TrackName, TrackLayout).
- The input is GPS curvature over a ±20 m window. It matches lateral G ÷ v² at
  r 0.995–0.999, slope 0.97–1.00, on 18 sessions.
- The detector runs on the median over the layout's clean laps. A corner starts at
  R ≤ 500 m and ends at R ≥ 1 km, and is split at a valley below half the smaller
  flanking peak.
- Each corner carries a direction, a radius at its apex and a turn angle.
- Measured: the same corners in every session of a layout to a median 2–6 m. Sessions with
  only one or two laps add one or two extra corners. GT3, Hypercar and LMP2 sessions at
  the same layout match every corner, with at most one extra in either (Interlagos,
  Imola).

Corners and segments disagree in useful ways, and that is why both are kept. Sebring
School has 7 geometric corners in Compare's 6 segments:
- A chicane is two corners in one segment, because it has one speed minimum.
- A fast kink taken flat is a corner with no segment of its own, because the car never
  slows for it.

Per corner, the screen shows local measures inside the corner's frozen span: slowest
speed, peak lateral G, grip utilisation, steering at the apex, TC/ABS time, countersteer.
Per segment it shows the timed measures: segment time, and braking, trail, overlap and
coast time.

What was measured and rejected:
- **Per-lap detection.** The session's corner count holds on 16 of 16 laps of one Sebring
  race (12 of 17 in the other), but only on 8 of 40 at Spa and 13 of 81 at Interlagos.
  Steering peaks are worse (7–15 per lap, Compare §12).
- **Curvature from lateral G.** On banking it is not curvature: 0.86–0.88 × the GPS value
  on Daytona's banking.
- **Official turn numbers**, for Compare's reason (proposal §12). Corners are labelled by
  segment and position ("Seg 3 · corner 2 · R, 43 m"), never "T7".

Every pedal sample and event is placed on `Lap Dist` (as Compare's `PlacedSeries` does)
and totalled per segment and per corner span. The comparison is the selected lap against
the median of the session's racing laps.

#### 8.13.6 Conditions and electronics, per segment
The user's question is how grip, track temperature, tyre compound and electronics changes
show up corner by corner. The file holds these as per-lap facts:
- `Minimum Path Wetness` (the grip proxy the file has; there is no rubber or grip-level
  channel);
- `Track Temperature` and `Ambient Temperature`;
- `TyresCompound`, per wheel;
- `TCLevel`, `TCCut`, `TCSlipAngle` and `ABSLevel`;
- `Brake Bias Rear` and `Brake Migration`;
- `FuelMixtureMap`.

A **conditions lens** groups the session's racing laps by one of these and shows, per
segment, the change in segment time, slowest speed and TC/ABS time. Measured on the natural
experiments in the library (20 races with a change inside them):

| What changed | Where | What the segments showed |
|---|---|---|
| Wet (wetness ≥ 12.5 %) against dry | 3 Daytona Hypercar races, 8–16 wet and 13–15 dry laps | Every segment slower by 1.7–3.6 s. The loss is uneven: the three infield segments lose 12.5–26.9 % of their dry time, the banking and straight segments 6.6–8.9 %, in the same order in all three races. TC +1.3–3.7 s per segment; slowest speed −11 to −31 km/h. |
| Compound index 0 → 2: used Mediums to **Wets** on a dry line (named from the setup, §15.20; path wetness 0 throughout) | Interlagos Hypercar (BMWMH), 16 °C track, 15 against 17 laps | +3.7 s per lap, spread evenly (3.4–5.1 % per segment). TC +0.55–1.27 s per segment. The largest drop in slowest speed is in one segment (−8.4 km/h). |
| TC power cut 8 → 9 | Imola GT3, alternating 8 / 9 / 8 over laps 19–131, adjusted for lap trend | −0.03 to −0.12 s in six segments, +0.09 s in one (standard errors 0.02–0.07). TC *active time* unchanged (≤ 0.12 s): the cut level changes how hard TC cuts, not how often. |
| Fuel mixture map | 5 Hypercar races, switched lap by lap | Nothing clears the noise, and the signs flip between races (\|Δ\| ≤ 0.31 s, mostly under 1.5 standard errors). |
| Track temperature | 20 races | Not measurable within a race. It moves with lap number at \|r\| ≥ 0.87 in 19 of 20 races, so it cannot be separated from fuel burn and tyre wear. Across sessions, Compare found no whole-lap effect (r ≈ 0 over 136 sessions). |

What the lens therefore does:
- **States what changed together.**
  - In all four wet Daytona races, compound 0 → 3, a higher TC level and rising wetness
    arrived on the same lap. So the wet contrast is "wet, as the driver ran it", and the
    lens names all three.
  - A compound change comes with a pit stop. Fresh tyres would make the new compound look
    faster, so a loss across it is if anything understated.
- **Adjusts for drift where it can.** When a setting alternates (TC 8 / 9 / 8, mixture maps),
  each segment is compared after removing the lap-number trend, which carries fuel burn
  and tyre wear. When a change happens once, the lens compares the laps either side of it
  and says it could not adjust.
- **Greys out what is noise.** A segment whose change is under two standard errors is drawn
  muted and labelled "within lap-to-lap noise". That covers most of the TC-cut and every
  mixture-map result above.
- **Leaves track temperature out of the within-session contrasts.** It shows it as a
  per-lap chip instead.
- **Names a compound only where the file can.** The event stores an index into the
  session's list of compounds, and the setup's `WM_COMPOUND-W_*` names the one in force
  at recording start (§15.20). A file's starting index takes that name. A later index is
  named through the game's order (Soft, Medium, Hard, Wet, minus what the session does
  not offer) and the setup's count of compounds, where those leave one compound for it;
  otherwise it reads "compound n". So the four wet Daytona races read Soft → Wet and
  Interlagos reads Medium → Wet, while a GT3's second compound stays "compound 1"
  (two on offer: Hard or Wet). (The earlier rule here, "index 3 is the wet tyre", was
  inferred from four Daytona races and does not generalise. The BMW's wet tyre at
  Interlagos is index 2.)

A cross-session version (the same car and layout, sessions grouped by conditions) needs the
library index (§9.6) to carry per-segment summaries. It is not specified here.

#### 8.13.7 The screen
The `driving_technique` route, a placeholder today, becomes one session-scoped screen. It
answers three questions in reading order: *how did this lap go*, *where on the track*, and
*what changed it*.

- **Header** (static chrome, the one `GlassSurface` here, §9.7.3):
  - the lap strip, with the racing laps as squircle chips;
  - the selected lap raised;
  - laps with a countersteer episode carrying a small marker;
  - the conditions lens selector (§8.13.6), listing only the conditions that changed this
    session. With none, it reads "Conditions were constant this session".
- **Lap at a glance**: a row of stat cards, one per family. Each card shows:
  - the lap's value and the session median;
  - a 1-line plain-language subtitle. Overlap, for example, reads "both pedals pressed at
    once; mostly the throttle-to-brake handover".

  Every card has an info popover with the exact definition and how it was checked
  (§8.13.3), in plain words. The three measures that go with pace (§8.13.4) say so. The
  others say they describe the lap, not its speed.
- **Track panel**: §8.5's map with the segments as numbered bands and the corners as
  chevron markers (§8.13.5). Hovering or selecting either links the whole screen.
- **Segment table**: one row per segment, "Seg N", showing the timed measures for the
  selected lap against the session median. Each segment expands to show its corners as
  indented rows ("corner 2 · R · 43 m") with their local measures. With a lens active, the
  table gains the per-segment change columns.
- **G-G panel**: the selected lap's scatter over the session's density grid, with the
  envelope per speed band.
  - The axes read "← LEFT", "RIGHT →", "BRAKING" and "ACCELERATING": left turns plot on
    the left. Lateral G is + left, and that was checked against the GPS path on a Daytona
    Hypercar race. While turning, its sign matches the heading's turn in 559 of 631
    samples above 0.8 G. All 11 detected corners' mean lateral G has the sign their
    direction says.
  - It is a custom painter. It needs no cursor, but neither `fl_chart` nor the synced core
    fits a 5,720-cell grid drawn beneath up to 2,244 points.
  - Hovering a segment or corner keeps its points at full strength and fades the rest:
    "where in the friction circle was this corner".
- **Shift panel**: upshifts per gear against L, by band, with each band's measured da
  (§8.13.3).
- **Per-lap trends**: small multiples of `PerLapTrendChart`, one per measure, with lap time
  as the first.
  - These are `fl_chart` and unsynced, §9.5's per-lap aggregate case.
  - Selecting a lap in any of them selects it for the screen. That is in-screen state, not
    `ChartSync`, so §15.8's migration risk does not arise.
- **Class-aware**: ABS appears only where the setup has ABS, and an absent aid says so in a
  sentence rather than an empty chart. Hypercar energy belongs to §8.7, not here.

**Layout.** On desktop the header spans the top. Below it, the track panel and segment
table take the left ~60 %, and the G-G and shift panels sit in the right column, with the
trends across the bottom. Below 1100 px it becomes one column in reading order: header, lap
at a glance, track, segments, G-G, shifts, trends.

"Open in Trace" (the app-bar button, or ⌘/Ctrl+Enter) selects the shown lap and opens Trace
at its start. That is the screen's one link into the synced system. Trace has no way yet to
open at a station, so a segment, corner or episode opens its lap, not its place on it.

#### 8.13.8 Look and motion
The bar is the user's: beautiful, understandable, polished and nicely animated. Everything
is built from §9.7's primitives and tokens, so it reads as the same app.

- **Colour.** No new hues: §9.7.1's wheel is full (Compare measured candidate tints at 3.2–13.2
  ΔE, under the 15 floor).
  - Measures wear their channel's identity: braking and ABS brake red, throttle and TC
    throttle green, steering and countersteer the steering neutral.
  - Segment bands alternate two neutral surface tones; corners are told apart by glyph, not
    colour.
  - The G-G density grid is a single-hue sequential ramp.
  - Lens changes use the delta's cool blue, muted when within noise. There is no green and
    red for gained and lost, for Compare's reason.
- **Type and numbers.** UI voice General Sans, every numeral in JetBrains Mono with
  tabular figures (§9.7.7), units set smaller beside the value. When the selected lap
  changes, numbers roll to their new value over 250 ms. Tabular figures keep the columns
  still while they roll.
- **Cards and states.** Every panel is a `SquircleCard` with the gradient edge (§9.7.2) and
  loads through `AsyncValueView`. Each skeleton is in the shape of the content it stands
  for: a ring for the G-G, bars for the trends, rows for the table. Errors and absences are
  sentences.
- **Motion.** All of it goes through `AppMotion.duration` on the standard
  `cubic-bezier(.16,1,.3,1)` curve, and all of it disappears under reduced motion (§9.7.4).
  - *Entrance*: cards stagger in by reading order (`useFadeInOnMount`, 40 ms apart) and
    leave the animation tree once landed, as §9.7.4 requires.
  - *Lap change*: the G-G cloud morphs over 450 ms. Each point travels from where the
    previous lap was at the same `Lap Dist` to where this lap was, so the eye sees *how*
    the lap differed, not just that it did. The session grid underneath stays still. The
    map's bands and the table cross-fade, and the trend charts slide their selection
    marker.
  - *Linking*: hovering a segment lifts its band on the map (120 ms), fades the other
    G-G points to 25 %, and highlights its table row. Moving across segments chains these
    without restarting from zero.
  - *Lens*: switching a lens on grows each segment's change bar from zero over 300 ms, and
    within-noise bars settle at their muted level. Switching it off reverses the growth.
  - *Countersteer*: a lap's episode marker pulses once when the lap is first shown, never
    on a loop.
  - *Segments expanding* to their corners use `AnimatedSize`, skipped rather than zeroed
    under reduced motion (the Flutter 3.47 assert, §9.7.4).
- **Performance.** The G-G morph is one `CustomPainter` driven by an animation, with no
  widget per point, behind its own repaint boundary. The budget is §15.3's: no frame over
  budget in profile mode while scrubbing laps on Imola's 127-lap race.
- **Keyboard** (§10): ←/→ step through racing laps, ↑/↓ through segments, Enter expands a
  segment, ⌘/Ctrl+Enter opens it in Trace. Tab order follows the reading order.
- **Verified the way the rest of the app is.**
  - One golden per card with motion disabled, plus the screen tour's PNGs (§14).
  - A widget test that stepping a lap completes the morph and lands on the new lap's
    values.
  - A profile-mode frame count for the lap morph.

#### 8.13.9 Architecture and tests
- **Queries** (`lib/data/duckdb/technique_queries.dart`), as built. Each reads the master
  grid like `lapStatsSql`, and takes laps and stretches as `VALUES` lists, aggregating
  inside DuckDB (§9.5). The steering scale comes from one `max(abs("Steering Pos"))`.
  - `lapPedalStatsSql`: the 50 Hz pedal frame → one row per lap, and per lap and segment
    or corner. It holds the pedal shares, overlap, coast and trail, the slowest speed,
    steering at a corner's apex, and the raw TC/ABS flag time.
  - `pedalRunsSql`: each lap's runs of pedal state, which the domain classifies into
    overlap and coast spans.
  - `lapGgSql`: the 10 Hz frame → the per-lap sustained peak and the utilisation numerator
    and count, per stretch, plus the session's envelope per speed band, density grid and
    direction limits. `lapGgPointsSql` reads one lap's points when it is shown.
  - `gearRowsSql` and `upshiftReadsSql`: the `Gear` rows, from which Dart counts shifts.
    Each upshift's neutral row comes with its pre-shift RPM maximum, da, pedal and
    limiter time.
  - `aidEpisodesSql`: the 0.25 s pulse merge, done in SQL, counted per lap.
    `countersteerSamplesSql`: the candidate 10 Hz samples; the episode rule is Dart's.
  - `lapProfilesSql`: each lap's 10 Hz path, distance and speed. Segment crossing times
    and the geometric corners are computed in Dart from it. That replaced a separate
    crossings query (0.75 s on Imola's 127 laps), since the profiles are read anyway.
  - The conditions come from Compare's `sessionConditions`, extended rather than
    duplicated. It gains each lap's electronics settings at its start, and whether they
    changed during it.
- **Corner table**: detected from GPS curvature on the layout's clean laps (§8.13.5). It is
  frozen and keyed by `TrackKey` next to Compare's segment table, so both are detected
  once and agree on which laps are clean. Where Compare has not frozen a segment table for
  the layout yet, the screen detects and freezes one by Compare's own rules.
- **Repository**:
  - `TechniqueRepository`, in the feature's own `data/` folder, holds the reads. It lives
    beside the feature rather than in the shared `TelemetryRepository`, since nothing else
    reads these shapes.
  - `CarSetup` gains `revLimiter`, `steerLock` and `hasAbs`, from `VM_REV_LIMITER`,
    `VM_STEER_LOCK` and `VM_ANTILOCK_BRAKES`.
- **Domain** (`lib/features/driving_technique/domain/`, pure Dart):
  - Every threshold is a named constant with the measurement that set it, as in
    `segment_findings.dart`: 2 % applied, 98 % full, 5 % turned, the 0.25 s pulse merge,
    the 0.3 s sustained-peak window, the 0.5 G utilisation floor, the countersteer rule and
    the limiter bands.
  - It also holds overlap and coast span classification, and per-segment and per-corner
    placement.
  - The conditions lens: lap grouping, lap-trend adjustment for alternating settings, the
    "changed together" list, and the two-standard-error noise rule.
- **Application**: Riverpod providers keyed by `TelemetrySource`, with the segment table
  from Compare's `segment_tables.dart`.
- **Tests**:
  - Unit tests on constructed arrays: shift counting through neutral rows, pulse merging,
    span classes, the steering-scale rule, limiter bands, countersteer runs, corner
    hysteresis and splitting, and the lens's trend adjustment. The last one checks a
    planted effect is recovered from an alternating sequence with drift.
  - A lap-rule test: a lap that starts with `In Pits` already on is not a racing lap.
  - An integration test on the fixture that pins laps 1–3 at the values this section
    measured, and the identity n = 50 × `Lap Time` ± 1:

    | Lap | 1 | 2 | 3 |
    |---|---|---|---|
    | 50 Hz samples | 3225 | 3228 | 3202 |
    | Overlap | 0.81 % | 1.39 % | 0.75 % |
    | Coasting | 5.09 % | 4.12 % | 5.03 % |
    | Full throttle | 63.72 % | 63.04 % | 65.90 % |
    | Braking | 18.95 % | 17.22 % | 17.43 % |
    | Trail braking | 70.4 % | 68.5 % | 67.6 % |
    | TC | 2.12 s | 2.66 s | 2.54 s |
    | ABS | 3.86 s | 4.32 s | 3.38 s |
    | Upshifts (and downshifts) | 10 | 10 | 9 |

  - Where the user's Telemetry folder is present (as `findings_test.dart` does):
    - Spa qualifying's lap-3 episode. "Lap 3" is the file's own lap value, `Lap.index` 3,
      which the app labels Lap 4. The 122.7 s `Lap Time` row at its start closes lap 2,
      so lap 3 is the one without a time;
    - a February file's steering scale;
    - the LMP2 240° file's 0.714976 factor;
    - Imola's Hypercar pit-exit lap being excluded;
    - the wet Daytona race's segment ranking (infield segments lose the largest share).
  - As built, these are `test/features/technique_domain_test.dart` (the rules),
    `test/features/technique_gg_panel_test.dart` (the morph, with and without reduced
    motion) and `integration_test/technique_test.dart` (the fixture table and the five
    folder cases). The fixture matches the table above exactly. On the fixture, the SQL
    pulse merge also equals the same merge done in Dart from the raw flag rows, lap by lap.

#### 8.13.10 Not established
- What per-car reference `Steering Pos` is a percentage of (§15.16).
- What the last 0.3–4.9 % of Hypercar throttle trims are (§15.17).
- What compound indices 0–2 are (§15.20).
- Oversteer the driver does not correct, and understeer. There is no yaw rate (§15.18).
- Why the pedal stops reaching 100 late in long races (§15.19).
- Which laps were run under caution: `Yellow Flag State` never changes.
- Whether any measure describes the driver rather than the lap's circumstances. Grip
  utilisation, full throttle and braking consistently go with lap time; §8.13.4 shows only
  that the others do not, and correlation is not cause for any of them.
- Whether track temperature changes a corner. Within a race it moves with lap number, so it
  cannot be separated from fuel and tyres (§8.13.6). Across sessions it has not been
  measured per segment.

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
                        #   distance-axis remap, track projection, painters, the shared
                        #   cursor/viewport controller, and the widgets features compose
                        #   (TracePanel, TrackMapView). Built in Phase 1.
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
they genuinely don't participate in the synced system. **The read behind them exists as of
v0.10**: `lapStatsSql` summarises any channel per lap (first, last, min, max, mean, sample
count) inside DuckDB, one row per lap however long the session, by the same
aggregate-before-timestamping rule as decimation — lap starts become channel row numbers,
so only one timestamp lookup happens per lap. §8.7's fuel view is its first user; tire and
brake trends (§8.6) are the next.

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

**Render side, answered in v0.8 for a single lap.** The query side was measured in v0.7;
what was still open was whether anything could *draw* those points. It can, and the
single-lap case turns out not to need the re-query loop at all — which is worth stating as
arithmetic rather than as a result, because the arithmetic is what says where it stops
being true:

- A lap is fetched once at **100 buckets per second**, capped at 6000. The master grid is
  itself 100 samples per second (§5.1), so the fastest channel in the file arrives at one
  sample per bucket and every slower one is oversampled. **Zooming inside a lap has nothing
  finer left to fetch**, so no re-query is needed and none is done.
- The cap is where that stops holding. A 6-minute Le Mans lap resolves at 6:1, and a
  *session*-scoped viewport — Phase 2's stint views — is where §9.5's re-query per viewport
  becomes load-bearing rather than optional: a 6-hour stint is 2.16M rows on one 100 Hz
  channel, and no single bucket count both covers it and resolves a 60-second window inside
  it. What that path needs is a controller recomputing the window; the repository already
  takes the window and bucket count.
- **The cursor and the trace are separate paint layers.** The trace costs thousands of
  points and changes only when the data or the viewport does; the cursor changes on every
  pointer move. Keeping them apart behind a `RepaintBoundary` is what stops a scrub from
  redrawing the trace at pointer rate — and it only works because the chart view model
  watches `chartSync.select((s) => s.axis)` rather than the whole state, so the plot objects
  stay identical across a cursor move and the painters' identity checks actually hit.
  Watching the whole state would rebuild every plot in the lap at pointer rate while
  looking, from the outside, exactly the same.

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

**Built in v0.11**, as a drift file in the app-support directory: one row per path with
every §8.1 fact, completed and timed lap counts, the best lap and which one, the
`metadata.Version` and the clock-gap count asked for above, the file's size and
modification time, and when it was imported and last opened; folders in a table of their
own. The modification time is stored as integer milliseconds and dates as ISO text,
because drift's default Unix-seconds storage truncates the fixture's
1790726677.7102625 s and would make every rescan see a changed file. `SessionIndexStore`
is the seam, and on **web it is in memory, by decision**: an upload has no path to reopen
from, so a persisted row could only ever say "upload this again". Search, filtering and
personal-best ranking sit above the store in plain Dart, so the two implementations
cannot disagree about any of them.

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

**These are identity colors, and they are not a categorical palette — checked, in v0.8.**
Run through a standard categorical-palette validator against this theme's dark surface
(`#191114`), the five pass chroma, adjacent-pair colour-vision separation (worst 11.2 ΔE
against a target of 8) and 3:1 contrast, and fail the *all-pairs* separation floor on
**speed↔throttle at 12.0 ΔE**, under the 15 a reader with full colour vision needs to tell
two co-plotted series apart. That is a real limit and worth naming rather than
rediscovering: it is safe today **only because §9.5 stacks one channel per panel**, each
directly labelled with its own swatch, name and unit, so no two of these colours ever share
a plot frame. The day two do — a per-corner tire panel (§8.6), a multi-lap overlay (§8.4) —
that pair has to be re-stepped or given a second encoding first.

Neither the multi-lap overlay (below) nor the per-corner tyre view (v0.11) turned out to
be that day. The tyre view's four corners are four small multiples on one shared scale —
one corner per frame, never four hues in one.
Its one new identity colour, a honey `#F0C069` for tyres whose tread temperatures are a
single-hue ramp of it, shares a screen only with brake red, and is validated against that
pair: ΔE 20.9 at normal vision (floor 15), 15.1 at worst under simulated colour-vision
deficiency (target 8), 11.9:1 contrast.

The multi-lap overlay (v0.10) turned out not to be that day, and why is worth keeping: it
puts two *laps* in a frame, not two *channels*. A reference is the same channel, so it keeps
the channel's hue — one colour per channel type, not per lap — and is told apart by the
second encoding the reference apps already use: a dotted line against the solid filled
trace, lifted 35% toward the ink colour so it does not sink into the primary's fill. The
header pairs the two readouts the same way, the reference's in its line's tint. The
all-pairs failure above is untouched by all of this, and still stands for the first panel
that co-plots two different channels. The delta panel's own colour needed no check either:
it is drawn alone in its frame, and signed toward a zero line rather than coloured green
for gained and red for lost, which would lend throttle's and brake's identities to a panel
stacked directly above both.

**Fuel, energy and state of charge got identity colours in v0.10 — and could not be told
apart from every channel, which turned out not to matter.** Every hue left on the circle
measured within ΔE 5–9 of an existing channel colour (normal vision), under the 15 two
co-plotted series need: the wheel is full. The resolution is the rule the channels already
live by — identity colours must separate only where they share a frame — and these three
only ever share one screen, as small multiples. Validated as such, all pairs: orange
`#F08A4B`, teal `#2FD3C0` and yellow `#F2D14B` clear colour-vision separation at 13.4 ΔE
(target 8), normal vision at 17.5 (floor 15), and 3:1 contrast. The same validator run
reports something the v0.8 check did not mention: **every channel colour sits above the dark
lightness band** (OKLCH L 0.48–0.67, calibrated on a `#1a1a19` surface; ours reach 0.65–0.87
on `#0B0709`). That is the palette's bright-on-near-black character rather than an accident,
so the three newcomers match it instead of being the only dim marks in the app — but it is
a palette-wide decision worth making on purpose one day, not per colour.

Two colours were added in v0.8 for the channels §7.1's reference stacks show but §9.7.1
never named, and neither is a categorical hue, deliberately:

- **Steering** is a *bipolar* signal — the fixture's `Steering Pos` runs −23.8 to +51.3 —
  so it gets a neutral. That is the conventional encoding for a signal whose interesting
  value is its deviation from centre, and it keeps the saturated colours meaning "a
  performance channel".
- **Gear** is the one event-sourced trace in the default stack, drawn as held steps rather
  than a filled trace, and takes chartreuse — the widest gap left in the hue circle once
  throttle/brake/speed/RPM/delta are placed and the purple family is reserved for brand
  chrome.

**A second accent, and a darker ramp — added in v0.9.** One seed makes a coherent
palette and a monotonous one: every surface, border and emphasis ends up a tint of the
same wine, and the eye stops finding the emphasis. **Iris** (`#7C5CFF`) is a second
identity, chosen under two constraints rather than for variety. It stays inside the purple
family this section already reserves for brand chrome, so a second accent cannot collide
with a channel identity colour by construction — the reservation is what makes it safe to
add one at all. And it lands on a domain convention worth having: purple is the fastest
sector on every timing screen in motorsport, which is the role Material's `tertiary` slot
already plays in the lap table (§8.3). It is grafted onto `secondary` and `tertiary` by a
second `ColorScheme.fromSeed` run; the brand seed still generates everything
contrast-related.

The surface ramp is no longer the generated one either. `fromSeed`'s dark ramp starts at
`#191114` and its containers sit within a few percent of it — legible, but the containers
never read as *objects* on a background, which is the whole visual proposition of a
panelled telemetry tool. The base drops to `#0B0709` and the container tones are set
explicitly, which gives cards something to be lifted off and the §9.5 charts a darker field
to draw a saturated trace on. The palette check above is unaffected: its separation legs
are measured between the channel colours themselves, and its contrast leg only improves as
the surface goes darker.

**Gradients are chrome, and they all run the same way.** One direction and one journey,
everywhere: top-left to bottom-right, wine → iris. That single rule is what keeps a
gradient from reading as decoration — a border, a badge and a button all look lit by one
source instead of each having a mood. Nothing in the gradient tokens is ever used on a
trace, a track map or a value ramp: colour there carries channel identity or magnitude, and
a gradient laid over either makes the same value read as two different ones depending on
where it falls in the frame.

**Magnitude is a different job from identity, and gets a different mechanism.** A track map
coloured by speed (§8.5) is asking colour to carry a *quantity*, so it uses a sequential
ramp: **one hue, varying in lightness**, anchored on the channel's own identity colour and
running dark→light with increasing value (correct on this theme's near-black surface). Never
a rainbow — a multi-hue speed ramp implies category boundaries the data doesn't have and
stops being readable under common colour-vision deficiencies. Holding the channel's hue also
keeps "one colour per channel type" true of the map: a map coloured by brake is red
throughout and only its lightness moves. Identity colours live in the design system;
how a quantity becomes colour lives with the charts, in `widgets/charting/value_ramp.dart`.

#### 9.7.2 Shape

`ContinuousRectangleBorder` — Flutter's built-in iOS-style continuous-curvature corner,
i.e. an actual squircle, not a circular-arc approximation — costs zero new dependencies
and is the default shape for buttons, inputs, and cards. A small radius scale (`sm`/`md`/
`lg`/`xl`) is defined once as shared tokens (§9.7.6) rather than each widget picking its
own value, and `StadiumBorder`/pill shapes are explicitly avoided so nothing ever rounds
into a circle. (`figma_squircle` is a possible later upgrade if we ever need
Figma-parity corner-smoothing control — not needed to start.)

Two shapes fill the gaps Flutter leaves in that sentence. A `BorderSide` carries a single
`Color`, so the stock shape can draw a squircle *or* a gradient edge, never both:
`GradientSquircleBorder` borrows the token shape for its geometry and strokes the outline
itself, which is how a container's edge carries §9.7.1's wine→iris light. And an
`InputDecoration` will only accept an `InputBorder`, whose only outlined implementation is
a circular-arc `RRect` — so "inputs" was the one word in the paragraph above that wasn't
actually true of the app. `SquircleInputBorder` is the same continuous corner wearing an
`InputBorder`'s interface, and it strokes with a gradient too, so a focused field is the
edge lighting up rather than a different border.

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
  settings. **Enforced in v0.11** through one helper, `AppMotion.duration(context, base)`,
  which every implicit animation in shared code goes through; route transitions, whose
  duration is fixed at construction, return the bare page instead. Two things found on the
  way: a *finished* `FadeTransition` still costs an offscreen layer (an opacity of 255 is
  still a repaint boundary, and it moved one golden pixel by one blue step), so the
  staggered entrance takes itself out of the tree once a tile lands; and
  `AnimatedSize(duration: Duration.zero)` asserts in Flutter 3.47, so a reduced-motion path
  has to skip it rather than zero it.
- Keyboard (§10), also v0.11: every tappable card is a Tab stop activated by Enter/Space,
  with a focus ring drawn as the gradient edge lighting up — outside the child, since the
  selected nav slot already wears the same edge. ⌘/Ctrl+O opens a file and ⌘/Ctrl+1…9 jump
  between destinations. Focus order is by screen position, not by focus-attach order: the
  rail's slots are built lazily and attach after the session badge, which had made all
  fourteen unreachable by Tab from a page with nothing else to focus.

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
| `GradientSquircleBorder` | The token squircle stroked with a gradient — the edge every card, glass surface and badge is drawn with (§9.7.2) |
| `SquircleInputBorder` | The same corner as an `InputBorder`, so text fields finally share the app's shape (§9.7.2) |
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
| Language/framework | Flutter, newest stable, pinned per project by FVM (`.fvmrc`) | Targets listed: Windows, macOS, Linux, Web. Tracked deliberately rather than frozen — §14's v0.10 upgrade |
| Material components | `material_ui` (not `package:flutter/material.dart`) | Material left the framework as its own package; `go_router` 18 already depends on it (§14) |
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
| CI | GitHub Actions (`.github/workflows/ci.yml`): matrix across windows-latest/macos-latest/ubuntu-latest + web, plus a weekly newest-stable job; Dependabot for pub and actions | §13 |

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
  easy to introduce and hard to eyeball-catch. Live as of v0.8 (`test/goldens/`) and now
  real assertions rather than groundwork: a widget test proves the strings and the numbers
  and nothing about whether the trace is drawn upside down, the circuit is stretched, or a
  readout sits off its panel. Regenerate with `flutter test --update-goldens test/goldens/`
  — **and then look at the PNGs**: the images are the artifact, the diff is only the alarm.
  Three defects were caught this way that no assertion had been written for (axis labels
  colliding with panel titles, labels hidden *under* a filled trace, and `-0` on any axis
  crossing zero).
  - **The baselines are committed, and tagged `golden`.** Committed because
    `matchesGoldenFile` *fails* rather than skips when a baseline is absent, so an ignored
    baseline directory means a suite that only passes on the machine that generated it.
    Tagged because pixel baselines are platform-dependent — text shaping and antialiasing
    differ per OS — which makes them incompatible with §13's matrix unless the matrix says
    so. Nothing is lost on the other runners: everything the goldens cover is also asserted
    structurally in `test/features/`.
  - **The chart tests are fed real telemetry, generated into Dart.** `dart_duckdb`'s native
    library is not linked into the `flutter test` process, so no `.duckdb` file can be
    opened there at all — which would leave every chart test running on an invented curve.
    `tool/make_lap_fixture.py` emits `test/fixtures/sebring_lap1.dart` from the checked-in
    fixture instead: one real lap, resampled to 5 Hz, so a widget test asserts against
    numbers the game actually recorded and a golden renders the actual circuit. Checked in
    as a script for the same reason `make_fixture.py` is — a fixture nobody can regenerate
    is an artifact described only in prose.
- **Integration tests** (`integration_test`) covering the import → analyze golden path on
  each desktop platform plus web.

## 13. CI/CD & Distribution

- GitHub Actions matrix: build + test on `windows-latest`, `macos-latest`, `ubuntu-latest`,
  plus a web build job — **built in v0.10** as `.github/workflows/ci.yml`, not yet run
  (nothing has been pushed since). Every job installs exactly the release `.fvmrc` pins and
  resolves exactly `pubspec.lock` (`--enforce-lockfile`), so a red run means the code broke,
  not the world. One Ubuntu job also regenerates the committed `*.g.dart`/`*.freezed.dart`
  and fails on any diff: a stale generated file compiles fine and is simply wrong.
  - **A weekly `latest-stable` job asks the other question** — would the project still pass
    on the newest releases? — by installing the newest Flutter stable, running
    `pub upgrade --major-versions`, and warning when `.fvmrc` is behind. Scheduled only,
    never on a push or PR, so a release someone else shipped cannot turn an unrelated change
    red. Dependabot opens the pub and actions PRs; the Flutter SDK is not a Dependabot
    ecosystem, which is what that job is for.
  - `integration_test` runs **one file per `flutter test`**: given the whole directory,
    every app after the first fails to launch ("the log reader stopped unexpectedly"),
    measured on macOS with 3.47.5. The Linux and Windows legs run with `continue-on-error`
    until one has passed once (§15.11).
  - **`flutter test --exclude-tags golden` on every runner except macOS**, which runs the
    full suite. The golden baselines are pixel images generated on macOS and will not match
    another platform's text rendering; the tag is what lets one matrix hold both (§12).
    Currently 742 of 767 device-free cases run everywhere, and 767 on macOS.
  - The web job needs `python3 tool/fetch_web_deps.py` before `flutter build web`, since
    `web/duckdb/` is fetched rather than committed (§9.2, `web/README.md`). Worth caching on
    the pinned versions — it is ~70 MB and changes only when those versions do.
- Distribution (later, not needed for early dev):
  - Windows: MSIX packaging.
  - macOS: signed/notarized `.app`/`.dmg` (Gatekeeper will otherwise block a locally-built
    app reading user files). **App Sandbox is deliberately off** (both entitlements
    files) — confirmed during the Phase 0 spike that a sandboxed macOS build cannot open
    an arbitrary file path at all (`Operation not permitted`), and we're not targeting the
    Mac App Store, so there's no reason to take on security-scoped-bookmark plumbing for a
    restriction that doesn't apply to us.
    - Both files must nonetheless declare
      `com.apple.security.files.user-selected.read-only`. It grants nothing outside the
      sandbox; it exists purely because `file_picker_darwin` gates every panel behind a
      `SecTask` entitlement check and never asks whether the process is sandboxed. See the
      package-upgrade findings in §15 — this is what made the import button appear dead —
      and `test/macos_entitlements_test.dart`, which fails if either key is dropped.
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
- **Phase 1 — MVP — done.** Single-file import (desktop + web), Session Overview, lap time
  table, single-lap telemetry trace (speed/throttle/brake/gear vs. distance), basic 2D track
  map.
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
  ~~`widgets/charting/`, the single-lap trace, the 2D track map, and the web wiring~~ —
  done, and Phase 1 with it. Total suite: **194 unit/widget/golden tests** (`flutter test`,
  no device) and **55 `integration_test` cases** against the real fixture. Four things came
  out of it worth recording:
  - **The track map's GPS channels are a local frame, and the projection needs a cosine.**
    §8.5.1 has the measurements. The failure mode is the one this project keeps meeting:
    the naive version produces a *plausible-looking* circuit that is 69% too long, and only
    an independent ground truth — the file's own `Lap Dist` — distinguishes it from the
    correct one. Checked on every fixture now, alongside the lap-boundary check.
  - **§9.5's re-query-per-viewport is not load-bearing at single-lap scope**, and §9.5 now
    carries the arithmetic that says where it starts being. Worth writing down because the
    honest version of "we didn't build it" is "here is the condition under which it is
    needed", not "it seemed fine".
  - **The channel palette fails an all-pairs categorical check** — on speed↔throttle, a
    pair that predates this phase — and is safe only because one channel per panel means no
    two share a plot frame (§9.7.1). Found by running a validator rather than by looking,
    which is the only way that class of thing gets found.
  - **`dart_duckdb`'s documented web setup has a latent type error.** Its template publishes
    the readiness promise under `duckdbWasmReady`, but the bindings read
    `duckdbduckdbWasmReady` — so upstream's `await` never resolves against anything and is
    a silent no-op. Publishing it under the name the bindings actually read makes the await
    real, and then it throws: the global is typed `JSPromise<JSAny>?`, non-nullable inside,
    so a promise settling with `undefined` raises "type 'Null' is not a subtype of type
    'Object'" out of an unawaited future during plugin registration — an uncaught rejection
    at startup and a DuckDB that never finishes initialising. Resolving with a value fixes
    it. Found only because the app was actually loaded in a browser and its console read;
    nothing in the test suite would have caught it, which is the same lesson §14 keeps
    recording one layer up.
  - **Web assets are self-hosted and git-ignored.** `tool/fetch_web_deps.py` vendors the
    pinned DuckDB-Wasm and Arrow builds into `web/duckdb/`; §10's offline-first requirement
    rules out the upstream CDN setup, and the ~70 MB of WebAssembly rules out carrying them
    in git. Verified end to end on Chrome: every request stays on the app's own origin,
    `selectBundle` picks the `eh` bundle from local files, the engine instantiates in
    ~0.5 s, and `registerFileBuffer` + `ATTACH … (READ_ONLY)` behave exactly as on desktop.
    See `web/README.md`.
- **Package upgrade (v0.7):** Riverpod 2→3, `freezed` 3→4, `file_picker` 11→12,
  `riverpod_generator` 2→4. Four things came out of it worth recording:
  - **`file_picker` 12 refuses to open a panel without a `files.user-selected`
    entitlement**, and does not first check whether the app is sandboxed — so turning App
    Sandbox off (§13) does not opt out of the check, it only guarantees the check fails.
    With neither key declared, `FilePicker.pickFile()` throws
    `PlatformException(ENTITLEMENT_NOT_FOUND)` in ~6 ms and no window is ever shown:
    measured on a debug build, then measured again after adding the key, where the same
    call sat open waiting for input instead. `read-only` is enough — §3 makes writing back
    a non-goal, and the plugin accepts either key for opening. The v11 escape hatch,
    `skipEntitlementsChecks()`, is now an empty method, so declaring the entitlement is the
    only route. Two things made this expensive to find: it is invisible to every test that
    drives the import controller directly (which is all of them, since a native panel needs
    a human), and the screen reported it as *"That file could not be opened"* — a message
    about a file the user had never been offered the chance to choose. Both are fixed:
    §8.1's controller now separates "the chooser failed" from "your file failed", and
    `test/macos_entitlements_test.dart` guards the key from a plain `flutter test` on any
    platform.
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
- **Toolchain and package upgrade (v0.10):** Flutter 3.47.0 → 3.47.5 (Dart 3.13.4),
  `go_router` 17→18, `file_picker` 12→13, `desktop_drop` 0.7→0.8, `freezed` 4.0.0-dev.3 →
  4.0.2, every other package to its newest release, and `pubspec.yaml`'s lower bounds
  tightened to what was resolved. The project now tracks the newest stable deliberately
  rather than freezing on the version it started with — README.md, "Toolchain", has the
  procedure. Five things came out of it:
  - **The SDK is per project now, through FVM.** The development machine's global
    `flutter` had been pinned back to 3.41.9 for another codebase that requires Dart 3.11.5
    exactly, while this one's lockfile already needed ≥ 3.12. Upgrading the global SDK
    would have broken that one, so `.fvmrc` pins this project's instead, and `environment`
    holds the same minor release as a floor.
  - **Material left the framework.** It now ships as `material_ui`, Flutter 3.47 carries a
    data-driven fix to migrate off `package:flutter/material.dart`, and `go_router` 18
    already depends on the new package — so staying on the old import would have left the
    app and its router on two different Material libraries. Migrated with that fix (50
    files, imports re-sorted after). The evidence that it changed nothing on screen is
    precise rather than eyeballed: the goldens differed from their baselines by *exactly*
    the same pixel counts before and after the migration (1,447 / 1,154 / 832 / 1,515 / 699
    on the five screens), so the migration contributed zero pixels. `fl_chart` 1.2.0 still
    imports the old library; it resolves `Theme.of` only in its candlestick chart, which
    §9.5's standalone charts have no use for, so explicit styles are enough.
  - **What did move the goldens was the engine**, by 0.05–0.13% per screen, and only on
    glyph edges: the diff images trace every label's outline and no trace, track or layout
    edge. Text rasterisation changed between 3.47.0 and 3.47.5. Regenerated and inspected;
    expect the same on every engine bump, which is why README.md says to look at the PNGs.
  - **`integration_test` has to run one file at a time on macOS** — see §13. All 51 cases
    (spike 10, data layer 39, app flow 2) pass on 3.47.5 run that way.
  - **`dart_duckdb` does not support Swift Package Manager**, and the macOS build now says
    so on every run: "This will become an error in a future version of Flutter." Recorded
    in §15 as the upgrade risk most likely to block a future Flutter release.
  - Settled on the way: `macos/Flutter/GeneratedPluginRegistrant.swift` loses its
    `path_provider_foundation` line for good. `path_provider_foundation` 2.6 is an FFI
    plugin with no registrar, which is why the file kept flip-flopping between machines
    on different toolchains.
- **Phase 2 — done in v0.11:** ~~multi-lap overlay + delta trace~~, ~~tires/brakes view~~,
  ~~fuel/stint view~~, ~~Session Library with local index/cache~~, ~~Events Log (§8.12 —
  cheap, direct off the catalog)~~, ~~per-lap aggregate trend charts~~ (§7.2/§9.5 — fuel,
  tyres, brakes, lap pace and race gaps all use them now). Two features not scheduled for
  Phase 2 came with it because their data turned out to be ready: ~~Race Pace & Gaps
  (§8.9)~~ and ~~the Setup Viewer (§8.10)~~.
  ~~Multi-lap overlay + delta trace~~ — done in v0.10, as a *reference lap*: one chosen lap
  drawn dotted over every panel of the one on display, with a delta panel heading the stack
  (§8.4 has the definition and its measurement). Same controls on the trace view and the
  track map, since they are one synced system. Total suite: **250 device-free tests** and
  **52 `integration_test` cases**. Four things came out of it:
  - **The file confirms a delta at exactly one point, and the check is now automatic.**
    The end of the trace must equal the difference between the two laps' `Lap Time`s:
    0.459 s against 0.468 s for the fixture pair at the app's own 10 Hz, 0.4587 s from the
    5 Hz Dart fixture, and within 0.0154 s on all 16 pairs in the samples. Both the unit
    suite and `integration_test/data_layer_test.dart` assert it, and the unit one could
    only do so because `tool/make_lap_fixture.py` gained `--prefix` and a second lap
    (`test/fixtures/sebring_lap3.dart`).
  - **The fixture pair has a real −0.167 s dip**, at 792 m: lap 2 gains 0.3 s into the
    first heavy braking zone and gives back 0.45 s through the corner — an over-driven
    entry, which is precisely what a delta trace exists to show. It looked like an artefact
    at first, and was confirmed against the full 10 Hz recording before being believed.
  - **The reference is a standing choice**, per session, not per lap: stepping through laps
    keeps comparing against the same one, and stepping *onto* it drops the comparison
    rather than drawing a lap against itself — a flat zero delta is a result-shaped picture
    of nothing. Stepping off brings it back.
  - **`lapChartProvider` is no longer kept alive.** The reference is part of its family
    key, and a kept-alive family keyed on lap × reference grows with every pair a user ever
    looks at. It is a pass over a few thousand points; the lap reads beneath it, which are
    the expensive half, stay cached per lap.
  ~~Fuel/stint view~~ — done in v0.10: fuel and virtual energy per lap, what each lap
  costs on average, what is left and how many laps it lasts, which of the two runs out
  first, the Hypercar's state-of-charge window per lap, and the pit-lane visits (§8.7 has
  the definitions and the Race sample's numbers). Not yet: the in/out-lap deltas §8.7 also
  names, which want a session with a mid-race stop to be checked against — none of the
  samples has one. Total suite: **276 device-free tests** and **54 `integration_test`
  cases**. Four things came out of it:
  - **Per-lap aggregates are a read of their own now**, `lapStatsSql`, and it follows the
    decimation rule rather than the obvious query: lap starts become channel row numbers
    (one master-grid lookup per lap) and the channel is bucketed by row, instead of every
    sample being timestamped — 1.7M joined rows on a 24-hour file, avoided. Checked against
    the obvious version on the fixture: identical first, last, extremes and sample counts on
    every lap, and the integration suite now asserts the same numbers.
  - **A lap with no samples is absent, not zero** — the fixture's lap 5 opens 2.5 ms after
    the channels stop. Both `ASOF` joins in the read are the inner kind on purpose, the
    opposite of §9.2's `LEFT` rule, because here "no row" is the true answer.
  - **`fl_chart` is in use, and themed** (`widgets/fl_chart_theme/`, empty until now): a
    `PerLapBarChart` with the custom core's numeral face and grid, bars at most 24 px with
    4 px rounded tops, ticks only on round values — `fl_chart` otherwise labels the axis
    maximum, a number on no gridline that reads as data — and a dashed reference line for
    the average the headline states. The laps an average leaves out are drawn grey rather
    than dropped, for the lap table's reason: a missing column renumbers everything after
    it. The screen also carries every charted value as a table, so nothing is readable only
    by hovering.
  - **Fuel, energy and state of charge needed identity colours the wheel did not have
    room for** — §9.7.1 has the measurement and why small multiples make it safe.
  A partial comparison says which lap is responsible: a reference whose lap distance runs
  backwards can be overlaid on the time axis only — both laps start at their own line
  crossing, so a time shift suffices — and never has a delta; the screen says so rather
  than silently drawing less. The widget test for it also caught a real overflow: with a
  reference's readout column added, the track map's narrow trace strip had no room left
  for a panel title, which now ellipsises instead.
  ~~Events Log~~ — done. A filterable table over all 42 event tables, session-scoped, with
  the lap each change belongs to. Two things came out of measuring it first:
  - **42 separate reads beat one `UNION ALL`, on both speed and fidelity.** Measured on the
    Sebring Race sample: 42 reads return all 20,304 rows in **62 ms**, the union returns
    41,946 rows (per-corner tables expand four-fold) in **144 ms**. The union is also
    lossy — the tables are a mix of BOOLEAN, four unsigned integer widths, TINYINT and
    FLOAT, so the cast that makes them unionable is the one that turns `false` into `0`,
    and §8.12's whole purpose is showing what the file actually holds. `dart_duckdb`
    already returns `bool`/`int`/`double` natively per column, so reading table by table
    keeps them for free.
  - **The row cap is per event, not global.** A global budget spent in catalog order drops
    whole signals off the end of the alphabet while the busiest table at the front consumes
    it — a log missing entire events rather than the tail of a few, and missing without a
    clue as to which. Each table gets its own ceiling (10,000, above the 7,212-row worst
    case measured) and `EventLog.clipped` names the ones that hit it, which the screen
    renders rather than silently showing a prefix (§9.5's no-silent-caps rule).
  - Per-corner events (`SurfaceTypes`, `TyresCompound`, `WheelsDetached` — the same three
    in every sample) stay one row of four values, **unlabelled**: §15's open question on
    FL/FR/RL/RR ordering is still open, so a corner label here would state something the
    data has not settled.
  ~~Tires & brakes, the Session Library, lap-pace trend and incidents, race pace, the setup
  viewer, and app-wide motion and keyboard work~~ — done in **v0.11**; each §8 section has
  its "Built in v0.11" paragraph. Total suite: **767 device-free tests** and **78
  `integration_test` cases** across nine files, every one passing, plus a profile-mode
  scrub benchmark that closed §15.3. Six things came out of it that reach beyond one
  feature:
  - **§15.5 is closed, and it did not need the asymmetric setup §5.3 asked for.** The wheel
    order is FL, FR, RL, RR by three independent measurements — wheel-speed kinematics
    (a 1.68 m track width that changes sign with circuit direction), tyre heat and wear
    against circuit direction, and roll — and the setup could never have been the answer
    key, since every sample carries `"symmetric": true`. The kinematic test is also the one
    that checked §8.5.1's frame is not mirrored, against Interlagos running anti-clockwise.
  - **Two channels are exported under each other's names** — `G Force Lat` is longitudinal,
    `G Force Long` lateral (§5.4) — and four per-corner channels carry the wrong unit or
    meaning. None of it was visible in the catalog; all of it was visible the moment a
    channel was checked against another one it has to agree with. The rule §5's v0.7 note
    wrote down keeps paying: a column holding plausible numbers is not a column whose
    meaning is known.
  - **Two setup fields mean something other than their names** (§8.10): `value` is a step
    index, and `lastSavedStringValue` is the lowest step, not the saved setup — a "changed
    since saved" marker built on it would have flagged nearly every setting.
    `LastImpactMagnitude` is a boolean whose *rows* are impacts (§8.3), and `Time Behind
    Next` is a signed offset whose large steps are changes of car ahead (§8.9). Each was
    settled by a second channel the file already carried — `Brake Bias Rear`, `Ground
    Speed`, the lap durations.
  - **Per-lap aggregates take several columns in one scan now.** A per-corner channel was
    four reads; one four-column `lapStatsSql` returns the same values lap for lap, 3.4–4.6×
    faster (49 ms against 225 ms on the 100 Hz `TyresTempLeft`).
  - **The same `ValueRange` tick bug surfaced twice.** Its steps include 2.5 × 10ⁿ, and a
    formatter that picks decimals from the step's size alone prints −7.5 as "−8" — found by
    the race-pace golden, fixed in both formatters that had it. And on the trace panels the
    top tick's label, flipped below its line, ran through the next one; labels are now laid
    out bottom-up and the flipped one gives way (§9.5).
  - **Six agents building in parallel met at one file.** `PerLapBarChart` gained `signed`,
    `maxValue`, per-lap marks, selection and hover, and an entrance animation from three
    features at once, all optional and off by default. The fuel view — its first user — is
    pixel-identical; one race-pace bar changed, legitimately, when lap-pace's rule that a
    zero is drawn as a 4 px cap rather than as nothing reached it.
  Also new as tooling: `integration_test/screen_tour_test.dart` renders every destination
  of the real app against a real recording to PNGs — the compiled counterpart of the
  goldens, and as part of CI's integration loop a smoke test that no screen throws.
- **Phase 3:** N-way driver/stint comparison (§8.8), export (image/CSV), cross-session
  personal-best tracking, ~~Driving Technique Analysis (§8.13)~~. §8.13 was specified on
  2026-10-13 from measurements on the user's library and built the same day, on Compare's
  segment table (§8.13.5). What came out of building it:
  - **The pinned values held exactly.** The fixture's laps 1–3 reproduce §8.13.9's table to
    the last digit. The 50 Hz sample count is 50 × `Lap Time` within one sample.
  - **Timings on Imola's 127-lap GT3 race**: pedals 0.88 s, pedal runs 0.77 s, G 0.21 s,
    upshifts 0.18 s, countersteer 0.16 s, 10 Hz profiles 0.9 s. The upshift query first
    joined RPM rows by a time range and took 4.4 s. An equi-join on row offsets generated
    by `range()` took it to 0.18 s with the same values.
  - **TC and ABS time is the raw flag's time; the episode count is merged.** Merging decides
    what counts as one intervention, never how long the aid was active.
  - **Limiter dwell needed rewording.** On Sebring's GT3 race most upshifts never come
    within 100 rpm of the limiter, so a median over all of them is 0.000 s and says nothing.
    The panel counts the shifts that reached it and gives their median.
  - **The wet Daytona race in §8.13.6 is not every wet Daytona race.** Four Hypercar races on
    5 August went wet. In 00:19 the line reached 12.5–40 % only for laps 4–16, and the lens
    measures +3.95 s a lap, 0.6–1.0 s a segment. 02:39 loses 2.0–2.3 s a segment, inside
    §8.13.6's ranges. There, the infield's Segs 2–4 lose 14.5–20.4 % of their dry time and
    the banking and back straight 7.3–8.6 %. The integration test pins 02:39.
  - **A known gap, shared with Compare**: a lap whose first 10 Hz sample still reads the
    previous lap's `Lap Dist` fails the monotonic check and is not a clean lap for
    detection. It is still measured.
  - **Seen on the screen tour, not fixed**: on a race with pit laps, `PerLapTrendChart`'s lap
    labels collide where missing laps leave adjacent slots ("18 21" on Daytona). It is the
    shared chart's labelling, not Technique's.
  - **Not done yet**, because they need macOS:
    - §8.13.8's per-card goldens (goldens are not generated on Windows);
    - the profile-mode frame count for the lap morph on Imola's 127-lap race.
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
   since browser tabs have materially less addressable memory than a desktop process. The
   *wiring* is now verified (v0.8, `web/README.md`), which narrows this to the one thing it
   was always about: the size of the buffer, not whether the path works.
2. **Chart/decimation performance beyond one lap** — the query side was answered in v0.7
   (**~4 ms** for a real 22-minute session at 1200 buckets, **~42 ms** at 6 h / 2.14M rows,
   **~156 ms** at 24 h / 8.7M rows, **~24 ms** for a zoomed 60-second window of that 24-hour
   table), and the render side in v0.8 — but only at *single-lap* scope, where a one-shot
   fetch at one bucket per master-grid sample makes zoom free and no re-query loop exists to
   test (§9.5). What is still open is the case that loop exists for: a viewport spanning a
   whole stint, where the fetch has to follow the viewport and a debounce/stale-result
   policy has to be right. Two of v0.7's caveats also still stand — the query numbers are
   DuckDB's own and exclude Dart result marshalling, and nothing has yet rendered a
   *session*-sized dataset.
3. ~~**Frame cost while scrubbing has not been profiled.**~~ — **closed in v0.11, with room
   to spare.** `integration_test/scrub_perf_test.dart`, run in profile mode through
   `flutter drive` (`test_driver/perf_driver.dart`), sweeps a mouse at ~125 Hz across the
   six-panel stack of the full Sebring Race sample, coloured track map beside it, while the
   engine reports every frame: **1,234 frames, build 0.89 ms average / 1.49 ms p99, raster
   3.42 ms / 3.82 ms p99, worst 4.8 and 11.4 ms — zero frames over the 16.7 ms budget** on
   the development Mac. So the layer split (§9.5) does what it was designed to do, and a
   seventh panel (the delta) or a Phase 3 overlay has a budget left to spend. Two caveats
   stand: one machine, and one lap's worth of points — a session-scoped viewport (open item
   2) is still unmeasured, because it does not exist yet. The first version of the benchmark
   hovered over the panels' title rows, where a pointer sets no cursor, and timed six idle
   panels; it now aims at a plot's own hover region and asserts a cursor was set, which is
   the only thing that makes the numbers mean scrubbing.
4. **Flag/enum decoding** — `Sector1/2/3 Flag`, `Finish Status`, `SurfaceTypes` store
   integer codes with no confirmed meaning (§5.4). Needed before flag/incident annotations
   (§8.3) can be built.
5. ~~**FL/FR/RL/RR left/right order**~~ — **resolved in v0.11** (§5.3): FL, FR, RL, RR, by
   wheel-speed kinematics, by tyre heat and wear against circuit direction, and by roll —
   three methods, no asymmetric setup needed. Numbering kept so references elsewhere stay
   valid.
6. ~~**`CarName` structure**~~ — **resolved 2026-10-14** (§5.1). The grammar is
   `<team> [<season>] [#<number>][:<tag>]`. The model is never in it, so
   `lib/data/reference/car_catalog.dart` places each entry by four rules, the first that
   leaves exactly one model in the file's class winning:
   1. a custom livery's code (`VLMDH Custom Team` is the Cadillac V-Series.R);
   2. the team, by class, season and pack (Iron Dames: Huracán GT3 Evo2 to 2024, 911 GT3 R
      from 2025; Proton Competition: Mustang GT3, but 911 GT3 R in the 2026 ELMS, 963 in
      Hypercar, Oreca in LMP2);
   3. a make named in the entry (BMW M Team WRT in Hypercar is the M Hybrid V8);
   4. a class with one car (every LMP2 is an Oreca 07).

   Two or more models left means unplaced, never a guess, and an unplaced car shows its
   entry. The evidence is the game's own logs: each garage load writes `Requested Setup …
   for Vehicle <CarName> & Track … Found setup: <PREFIX>_….svm`, and the prefix
   (`GT3_992GT3R`, `HY_Cadillac`) names the model. On 2026-10-14 the catalog agrees with
   all 529 garage loads in the user's 37 trace logs (306 distinct entries, AI cars
   included), places all 54 entries in the library, and claims all 36 `Installed\Vehicles`
   folders. `tool/catalog_check.dart <LMU folder>` repeats both checks when a DLC lands.

   Model, not entry, is what "the same car" means. Compare's "≠ car" chip, its setup
   comparison and its suggestions treat AF Corse #83 and Ferrari AF Corse #50 (both
   499Ps) as one car. An LMP2 and an LMP2 ELMS Oreca still differ, on the class chip.
7. **Schema stability across untested combinations** — confirmed identical across these 3
   samples (different tracks, GT3 and Hypercar), but not verified for every class (e.g.
   LMP2) or a multiplayer/league context. **Partly answered 2026-10-13** (§8.13.1). On the
   user's 678 recordings (GT3, Hypercar, LMP2_ELMS, LMP3, 16 tracks), the G swap, the
   pedal and gear semantics, and the master-row mapping hold on every class. But one thing
   changed over time rather than by class: `Steering Pos` switched from a −1…+1 fraction
   to a percentage in April 2026, and `metadata.Version` stayed "1" across the change. So
   "same Version" does not mean "same units". A per-file range check is the only guard,
   and §8.13.1 specifies it. Multiplayer and league files remain untested.

   **Another driver, and a second change of build (2026-10-13).** Two recordings by
   another driver (Joao Chiozini, Alpine #35 at Le Mans: a race and a practice) are the
   first files in hand that the user did not record.
   - **The catalog moved.** `TC` and `SurfaceTypes` are channels in his files, and events
     in all 707 of the user's, including the user's own race started 38 s earlier that
     night (§5.1). So it is a different build at the same time, perhaps a beta branch,
     not only a newer one. `Version` is "1" in both.
   - **What the move broke:** §8.13's TC measures read nothing from such a file, without
     an error. They now read `TC` as either kind (§8.13.1). Nothing else in the app reads
     either table by kind.
   - **What held on his build:**
     - the G swap (steering correlates −0.72 with `G Force Long`, −0.02 with `G Force Lat`);
     - steering as a percentage, with `Steering Pos` equal to Unfiltered;
     - `Gear`'s neutral row at 37.5 ms (895 of 929 shifts);
     - no recording gaps.
   - **Compare's gates hold for a cross-driver pair** (comparison proposal, probe 0l, in
     part). His wrap length L is 13,623.97 m, equal to the user's to the centimetre, and
     his S1 and S2 stations sit within 0.3 m of the user's (1,896.25 / 7,724.88 m against
     1,896.22–1,896.44 / 7,724.79–7,725.07 m).
   - **`DriverName` is not a stable key for a person.** His race reads "Chiozini Joao" and
     his practice "Joao Chiozini". `SteamID` is "0" in both, as in every file seen.
     `RecordingIdentity` is unaffected, but anything that groups by driver would split him
     in two.
   - The pace and condition findings from his files are in `docs/PACE-FACTORS.md`.
8. **Hybrid chart boundary drift** — a chart built standalone in `fl_chart` may later need
   to join the synced cursor/viewport system (§9.5); watch for this during feature scoping
   so it's a planned migration, not a late-discovered rewrite.
9. **Corner/segment numbering** — both reference apps (§7) show numbered corners and
   finer-than-sector segment navigation, but nothing in the confirmed schema (§5) carries
   corner definitions. Needs a decision between a bundled per-track reference (accurate,
   matches "official" numbering, needs manual upkeep as LMU adds tracks) and geometric
   auto-detection from position/steering data (no external dependency, degrades gracefully
   to new tracks, not guaranteed to match official numbering) before building §8.5's
   segment navigation.
10. **Any ToS/legal consideration** reading LMU's telemetry export format — existing
   community tools suggest it's fine, but worth the user's own confirmation.
11. **CI wiring for `integration_test`** — wired in v0.10 (§13). The first CI run (12cdd83,
    2026-09-30) answered most of it: **ubuntu-latest passed all nine files**, so the native
    library links there; windows-latest passed the seven before `session_library_test.dart`,
    failed two of its four cases, and stopped (the loop runs under `bash -e`). Both failures
    were Windows-only and reproduced locally: a test path spelled with `/` against a folder
    listing Windows joins with `\`, and closing a session reopening its file in the same
    frame (§8.1) — a real defect that macOS's unlink-while-open had hidden. With both fixed,
    all nine files pass on Windows locally (Flutter 3.47.1). What is left is one green
    windows-latest run, then dropping `continue-on-error` from both legs.
12. **Recording discontinuities: how common mid-session?** — §5.2 measured one ~0.38 s gap
    in 2 of 3 samples, both landing *after* the last lap (recordings being stopped). Whether
    a long stint puts gaps mid-session — garage returns, ESC, a frame-time stall — decides
    whether the master-clock mapping is merely correct-by-construction or actively
    load-bearing. Answerable with the first real endurance file, and cheap to instrument now:
    count gaps at import time and surface them on the Session Overview (§8.2).
13. **Why do `Engine Oil Temp`/`Engine Water Temp` declare 7 Hz but sample at ~7.0171 Hz?**
    — measured identically in all three samples (§5.2), so it's systematic, not jitter. The
    mapped derivation makes it harmless, but the cause is unknown, and an unexplained
    systematic error is worth a second look in case it signals something about how LMU
    writes sub-100 Hz channels generally. Low priority, low cost.
14. **`dart_duckdb` has no Swift Package Manager support** (v0.10). Flutter builds macOS
    plugins through SwiftPM now and falls back to CocoaPods for the ones that lack it,
    printing on every build that this "will become an error in a future version of
    Flutter". `dart_duckdb` is the only plugin here in that position, and it is also the one
    the app cannot work without. Worth watching on each Flutter release note, and worth
    raising upstream before it becomes an error rather than after — it is the most likely
    thing to stop this project tracking the newest stable.
15. ~~**`Regen Rate`'s unit is wrong somewhere**~~ — **closed 2026-10-13: watts**, positive
    harvesting, negative deploying (§5.4). The catalog's kW is wrong. Checked against the
    known figures the v0.10 text asked for: the harvest peak is 0.97 × the setup's
    `VM_REGEN_LEVEL` on ten Hypercars, and the deploy peak is the class limit (LMDh 52 kW,
    LMH 196 kW). Numbering kept.
16. **What exactly is `Steering Pos` a percentage of?** (2026-10-13; partly answered.)
    In 603 of 613 scanned files `Steering Pos` and `Steering Pos Unfiltered` are identical.
    In the other ten, `Steering Pos` is a constant multiple of Unfiltered, and the multiple
    follows the setup's steering lock (§8.13.1):
    - six LMP2 files at 240° (9.3°) scale by 0.714976, where every other LMP2 file runs
      336° (13°) and is identical;
    - four Porsche GT3 files at 540° (18.8°) scale by 0.924372 (r = 1, max residual 10⁻⁵).

    The fit is Unfiltered = the wheel as a percentage of its set rotation, and `Steering
    Pos` = the front-wheel angle as a percentage of a per-car reference. That reference is
    13° for the LMP2 and 20.34° implied for the Porsche. What the reference is (the car's
    maximum lock?) is not established. It would matter only to a view that converts steering
    to degrees.
17. **What are the Hypercar throttle cuts with no cause in the file?** (2026-10-13; mostly
    answered.) Within ±0.1 s of TC and ±0.3 s of a shift, 8–21 % of Hypercar cuts looked
    uncaused. The user's suggested causes were tested on six sessions (§8.13.1):
    - Widening to ±0.5 s puts 5–14 % next to TC and 6–17 % next to a gear change.
    - Low pedal (< 20 %, a throttle map, inferred) takes 1–13 %.
    - Pit-lane time carried into a lap was the largest single episode.
    - No recording gap lies within 1 s of any cut, and no pedal dropout was seen, so
      connection losses and disconnected equipment are not supported by this data.

    The remaining 0.3–4.9 % are trims of 1–4 points with no visible cause, perhaps hybrid
    deployment (inferred). They affect the "throttle to engine" reading only; every §8.13
    pedal measure reads the pedal.
18. **No yaw rate.** (2026-10-13) The export has no yaw or body-slip channel, and
    `Wheel Speed` shows no slip (§5.4). §8.13's countersteer episodes therefore find only
    slides the driver corrected. They are validated on one known spin and on lap-time cost
    (§8.13.3). Uncorrected oversteer and understeer are invisible. GPS heading gives the
    path's direction, not the car's, so it is not a substitute. A yaw channel in a future
    export would be the first thing to look for.
19. **Why does the pedal stop reaching 100 late in long races?** (2026-10-13) On Imola's
    127-lap GT3 race, flat-out time spent at 99–<100 grows from 2 % to 50–60 % after lap
    100. On COTA's Hypercar race it reads exactly 100 for 31.5 % of racing time and ≥ 99
    for 45.7 %. Pedal hardware drift and a game-side clamp would look the same here. §8.13
    sidesteps it with a ≥ 98 % threshold. It would matter to any view that tests for
    exactly 100.
20. **What are the `TyresCompound` indices?** (2026-10-13; **mostly answered** the same
    day.) The event stores 0–3 per wheel with no names. The names are in the setup after
    all:
    - `WM_COMPOUND-W_FL/FR/RL/RR`'s `stringValue` names the compound in force at recording
      start: "Soft", "Medium", "Hard" or "Wet". A used set is prefixed with its remaining
      tread ("70% Medium"), and front and rear can differ (12 files).
    - The index is a **position in the session's list of compounds**, not a code with a
      fixed meaning. The Alpine's Medium is 1 at Le Mans and Spa, where Soft is 0, and 0 at
      Laguna Seca, which had no Soft. The BMW at Interlagos lists Medium 0, Hard 1, Wet 2.
    - Within one car and track, the setup's name and the starting index agree in 664 of
      700 recordings. Most of the rest are one race weekend with a different list
      (Cadillac at Le Mans, 26 February: Medium 0), or untimed files where the garage
      changed tyres after the setup was written.

    This corrects two earlier inferences:
    - "index 3 is the wet tyre" holds at Daytona only;
    - Interlagos's 0 → 2, "consistent with a harder tyre", was used Mediums to **Wets** on a
      line whose wetness stayed 0 (§8.13.6).

    **Answered for most cars (2026-10-14),** from a survey of the 444 recordings then in
    the folder:
    - The game keeps **one order**, Soft, Medium, Hard, Wet, and leaves out what the
      session does not offer. In 425 files the setup's compound sits at exactly the index
      that order gives it, with or without Soft. The rest are the Cadillac's Le Mans and
      Spa weekends of February–May, whose four-compound list starts on Medium, and races
      where the garage changed tyres after the setup was written (a Daytona storm race
      whose setup says Soft and whose event starts on 3, the Wet).
    - `WM_COMPOUND-W_*`'s `maxValue` is **twice the number of compounds**: 8 with all four
      (every Hypercar list with Soft), 6 with three (Medium, Hard, Wet), and 4 for every
      GT3, LMP2 and LMP3 file (two). Its `value` is the garage's tyre-set option, new
      and used sets, not the event's index.
    - So the index is named wherever the order, the starting name and the count leave one
      compound for it: every index of a four-compound list, every index of Medium, Hard,
      Wet. The setup's starting name is dropped where the order rules it out (a Soft is
      never 3), and the count where it contradicts the name (the Cadillac weekend).
      Pace Reader's `CompoundKey` reads all 444 files this way.
    - **`VM_FRONT_TIRE_COMPOUND` / `VM_REAR_TIRE_COMPOUND` are not the fitted compound.**
      Their `value` is 0 and `maxValue` 1 in every file, and the `stringValue` is the
      session's first compound: Soft in all 268 eight-option files, Medium in all others.
      They differ from the wheels in 203 of 440 files, so the Setup Viewer's compound tile
      reads the wheels, and the axle rows carry a caption saying what they are.
    - **Each wheel can carry its own compound.** The game's pit presets split the car by
      axle and by side, and its UI marks any set that is not one compound all round with
      four dots in the wheels' places, each in its compound's colour, in place of its tyre
      icon (`TyreMixedCompoundIndicator` in `Bin\UI.zip`). Pace Reader marks a mixed set
      the same way, and the Setup Viewer's tile reads all four wheels, so a left/right
      split reads as one.

    Still open: a two-compound car's second compound (the GT3s, LMP2s and LMP3s offer
    two, and no recording changes onto it), which the order leaves as Hard or Wet.
21. **Where are the temperature limits?** (2026-10-13) §8.10.1's tape guide can predict
    water and brake temperatures from air temperature and tape, but needs a target.
    `OverheatingState` never turned on in 708 recordings (hottest water 102.7 °C), so the
    data does not show where the engine starts to suffer. Brake and tyre windows are not in
    the file either. Options: a per-class reference table, or a user-set target, labelled
    as the user's.

## 16. Next Steps

1. ~~User shares sample `.duckdb` file(s)~~ — done: 3 samples (Practice/Qualify/Race)
   inspected directly with DuckDB; §5 and §8 updated from assumption to confirmed fact.
2. ~~Reference-app screenshots~~ — done: GO FAST and MyLMU reviewed directly (§7); §8
   expanded with 3 new features (Events Log, Driving Technique Analysis, Car Behavior
   Analysis) and §8.5/§8.8 refined with concrete UI patterns (N-way comparison, segment
   navigation, solid/dotted overlay convention).
3. Resolve the still-open items in §15 that are cheap to close now (flag/enum decoding,
   FL/FR/RL/RR order, corner/segment numbering approach) before they block feature work.
4. ~~Scaffold the Flutter project (Phase 0) and spike DuckDB access + chart rendering
   against the real samples~~ — done through Phase 1 (§14). Still outstanding from this
   item: a large/synthetic file for the web memory question (§15.1), since all 3 samples on
   hand are short sessions.
5. ~~Wire CI (§15.11) before Phase 2 rather than after~~ — written in v0.10 (§13), and it
   becomes real on the first push. Read that first run: the Linux and Windows integration
   legs have never executed anywhere.
6. ~~Profile a scrub (§15.3)~~ — done in v0.11: zero frames over budget in profile mode.
7. Record the files that would settle what v0.11 could not: a race with a pit stop (§8.7's
   in/out-lap deltas, `Time Behind Next` in the pit lane), a session with a yellow flag or a
   lost wheel (§8.3's annotations run on constructed series only), a Hypercar race, and
   one long stint for §15.1/§15.2/§15.12.
