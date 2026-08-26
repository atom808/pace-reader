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
  axis) and `StepPlot` (an event held between changes).
- `projection.dart` — `TrackProjection`, the §8.5 local equirectangular projection, and
  `TrackFit`, the uniform metres→pixels fit.
- `track_path.dart` — `TrackPath`, the map's payload: projected points plus, per point, the
  colouring value and the domain position that ties it to the panels' cursor.
- `value_ramp.dart` — the single-hue sequential ramp magnitude is encoded with. Identity
  colours live in the design system; how a *quantity* becomes colour lives here.
- `painters/` — `TracePainter`/`StepTracePainter`, `CursorPainter`/`DomainMarkerPainter`,
  `TrackMapPainter`/`TrackScalePainter`, and the shared `ChartPalette`/`ChartGeometry`.
- `sync/chart_sync.dart` — the Riverpod cursor/viewport/axis controller every synced chart
  subscribes to.
- `trace_panel.dart`, `track_map_view.dart` — the widgets features compose.

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
