/// Which telemetry files are currently open (SPEC.md §8.1).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/providers.dart';

part 'open_sessions.g.dart';

/// The sources the user has opened this run, most recent first.
///
/// Held in app state rather than encoded in the route, because a route
/// parameter cannot express both platforms: on web a session is a byte buffer
/// in memory with no path to put in a URL (§9.2). Keeping the identity here
/// means the same navigation works on desktop and web instead of one target
/// carrying file paths through the address bar.
///
/// This is *not* the Session Library's persistent index — that is
/// `SessionLibrary`, in drift (§9.6). This list is per-run: what is open now.
@Riverpod(keepAlive: true)
class OpenSessions extends _$OpenSessions {
  @override
  List<TelemetrySource> build() => const [];

  /// Adds a source and makes it current, moving it to the front if it's
  /// already open rather than opening a second handle to the same file.
  void open(TelemetrySource source) {
    state = [source, ...state.where((s) => s != source)];
  }

  /// Removes a source from the open list and releases its DuckDB
  /// connection.
  ///
  /// The connection is held by `telemetrySessionProvider`, which is kept
  /// alive on purpose (the family key is the open file), so taking a session
  /// off this list alone would leave the file open until the app quits.
  /// Invalidating it runs its `onDispose` — the connection closes — and,
  /// because Riverpod 3 does not rebuild a provider nothing is listening to,
  /// nothing reopens it unless the file is opened again. The derived
  /// per-session providers keep their now-stale values until then, and are
  /// recomputed on that next read rather than served.
  void close(TelemetrySource source) {
    state = state.where((s) => s != source).toList();
    ref.invalidate(telemetrySessionProvider(source));
  }
}

/// The session the feature screens are looking at, or null when none is open.
@Riverpod(keepAlive: true)
TelemetrySource? currentSession(Ref ref) {
  final open = ref.watch(openSessionsProvider);
  return open.isEmpty ? null : open.first;
}
