/// The provider the Setup Viewer reads (SPEC.md §8.10).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/providers.dart';
import 'car_setup.dart';

part 'car_setup_provider.g.dart';

/// See `providers.dart`: a malformed `CarSetup` is malformed on every read, so
/// retrying one on a timer only repeats the failure.
Duration? _neverRetry(int retryCount, Object error) => null;

/// The session's car setup, parsed.
///
/// Built on [sessionMetadataProvider] rather than a query of its own: the
/// `CarSetup` JSON is one of the twelve `metadata` rows the session already
/// reads when it opens, so the Setup Viewer adds no SQL and no second pass
/// over the file. Its own provider, rather than a parse inside the screen, so
/// a widget test hands the screen a [CarSetup] built from a real sample's JSON
/// without a DuckDB connection, and so switching sections and back does not
/// re-parse 38 kB.
///
/// A blank entry yields [CarSetup.empty], which the screen states rather than
/// draws blank; text that is not a JSON object surfaces as a
/// [SetupFormatException] through the usual error state.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<CarSetup> carSetup(Ref ref, TelemetrySource source) async {
  final metadata = await ref.watch(sessionMetadataProvider(source).future);
  return CarSetup.parse(metadata.carSetupJson);
}
