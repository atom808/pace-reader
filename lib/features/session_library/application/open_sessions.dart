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
  /// off this list alone would leave the file open until the app quits. It
  /// is released through the provider's own `close()`, never by invalidating
  /// it: something is always still watching a session at the moment it is
  /// closed, and an invalidated provider with a listener is rebuilt — which
  /// reopened the file in the same frame (see `TelemetrySessionHandle.close`).
  /// The derived per-session providers then serve the closed state until the
  /// file is opened again, and are recomputed on that next read.
  Future<void> close(TelemetrySource source) async {
    state = state.where((s) => s != source).toList();
    final session = telemetrySessionProvider(source);
    // Asking for the notifier of a session nobody built would open the file
    // just to close it.
    if (ref.exists(session)) await ref.read(session.notifier).close();
  }
}

/// The session the feature screens are looking at, or null when none is open.
@Riverpod(keepAlive: true)
TelemetrySource? currentSession(Ref ref) {
  final open = ref.watch(openSessionsProvider);
  return open.isEmpty ? null : open.first;
}
