/// The one rule every Compare read obeys (comparison proposal §9, "File
/// ownership"): a file is read through its kept-alive session only while it
/// is in Open now.
///
/// `telemetrySessionProvider` is kept alive by design — the family key is the
/// open file — so a Compare provider that built one for a file the user never
/// opened would hold that file until the app quit: on Windows, a recording
/// that cannot be deleted (§8.1). Files that are not open are read only
/// through an open-read-dispose reader (`compare_laps.dart`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../session_library/application/open_sessions.dart';
import '../domain/comparison_set.dart';

/// Whether [source] is in Open now.
///
/// Through `select`, so reordering Open now — which every switch of the
/// current session does — rebuilds nothing that only asked this.
bool watchSourceOpen(Ref ref, TelemetrySource source) =>
    ref.watch(openSessionsProvider.select((open) => open.contains(source)));

/// A lap Compare was asked to read whose file is not open: closed by the
/// user, or never opened.
class CompareSourceClosed implements Exception {
  const CompareSourceClosed(this.source, this.role);

  final TelemetrySource source;
  final ComparisonRole role;

  @override
  String toString() =>
      'CompareSourceClosed(${role.label}: ${source.label} is not open)';
}

/// Throws [CompareSourceClosed] unless [source] is open — the guard every
/// per-lap Compare read passes first.
void requireSourceOpen(Ref ref, TelemetrySource source, ComparisonRole role) {
  if (!watchSourceOpen(ref, source)) throw CompareSourceClosed(source, role);
}
