# `fl_chart_theme/` — themed wrapper for standalone charts (SPEC.md §9.5)

Empty on purpose. A thin theme wrapper so `fl_chart` output matches the custom chart core
rather than looking like a bolted-on library — colors, fonts, tooltips, animation timing
from the §9.7 tokens.

`fl_chart` is for charts that genuinely never join the synced cursor/viewport system: the
lap-time bar chart, fuel-per-lap trend, and §8.13/§8.14's per-lap aggregate charts (one
point per lap — no decimation, no cursor sync). The split is drawn by *behavior*, not by
"simple vs. complex". §15.7 names the expected migration: a standalone chart that later
grows a sync requirement graduates into `../charting/`.
