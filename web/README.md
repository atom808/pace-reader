# Web target

The web build needs one setup step the desktop builds don't:

```bash
python3 tool/fetch_web_deps.py
```

Then `flutter run -d chrome` / `flutter build web` as usual. Desktop builds need none of it.

## What the step does, and why it exists

`dart_duckdb`'s web path is DuckDB-Wasm plus Apache Arrow, loaded by the *page* rather than
by Dart: the package expects two globals — `duckdbduckdbWasm` and `duckdbduckdbWasmReady` —
to exist before Flutter starts. Its documented setup imports both from jsDelivr, which puts
SPEC.md §10's offline-first requirement at the mercy of a CDN and makes a first run on a
disconnected machine a blank page.

`tool/fetch_web_deps.py` fetches the same pinned assets into `web/duckdb/` so the shipped
page loads them from its own origin. That directory is git-ignored: the two WebAssembly
builds are ~70 MB together and are exactly reproducible from the versions pinned in the
script, which is a poor trade for a git object.

`web/index.html` wires them up. Two things there are worth knowing before changing it.

**Bundle selection can't be fixed by copying files.** `dart_duckdb` calls
`getJsDelivrBundles()`, whose URLs are CDN URLs by construction. The module is therefore
wrapped in an object of the same shape with that one function replaced. Everything else —
including `selectBundle`, which feature-detects the browser and chooses between the `mvp`,
`eh` and `coi` builds — is upstream's implementation, unchanged, now choosing between local
files. On a page served without COOP/COEP headers (which is what `flutter run` and plain
static hosting do) it picks `eh`; `coi` is only reachable cross-origin isolated, and
`--with-coi` fetches it for that case.

**The ready promise has to resolve with a value.** `dart_duckdb` types the global as
`JSPromise<JSAny>?` — non-nullable inside — and awaits it. A promise settling with
`undefined` throws `type 'Null' is not a subtype of type 'Object'` out of an unawaited
future during plugin registration: an uncaught rejection at startup and a DuckDB that never
finishes initialising. Upstream's own template resolves with `undefined` and gets away with
it only because it publishes the promise under `duckdbWasmReady`, a name the bindings never
read — so their await is a silent no-op. Ours is not, and it resolves with `true`.

## Verified

Against `flutter run -d web-server` on Chrome, with the vendored assets in place: every
request stays on the app's own origin (no CDN), `selectBundle` picks `duckdb-eh.wasm`, the
engine instantiates in ~0.5 s and reports DuckDB v1.3.0, `registerFileBuffer` accepts a
buffer, and `ATTACH … (READ_ONLY)` rejects a non-DuckDB buffer with the same clear error the
desktop path produces (§9.2's "byte-identical SQL on both platforms").

Still unverified, and §15.1's open question: how the bytes path behaves with an
endurance-length file. Every sample on hand is a short session, and the web path holds the
whole file in browser memory before DuckDB can open it.
