# `charting/` — custom chart core (SPEC.md §9.5)

Everything that participates in cross-chart interaction lives here — the trace panels, the
track map, the shared cursor and viewport — because they share one scrub cursor and one
axis across panels, which is exactly what a general-purpose chart library isn't built
around. Standalone charts that never join that synced system use `fl_chart` instead (see
`../fl_chart_theme/`).

Per §9.7.3, glass/`BackdropFilter` is never used on anything in here: these redraw every
frame while scrubbing.

## Layout

- `viewport.dart` — `ChartViewport` (pan/zoom/clamp) and `ValueRange` (extent, padding,
  round-number ticks). Plain Dart with no Flutter import, so the arithmetic every panel
  depends on is checkable in a plain `flutter test`.
- `decimation.dart` — query results → render-ready points. `DistanceAxis` (the §8.4
  Distance/Time remap, and its inverse), `TracePlot` (a decimated channel on the chosen
  axis) and `StepPlot` (an event held between changes). Both plots take a `timeShift`, which
  is how a reference lap lands on another lap's clock.
- `lap_delta.dart` — `LapDelta`, the time delta of one lap against a reference at equal lap
  distance, each lap timed from its own line crossing (§8.4 has the measurement behind that
  choice).
- `projection.dart` — `TrackProjection`, the §8.5 local equirectangular projection, and
  `TrackFit`, the uniform metres→pixels fit.
- `track_path.dart` — `TrackPath`, the map's payload: projected points plus, per point, the
  colouring value, the domain position that ties it to the panels' cursor, and `Lap Dist`.
  A second lap on the same map (Compare's Target) is built on the first's origin and time
  shift. `recoloured` gives the same points another colouring, so a change of Colour by
  never moves the camera or the hit test.
- `value_ramp.dart` — the single-hue sequential ramp magnitude is encoded with. Identity
  colours live in the design system; how a *quantity* becomes colour lives here.
- `painters/` — `TracePainter`/`StepTracePainter` (each with an optional dotted reference
  lap), `DeltaTracePainter` (filled toward zero, not the panel floor),
  `CursorPainter`/`DomainMarkerPainter`, `TrackMapPainter` (paths, casing, numbers, inset)
  under `TrackCursorPainter` (the cursor and the ghost, so a scrub repaints only them) and
  `TrackScalePainter`, and the shared `ChartPalette`/`ChartGeometry`/`dashedPolyline`.
- `sync/chart_sync.dart` — the Riverpod playhead/probe/viewport/axis controller every
  synced chart subscribes to. The **playhead** is set by a click, a key or playback and
  places the car; the **probe** follows the pointer and only reads.
- `lap_alignment.dart` — `LapAlignment`, where a reference lap is when Base is at a
  playhead: on Distance at the same point of the lap, on Time where it was at that moment.
- `map_stage/` — the map as a camera over the lap (map stage proposal):
  - `camera.dart` and `camera_rig.dart`: `MapCamera`, and the critically damped spring that
    moves it, with the speed zoom's low-pass.
  - `stage_contracts.dart`: the seams, `StageLayer` (one overlay) and `LineColouring` (what
    colour each stretch is). A new overlay or colouring is a new class, never an edit to
    `MapStage`.
  - `line_colouring.dart`: `PedalColouring` (the default) and `RampColouring`.
  - `stage_layers.dart`: the line, markers, cars, probe and scale bar, all culled to the
    view.
  - `path_kinematics.dart`: speed and heading along the path.
  - `path_hit_test.dart`: the grid behind hover and click on the line.
  - `map_stage.dart`: the widget, with its pen-stroke entrance.
  - `transport_bar.dart`: `PlaybackDriver` (the ticker behind ▶) and `TransportBar`.
  - `dock_tabs.dart`: the dock's tab bar, each tab named where the names fit.
  - `corner_grid.dart`: `CornerGrid`, the four corners laid out like the car, for every
    per-corner tab.
- `playback.dart` — `playbackProvider`, and the pure steps playback is made of:
  `advancePlayhead` (in lap time, on either axis) and `keepUpWindow`.
- `trace_tab.dart` — `TraceTab` and `ChannelGuard`: a dock tab as data, shown when the lap
  carries what it needs.
- `trace_panel.dart`, `map_stage/map_stage.dart`, `track_map_view.dart` — the widgets
  features compose. `TrackMapView` remains only for Compare until it moves to the stage.

## Two decisions worth not re-litigating

**The extent is not stored in the sync controller.** A viewport needs bounds to clamp
against, and those come from the loaded lap — data. Storing them in the controller would
mean writing to it during a widget build every time data resolved, which is how a Riverpod
graph starts looping. Every operation takes the bounds as an argument instead, and a null
viewport means "the whole lap".

**The cursor and the trace are separate paint layers.** The trace costs thousands of points
and changes only when the data or the viewport does; the cursor changes on every pointer
move. Keeping them apart, behind a `RepaintBoundary`, is what stops a scrub from redrawing
the trace at pointer rate — and why `lapChartProvider` watches
`chartSyncProvider.select((s) => s.axis)` rather than the whole state, so the plot objects
stay identical across a cursor move and the painters' identity checks actually hit.

## Where the query/render split falls

The heavy reduction happens in SQL (`data/duckdb/channel_queries.dart` min/max-buckets
inside DuckDB), so this layer never sees a full-resolution multi-hour trace. What it adds is
the part SQL can't do: remapping onto lap distance, and packing results into typed arrays a
`CustomPainter` walks each frame.

A single lap is fetched once, at one bucket per master-grid sample, so zooming inside it has
nothing finer left to fetch — see `TraceWindow.forLap` for the arithmetic. That stops being
true at session scope, which is where §9.5's re-query-per-viewport path becomes load-bearing;
the repository already takes the window and bucket count it needs.
