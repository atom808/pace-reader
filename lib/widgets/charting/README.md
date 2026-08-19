# `charting/` — custom chart core (SPEC.md §9.5)

Empty on purpose: scaffolded as the home for the chart core, not yet implemented. §15.2's
decimation/viewport spike is Phase 1 work and starts here.

Everything that participates in cross-chart interaction lives in this module — trace
charts, the track map, multi-lap overlay, the distance/time axis toggle — because they
share one scrub cursor and one viewport across panels, which is exactly what a
general-purpose chart library isn't built around. Standalone charts that never join that
synced system use `fl_chart` instead (see `../fl_chart_theme/`).

Planned layout per §9.5:

- `viewport.dart` — pan/zoom/transform math, shared by every chart and the track map.
- `decimation.dart` — DuckDB result at the current viewport → render-ready points.
  Non-negotiable per §9.5: a 6-hour stint puts one 100 Hz channel near 2.16M rows and
  there are **20** channels at 100 Hz, so no renderer is ever handed a full-resolution
  multi-hour trace.
- `painters/` — line-trace painter, track-map painter, shared cursor/overlay painter.
- `sync/` — the Riverpod cursor/viewport controller every synced chart subscribes to.

Per §9.7.3, glass/`BackdropFilter` is never used on anything in here: these redraw every
frame while scrubbing.
