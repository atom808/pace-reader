/// Which telemetry files are currently open (SPEC.md §8.1).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';

part 'open_sessions.g.dart';

/// The sources the user has opened this run, most recent first.
///
/// Held in app state rather than encoded in the route, because a route
/// parameter cannot express both platforms: on web a session is a byte buffer
/// in memory with no path to put in a URL (§9.2). Keeping the identity here
/// means the same navigation works on desktop and web instead of one target
/// carrying file paths through the address bar.
///
/// This is *not* the Session Library's persistent index — that's `drift`, at
/// import time, in Phase 2 (§9.6). This list is per-run.
@Riverpod(keepAlive: true)
class OpenSessions extends _$OpenSessions {
  @override
  List<TelemetrySource> build() => const [];

  /// Adds a source and makes it current, moving it to the front if it's
  /// already open rather than opening a second handle to the same file.
  void open(TelemetrySource source) {
    state = [source, ...state.where((s) => s != source)];
  }

  void close(TelemetrySource source) {
    state = state.where((s) => s != source).toList();
  }
}

/// The session the feature screens are looking at, or null when none is open.
@Riverpod(keepAlive: true)
TelemetrySource? currentSession(Ref ref) {
  final open = ref.watch(openSessionsProvider);
  return open.isEmpty ? null : open.first;
}
