# `fl_chart_theme/` — themed standalone charts (SPEC.md §9.5)

`fl_chart` is for charts that genuinely never join the synced cursor/viewport system: the
lap-time bar chart, fuel-per-lap trend, and §8.13/§8.14's per-lap aggregate charts (one
point per lap — no decimation, no cursor sync). The split is drawn by *behavior*, not by
"simple vs. complex". §15.8 names the expected migration: a standalone chart that later
grows a sync requirement graduates into `../charting/`.

What lives here is the part that keeps `fl_chart` output from looking bolted on — the
chart core's numeral face and grid, the design system's surfaces and motion — plus the
mark rules a standalone chart is easiest to get wrong.

- `per_lap_bar_chart.dart` — `PerLapBarChart`, one column per lap on one value axis. Bars
  at most 24 px with 4 px rounded tops and square feet, ticks only on round values (never
  `fl_chart`'s own label at the axis maximum), text in ink rather than the series colour,
  an optional dashed reference line, and laps left out of a headline figure drawn grey
  rather than dropped. `from` turns a bar into a range, for a state-of-charge window.
  First used by the fuel/energy view (§8.7). `maxValue` lets four small multiples share
  one scale.
- `per_lap_trend_chart.dart` — `PerLapTrendChart`, for a per-lap quantity that is *not*
  anchored at zero (pressure, temperatures), where bars from zero would be identical stubs
  and bars from a floor would lie about size. The lap's mean is a dot on a line, its
  lowest-to-highest reading a faint band; laps left out are a grey dot and whisker, off
  the line. Same 48 px value axis, round-value ticks, ink-coloured text and lap labelling
  as the bar chart, so a stacked pair agrees; `minY`/`maxY` take a shared scale. First used
  by the tyres & brakes view (§8.6).

`fl_chart` 1.2.0 still imports `package:flutter/material.dart` rather than `material_ui`,
which is harmless only because everything it would take from a theme is passed in
explicitly — keep it that way (README.md, "Toolchain").
