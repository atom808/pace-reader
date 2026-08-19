# `core/` — cross-cutting utilities (SPEC.md §9.1)

Empty on purpose. Error types, logging, and constants shared across features land here.
Anything that knows about DuckDB belongs in `data/` instead; anything that knows about a
specific feature belongs in that feature.
