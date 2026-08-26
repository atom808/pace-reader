// SQL-construction tests (SPEC.md §12).
//
// The SQL builders are pure string functions specifically so this file can
// exist: it asserts on the *shape* of every statement the data layer emits
// without a database, which matters because the alternative — only ever
// checking these through `integration_test` — means CI can't check them at
// all without a device.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/channel_queries.dart';
import 'package:pace_reader/data/duckdb/lap_queries.dart';
import 'package:pace_reader/data/duckdb/session_queries.dart';
import 'package:pace_reader/data/duckdb/sql.dart';
import 'package:pace_reader/data/duckdb/time_axis.dart';
import 'package:pace_reader/data/models/models.dart';

/// Real Race-sample geometry, so the expressions under test are built from
/// numbers that actually occur rather than round ones that hide off-by-ones.
const _masterRows = 134059;

const _lapDist = ChannelDescriptor(
  name: 'Lap Dist',
  frequencyHz: 10,
  unit: 'm',
  valueColumnCount: 1,
  rowCount: 13406,
);

const _oilTemp = ChannelDescriptor(
  name: 'Engine Oil Temp',
  frequencyHz: 7,
  unit: 'C',
  valueColumnCount: 1,
  rowCount: 9408,
);

const _tyrePressure = ChannelDescriptor(
  name: 'TyresPressure',
  frequencyHz: 10,
  unit: 'kPa',
  valueColumnCount: 4,
  rowCount: 13406,
);

