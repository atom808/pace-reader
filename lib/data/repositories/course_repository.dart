/// What a recording says about its course (comparison proposal §4).
library;

import '../duckdb/course_queries.dart';
import '../duckdb/lap_queries.dart';
import '../duckdb/telemetry_database.dart';
import '../models/models.dart';

/// Reads [CourseFacts] from one open file.
///
/// Each fact is read only when the file carries what it comes from, and
/// missing ones are null rather than errors: a file without `Total Dist` is
/// still a file whose laps can be drawn, it just cannot prove its course's
/// length, and the comparison says so.
class CourseRepository {
  CourseRepository(this._exec, this._catalog);

  final TelemetryQueryExecutor _exec;
  final TelemetryCatalog _catalog;

  Future<CourseFacts> readCourseFacts() async {
    final lapDistance = _catalog.channel(lapDistanceChannel);
    final totalDistance = _catalog.channel(totalDistanceChannel);

    double? wrapLength;
    var wrapCount = 0;
    if (lapDistance != null &&
        totalDistance != null &&
        lapDistance.frequencyHz == totalDistance.frequencyHz) {
      final row = await _exec.firstRow(wrapLengthSql());
      wrapCount = (row?[1] as num?)?.toInt() ?? 0;
      wrapLength = wrapCount == 0 ? null : (row?[0] as num?)?.toDouble();
    }

    final crossings = <SectorCrossing>[];
    if (lapDistance != null && _catalog.hasEvent(currentSectorEventTable)) {
      for (final row in await _exec.rows(
        sectorCrossingsSql(lapDistance, _catalog.masterRowCount),
      )) {
        crossings.add((
          sector: sectorNumberFromCode((row[0] as num).toInt()),
          seconds: (row[1] as num).toDouble(),
          station: (row[2] as num).toDouble(),
        ));
      }
    }

    final inPits = <(double, bool)>[];
    if (_catalog.hasEvent(inPitsEventTable)) {
      for (final row in await _exec.rows(inPitsSql())) {
        inPits.add(((row[0] as num).toDouble(), _truthy(row[1])));
      }
    }

    return CourseFacts.fromReads(
      wrapLength: wrapLength,
      wrapCount: wrapCount,
      crossings: crossings,
      inPits: inPits,
    );
  }

  /// `In Pits` is a UTINYINT 0/1 in every recording seen; a boolean is
  /// accepted too, should a future export write one.
  static bool _truthy(Object? value) => switch (value) {
    final bool b => b,
    final num n => n != 0,
    _ => false,
  };
}
