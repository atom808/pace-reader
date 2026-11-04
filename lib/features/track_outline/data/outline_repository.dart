/// The reads behind the road band (map stage proposal §3.4): one
/// recording's edges per station, and how far either side its laps went.
library;

import '../../../data/duckdb/outline_queries.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/telemetry_catalog.dart';
import '../../../data/repositories/session_repository.dart';
import '../domain/outline_pool.dart';

class OutlineRepository {
  OutlineRepository(this._exec, this._catalog);

  final TelemetryQueryExecutor _exec;
  final TelemetryCatalog _catalog;

  /// `Track Edge` per station; empty for a file without the channels.
  Future<List<EdgeBin>> edgeBins() =>
      _bins([...outlineChannels, edgeChannel], trackEdgeBinsSql());

  /// The 2nd–98th percentile of `Path Lateral` per [envelopeBinMetres]
  /// station; empty for a
  /// file without the channels.
  Future<List<EdgeBin>> envelope() => _bins(
    outlineChannels,
    pathLateralEnvelopeSql(binMetres: envelopeBinMetres),
  );

  /// The queries join positionally, which is only row-aligned when every
  /// channel is written at one rate.
  Future<List<EdgeBin>> _bins(List<String> channels, String sql) async {
    final rates = {
      for (final name in channels) _catalog.channel(name)?.frequencyHz,
    };
    if (rates.length != 1 || rates.single == null) return const [];
    return [
      for (final row in await _exec.rows(sql))
        (
          bin: (row[0]! as num).toInt(),
          left: (row[1] as num?)?.toDouble(),
          right: (row[2] as num?)?.toDouble(),
        ),
    ];
  }
}

/// Opens a recording the user has not opened just long enough to read its
/// edges, then closes it: `readComparableFactsBriefly`'s pattern.
Future<List<EdgeBin>> readEdgeBinsBriefly(TelemetrySource source) async {
  final session = await openTelemetrySession(source);
  try {
    return await OutlineRepository(
      session.database,
      session.catalog,
    ).edgeBins();
  } finally {
    await session.dispose();
  }
}
