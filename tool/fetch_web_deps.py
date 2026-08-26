#!/usr/bin/env python3
"""Vendor the web target's DuckDB-Wasm and Arrow assets into `web/duckdb/`.

SPEC.md §10 requires the app to work with no network access, and §9.2's web
path is the one place that would otherwise break that: `dart_duckdb`'s own
setup loads DuckDB-Wasm and Apache Arrow from a CDN at page load, so a
first-run without connectivity gets a blank page rather than an app. This
script fetches the same pinned assets once, so the shipped page loads them
from its own origin.

Not checked in, and deliberately: the two WebAssembly builds are ~70 MB
together, which is a poor thing to carry in git for a file that is
reproducible from a pinned version. `web/duckdb/` is git-ignored and this is
how it gets populated — one command, before `flutter run -d chrome` or
`flutter build web`. Desktop builds need none of it.

Versions are pinned to the ones `dart_duckdb` documents and tests against
(see its README's `web_test.html` template). Arrow's dependencies are not
pinned here: they are resolved from the bundle that actually gets fetched, so
a version bump cannot leave a stale transitive pin behind.

Usage:
    python3 tool/fetch_web_deps.py            # mvp + eh bundles (~70 MB)
    python3 tool/fetch_web_deps.py --with-coi # adds the threaded bundle
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import urllib.request

CDN = "https://cdn.jsdelivr.net"

DUCKDB_VERSION = "1.29.1-dev222.0"
ARROW_VERSION = "17.0.0"

OUTPUT_DIR = os.path.join("web", "duckdb")

# `+esm` bundles import their dependencies as absolute CDN paths, so every one
# of them has to be fetched and rewritten to a sibling file or the page still
# reaches the network for a transitive dependency it never named.
ESM_IMPORT = re.compile(r'(from|import)\s*"(/npm/([^"]+)/\+esm)"')

# Per-bundle binaries. `selectBundle` picks between these at runtime by
# feature-detecting the browser; the page has to be able to serve whichever it
# lands on, which is why more than one is fetched.
BUNDLES = {
    "mvp": ["duckdb-mvp.wasm", "duckdb-browser-mvp.worker.js"],
    "eh": ["duckdb-eh.wasm", "duckdb-browser-eh.worker.js"],
    "coi": [
        "duckdb-coi.wasm",
        "duckdb-browser-coi.worker.js",
        "duckdb-browser-coi.pthread.worker.js",
    ],
}


def slug(spec: str) -> str:
    """`@duckdb/duckdb-wasm@1.29.1-dev222.0` -> `duckdb-wasm-1.29.1-dev222.0`."""
    return spec.lstrip("@").replace("/", "-").replace("@", "-") + ".mjs"


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read()


def fetch_esm(spec: str, seen: dict[str, str]) -> None:
    """Fetch one `+esm` bundle and everything it imports, rewriting as it goes."""
    if spec in seen:
        return
    name = slug(spec)
    seen[spec] = name

    body = fetch(f"{CDN}/npm/{spec}/+esm").decode("utf-8")
    dependencies = {m.group(3) for m in ESM_IMPORT.finditer(body)}
    for dependency in dependencies:
        fetch_esm(dependency, seen)

    rewritten = ESM_IMPORT.sub(
        lambda m: f'{m.group(1)}"./{slug(m.group(3))}"', body
    )
    path = os.path.join(OUTPUT_DIR, name)
    with open(path, "w") as out:
        out.write(rewritten)
    print(f"  {name:44} {len(rewritten) // 1024:>6} KB")


def fetch_binary(filename: str) -> None:
    path = os.path.join(OUTPUT_DIR, filename)
    if os.path.exists(path):
        print(f"  {filename:44} {'cached':>9}")
        return
    data = fetch(f"{CDN}/npm/@duckdb/duckdb-wasm@{DUCKDB_VERSION}/dist/{filename}")
    with open(path, "wb") as out:
        out.write(data)
    print(f"  {filename:44} {len(data) // 1024:>6} KB")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--with-coi",
        action="store_true",
        help="also fetch the cross-origin-isolated (threaded) bundle, which "
        "`selectBundle` only picks when the page is served with COOP/COEP "
        "headers",
    )
    args = parser.parse_args()

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print(f"ES modules -> {OUTPUT_DIR}/")
    seen: dict[str, str] = {}
    fetch_esm(f"@duckdb/duckdb-wasm@{DUCKDB_VERSION}", seen)
    fetch_esm(f"apache-arrow@{ARROW_VERSION}", seen)

    wanted = ["mvp", "eh"] + (["coi"] if args.with_coi else [])
    print(f"WebAssembly bundles ({', '.join(wanted)}) -> {OUTPUT_DIR}/")
    for bundle in wanted:
        for filename in BUNDLES[bundle]:
            fetch_binary(filename)

    # index.html imports these two by name, so a rename upstream has to fail
    # here rather than as a blank page in a browser.
    for spec, expected in (
        (f"@duckdb/duckdb-wasm@{DUCKDB_VERSION}",
         "duckdb-duckdb-wasm-1.29.1-dev222.0.mjs"),
        (f"apache-arrow@{ARROW_VERSION}", f"apache-arrow-{ARROW_VERSION}.mjs"),
    ):
        if seen[spec] != expected:
            sys.exit(
                f"module for {spec} landed at {seen[spec]}, but web/index.html "
                f"imports {expected} — update both together"
            )

    print("done — `flutter run -d chrome` will now load DuckDB from this origin")


if __name__ == "__main__":
    main()
