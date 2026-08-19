/// Importing a telemetry file (SPEC.md §8.1, §9.2).
library;

import 'package:file_picker/file_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/providers.dart';
import 'open_sessions.dart';

part 'session_import.g.dart';

/// See `providers.dart`: import failures are deterministic, so retrying one on
/// a timer only repeats the same failure.
Duration? _neverRetry(int retryCount, Object error) => null;

/// LMU writes `.duckdb`; anything else is a wrong-file mistake worth catching
/// before opening rather than after.
const telemetryFileExtension = 'duckdb';

/// Drives file selection and opening, and owns the error surface for both.
///
/// The controller reports failure as state rather than throwing, because every
/// failure here is a *user* event — wrong file, unreadable file, a session
/// recorded by a newer game build — and each has something specific to say
/// (§10). An import that throws past the UI would collapse all of them into
/// one generic red screen.
@Riverpod(retry: _neverRetry)
class SessionImport extends _$SessionImport {
  @override
  SessionImportState build() => const SessionImportIdle();

  /// Opens the platform file picker.
  ///
  /// Prefers a path and falls back to bytes, which is the §9.2 asymmetry in
  /// its smallest form: on desktop a path lets DuckDB read the file in place,
  /// while on web there is no path and the whole file has to be pulled into
  /// memory first — the exact cost §15.1 flags as an open question for
  /// endurance-length recordings.
  Future<void> pickFile() async {
    state = const SessionImportBusy();
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Open a Le Mans Ultimate telemetry file',
        type: FileType.custom,
        allowedExtensions: const [telemetryFileExtension],
      );
      if (file == null) {
        // Cancelling isn't a failure, and mustn't leave a dialog-shaped error
        // behind.
        state = const SessionImportIdle();
        return;
      }

      final path = file.path;
      if (path != null) {
        await open(TelemetrySource.path(path));
      } else {
        await open(TelemetrySource.bytes(file.name, await file.readAsBytes()));
      }
    } on Object catch (error) {
      state = SessionImportFailure('That file could not be opened.',
          detail: '$error');
    }
  }

  /// Opens a source, validating it before adding it to the open list.
  ///
  /// Opening eagerly here rather than letting the first screen discover a bad
  /// file means an unusable session never enters the list — the alternative is
  /// an entry the user can select that fails every time they do.
  Future<void> open(TelemetrySource source) async {
    state = const SessionImportBusy();
    try {
      await ref.read(telemetrySessionProvider(source).future);
      ref.read(openSessionsProvider.notifier).open(source);
      state = SessionImportSuccess(source);
    } on TelemetryException catch (error) {
      // The data layer's messages are already written for a user (§10), so
      // they're surfaced as-is rather than replaced with something vaguer.
      ref.invalidate(telemetrySessionProvider(source));
      state = SessionImportFailure(error.message, detail: error.toString());
    } on Object catch (error) {
      ref.invalidate(telemetrySessionProvider(source));
      state = SessionImportFailure(
        'That file could not be opened as a telemetry session.',
        detail: '$error',
      );
    }
  }

  /// Accepts paths from a drag-and-drop, filtering out anything that isn't
  /// telemetry so dropping a folder of mixed files does something sensible.
  Future<void> openDroppedPaths(List<String> paths) async {
    final candidates = paths
        .where((p) => p.toLowerCase().endsWith('.$telemetryFileExtension'))
        .toList();
    if (candidates.isEmpty) {
      state = SessionImportFailure(
        paths.length == 1
            ? 'That file is not a Le Mans Ultimate telemetry recording.'
            : 'None of those files are Le Mans Ultimate telemetry recordings.',
        detail: 'expected a .$telemetryFileExtension file',
      );
      return;
    }
    // Multi-file comparison is §8.8 (Phase 3); for now the first wins, and
    // the rest are opened too so they're one click away in the library.
    for (final path in candidates) {
      await open(TelemetrySource.path(path));
    }
  }

  void dismissError() {
    if (state is SessionImportFailure) state = const SessionImportIdle();
  }
}

/// What the import UI is showing.
sealed class SessionImportState {
  const SessionImportState();
}

final class SessionImportIdle extends SessionImportState {
  const SessionImportIdle();
}

final class SessionImportBusy extends SessionImportState {
  const SessionImportBusy();
}

final class SessionImportSuccess extends SessionImportState {
  const SessionImportSuccess(this.source);

  final TelemetrySource source;
}

final class SessionImportFailure extends SessionImportState {
  const SessionImportFailure(this.message, {required this.detail});

  /// Written for a user.
  final String message;

  /// The underlying cause, for a "details" affordance and bug reports.
  final String detail;
}