void main() {
  group('quoteIdent', () {
    test('quotes names containing spaces', () {
      expect(quoteIdent('Engine RPM'), '"Engine RPM"');
      expect(quoteIdent('Track Temperature'), '"Track Temperature"');
    });

    test('escapes an embedded double quote by doubling it', () {
      // Table names come from a file's own catalog, so a name containing a
      // quote would otherwise close the identifier early and splice the rest
      // into the statement.
      expect(quoteIdent('od"d'), '"od""d"');
      // The leading quote doubles, so the identifier stays one token and the
      // rest is inert text rather than statement syntax.
      expect(
        quoteIdent('"; DROP TABLE metadata; --'),
        '"""; DROP TABLE metadata; --"',
      );
    });

    test('rejects an empty identifier rather than emitting ""', () {
      expect(() => quoteIdent(''), throwsArgumentError);
    });
  });

  group('quoteLiteral / sqlDouble', () {
    test('escapes single quotes in literals', () {
      expect(quoteLiteral("Sebring's"), "'Sebring''s'");
    });

    test('rejects non-finite doubles', () {
      expect(() => sqlDouble(double.nan), throwsArgumentError);
      expect(() => sqlDouble(double.infinity), throwsArgumentError);
      expect(sqlDouble(23.5975), '23.5975');
    });
  });

  group('masterRowExpression', () {
    test('an on-grid channel uses an exact integer stride', () {
      // The correction to SPEC v0.6 §5.2: the stride is exact, whereas
      // round(i * masterRows / rowCount) compresses the axis and lands the
      // last sample of a 1 Hz channel up to 0.5 s early.
      expect(masterRowExpression(_lapDist, _masterRows), '(i * 10)');
    });

    test('a 100 Hz channel needs no arithmetic at all', () {
      const rpm = ChannelDescriptor(
        name: 'Engine RPM',
        frequencyHz: 100,
        unit: 'RPM',
        valueColumnCount: 1,
        rowCount: _masterRows,
      );
      expect(masterRowExpression(rpm, _masterRows), 'i');
    });

    test('an off-grid channel falls back to the row-count ratio', () {
      // 100/7 isn't an integer and the declared 7 Hz is wrong anyway, so no
      // stride model exists — the ratio is correct precisely here.
      final expression = masterRowExpression(_oilTemp, _masterRows);
      expect(expression, startsWith('CAST(round(i * '));
      expect(expression, endsWith(') AS BIGINT)'));
      expect(expression, contains((_masterRows / _oilTemp.rowCount).toString()));
    });

    test('honours a custom row-index expression for use inside a join', () {
      expect(
        masterRowExpression(_lapDist, _masterRows, rowIndexExpr: 'a.i0'),
        '(a.i0 * 10)',
      );
    });

    test('reports which derivation a channel needs', () {
      expect(usesExactStride(_lapDist, _masterRows), isTrue);
      expect(usesExactStride(_oilTemp, _masterRows), isFalse);
    });
  });

  group('decimateSql', () {
    test('uses floor() so bucket indices stay in 0..buckets-1', () {
      // A bare CAST from DOUBLE rounds half away from zero, which would let
      // the final row land in bucket `buckets` and yield buckets + 1 groups.
      final sql = decimateSql(_lapDist, _masterRows,
          rowStart: 0, rowEndExclusive: 13406, buckets: 1200);
      expect(sql, contains('CAST(floor('));
      expect(sql, contains('GROUP BY bucket'));
      expect(sql, contains('ORDER BY a.bucket'));
    });

    test('aggregates before joining the master grid', () {
      // The whole point of the ordering: only bucket representatives get a
      // timestamp lookup, so the join is viewport-sized rather than
      // session-sized (8.7M rows on a 24-hour file).
      final sql = decimateSql(_lapDist, _masterRows,
          rowStart: 0, rowEndExclusive: 13406, buckets: 1200);
      expect(sql.indexOf('_agg AS'), lessThan(sql.indexOf('JOIN $masterCteName')));
      expect(sql, contains('MIN(i) AS i0'));
    });

    test('emits one lo/hi pair per value column for a per-corner channel', () {
      final sql = decimateSql(_tyrePressure, _masterRows,
          rowStart: 0, rowEndExclusive: 13406, buckets: 600);
      for (var n = 0; n < 4; n++) {
        expect(sql, contains('lo_$n'));
        expect(sql, contains('hi_$n'));
      }
      expect(sql, contains('MIN("value1")'));
      expect(sql, contains('MAX("value4")'));
    });

    test('restricts to the requested row range', () {
      final sql = decimateSql(_lapDist, _masterRows,
          rowStart: 500, rowEndExclusive: 1500, buckets: 100);
      expect(sql, contains('i >= 500 AND i < 1500'));
    });

    test('rejects a degenerate range or bucket count', () {
      expect(
        () => decimateSql(_lapDist, _masterRows,
            rowStart: 10, rowEndExclusive: 10, buckets: 100),
        throwsArgumentError,
      );
      expect(
        () => decimateSql(_lapDist, _masterRows,
            rowStart: 0, rowEndExclusive: 10, buckets: 0),
        throwsArgumentError,
      );
    });
  });

  group('channelRowRangeSql', () {
    test('resolves the window against GPS Time, not by arithmetic', () {
      // Arithmetic on (t - origin) * frequency is blind to recording
      // discontinuities and would name the wrong rows after one.
      final sql = channelRowRangeSql(_lapDist, _masterRows,
          startSeconds: 195.82, endSeconds: 260.32);
      expect(sql, contains(quoteIdent(masterChannelName)));
      expect(sql, contains('t >= 195.82'));
      expect(sql, contains('t < 260.32'));
    });

    test('rounds the start up and the end down to real sample positions', () {
      final sql = channelRowRangeSql(_lapDist, _masterRows,
          startSeconds: 100, endSeconds: 200);
      expect(sql, contains('ceil(m0 / 10.0)'));
      expect(sql, contains('floor(m1 / 10.0)'));
    });

    test('clamps to the channel row count', () {
      final sql = channelRowRangeSql(_lapDist, _masterRows,
          startSeconds: 0, endSeconds: 99999);
      expect(sql, contains('least'));
      expect(sql, contains('${_lapDist.rowCount}'));
    });
  });

  group('eventAsOfChannelSql', () {
    test('uses ASOF LEFT JOIN, never a bare ASOF JOIN', () {
      // A plain ASOF JOIN is inner and silently drops unmatched samples —
      // exactly how the Phase 0 spike passed while measuring a clock 23.6 s
      // out of alignment.
      const gear = EventDescriptor(
        name: 'Gear',
        unit: '',
        valueColumnCount: 1,
        rowCount: 758,
      );
      final sql = eventAsOfChannelSql(_lapDist, _masterRows, event: gear);
      expect(sql, contains('ASOF LEFT JOIN'));
      expect(sql, contains('e.ts <= _timed.t'));
    });
  });

  group('lapTableSql', () {
    test('reads each lap\'s time at its END boundary', () {
      // `Lap Time` is emitted when a lap completes, which is the same instant
      // as the next lap's `Lap` event.
      final sql = lapTableSql();
      expect(sql, contains('lead(ts) OVER (ORDER BY ts) AS end_ts'));
      expect(sql, contains('lt.ts = _b.end_ts'));
      expect(sql, contains('s1.ts = _b.end_ts'));
      expect(sql, contains('s2.ts = _b.end_ts'));
    });

    test('joins on exact equality, not ASOF', () {
      // Laps legitimately have no `Lap Time` row (an untimed out-lap), and
      // ASOF would resolve those to the *previous* lap's time — silently
      // attributing one lap's pace to another. Equality yields null.
      final sql = lapTableSql();
      expect(sql, contains('LEFT JOIN'));
      expect(sql.contains('ASOF'), isFalse);
    });

    test('names the cumulative column as cumulative', () {
      expect(lapTableSql(), contains('sector2_cum'));
    });
  });

  group('sector codes', () {
    test('Current Sector code 0 is sector 3', () {
      // The cycle is 1 -> 2 -> 0, confirmed by measuring durations between
      // transitions against the reported splits.
      expect(sectorNumberFromCode(1), 1);
      expect(sectorNumberFromCode(2), 2);
      expect(sectorNumberFromCode(0), 3);
    });
  });

  group('rowCountsSql', () {
    test('batches many tables into one statement', () {
      // ~98 tables at open time; one COUNT(*) each would be ~98 round trips.
      final sql = rowCountsSql(['Engine RPM', 'Gear', 'Lap Dist']);
      expect(sql.split('UNION ALL').length, 3);
      expect(sql, contains('FROM "Engine RPM"'));
      expect(sql, contains("'Gear' AS t"));
    });

    test('rejects an empty table list rather than emitting invalid SQL', () {
      expect(() => rowCountsSql(const []), throwsArgumentError);
    });
  });

  group('discontinuityScanSql', () {
    test('compares consecutive GPS Time steps against 0.01 s', () {
      final sql = discontinuityScanSql();
      expect(sql, contains('lag(v) OVER (ORDER BY i)'));
      expect(sql, contains('abs(dt - 0.01)'));
    });
  });

  group('carSetupValueSql', () {
    test('extracts a corner-named setup value by JSON path', () {
      // The setup names corners explicitly (WM_PRESSURE-W_FL) where
      // value1..value4 don't — §15.5's answer key.
      final sql = carSetupValueSql('WM_PRESSURE-W_FL');
      expect(sql, contains(r"'$.WM_PRESSURE-W_FL.stringValue'"));
      expect(sql, contains("key = 'CarSetup'"));
    });
  });
}
