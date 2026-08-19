# `data/` — shared telemetry data access (SPEC.md §9.1, §9.2)

Empty on purpose: this is Phase 1's first task, not existing code. Repositories are
**shared, not per-feature** (§9.1) because most features query the same session/lap/
telemetry tables, and duplicating query logic per feature would drift.

Planned layout per §9.1:

- `duckdb/` — connection lifecycle, catalog-driven schema discovery, SQL. Owns the
  time-axis derivation in §5.2/§9.2: map channel row `i` to master row
  `round(i * n_gpstime / rows)` and read that row's `GPS Time`, rather than trusting
  `origin + row_index / frequency`. Owns the desktop-path/web-bytes asymmetry too, so
  no feature ever branches on platform.
- `repositories/` — `SessionRepository`, `LapRepository`, `TelemetryRepository`.
- `models/` — `freezed` models: `Session`, `Lap`, `Stint`, `Driver`, `TelemetrySample`.

`integration_test/duckdb_spike_test.dart` already pins the invariants this layer has to
honour; start there.
