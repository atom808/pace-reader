// Event-window reads (SPEC.md §5.1, §8.4).
//
// Pure string and array logic, so CI can check the part that is easy to get
// silently wrong — reaching backwards past the window start — without a
// device. `integration_test/data_layer_test.dart` then checks that the SQL
// runs and agrees with the real file.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/event_queries.dart';
import 'package:pace_reader/data/models/models.dart';

const _gear = EventDescriptor(
  name: 'Gear',
  unit: '',
  valueColumnCount: 1,
  rowCount: 160,
);

const _wheelsDetached = EventDescriptor(
  name: 'WheelsDetached',
  unit: '',
  valueColumnCount: 4,
  rowCount: 1,
);

void main() {
  group('eventWindowSql', () {
    test('quotes identifiers that contain spaces', () {
      const inPits = EventDescriptor(
        name: 'In Pits',
        unit: '',
        valueColumnCount: 1,
        rowCount: 1,
      );
      final sql =
          eventWindowSql(inPits, startSeconds: 195.82, endSeconds: 260.32);
      expect(sql, contains('"In Pits"'));
      expect(sql, isNot(contains('FROM In Pits')));
    });

    test('reaches back for the last change before the window', () {
      // The case this exists for: in the checked-in fixture `Gear` has 36-44
      // rows in each of laps 0-3 and **zero** in lap 4, because the recording
      // ends before the next shift. Without the preceding row that lap renders
      // as no gear at all rather than as the gear being held.
      final sql =
          eventWindowSql(_gear, startSeconds: 195.82, endSeconds: 260.32);
      expect(sql, contains('ts < 195.82'));
      expect(sql, contains('ORDER BY ts DESC LIMIT 1'));
      expect(sql, contains('UNION ALL'));
    });

    test('is half-open, so a lap boundary sample belongs to one lap only', () {
      final sql =
          eventWindowSql(_gear, startSeconds: 195.82, endSeconds: 260.32);
      expect(sql, contains('ts >= 195.82'));
      expect(sql, contains('ts < 260.32'));
    });

    test('orders the union as a whole, not just its last branch', () {
      final sql = eventWindowSql(_gear, startSeconds: 10, endSeconds: 20);
      expect(sql.trimRight(), endsWith(') ORDER BY ts'));
    });

    test('projects every value column of a per-corner event', () {
      final sql =
          eventWindowSql(_wheelsDetached, startSeconds: 10, endSeconds: 20);
      for (final column in ['value1', 'value2', 'value3', 'value4']) {
        expect(sql, contains('"$column"'));
      }
    });

    test('rejects an empty window rather than emitting SQL that returns none',
        () {
      expect(() => eventWindowSql(_gear, startSeconds: 20, endSeconds: 20),
          throwsArgumentError);
      expect(() => eventWindowSql(_gear, startSeconds: 20, endSeconds: 10),
          throwsArgumentError);
    });
  });

  group('StepSeries', () {
    test('coerces the storage types the event tables actually use', () {
      // Measured in the fixture: `Gear` is TINYINT, `TC`/`ABS`/`Speed Limiter`
      // are BOOLEAN, `Lap` is USMALLINT. A boolean maps to 1/0 because an
      // on/off signal is exactly a two-level step trace.
      final series = StepSeries.fromRows(
        const [(10.0, 3), (11.0, true), (12.0, false), (13.0, 4.5)],
        eventName: 'Mixed',
      );
      expect(series.values, [3, 1, 0, 4.5]);
    });

    test('drops an unmappable value instead of calling it zero', () {
      // `Gear` genuinely uses 0 for neutral, so a coerced null would be
      // indistinguishable from a real reading.
      final series = StepSeries.fromRows(
        const [(10.0, 3), (11.0, null), (12.0, 'N/A'), (13.0, 5)],
        eventName: 'Gear',
      );
      expect(series.length, 2);
      expect(series.times, [10.0, 13.0]);
    });

    test('resolves a value as of a time, never by equality', () {
      final series = StepSeries.fromRows(
        const [(190.0, 4), (196.5, 3), (200.0, 4)],
        eventName: 'Gear',
      );
      expect(series.valueAt(196.4), 4);
      expect(series.valueAt(196.5), 3);
      expect(series.valueAt(199.999), 3);
      expect(series.valueAt(1e9), 4);
    });

    test('a time before the first row is "no value yet", not a lookup failure',
        () {
      final series =
          StepSeries.fromRows(const [(190.0, 4)], eventName: 'Gear');
      expect(series.valueAt(100), isNull);
      expect(series.indexAt(100), -1);
    });

    test('recognises the never-changed case as a constant', () {
      // §5.1: 21-25 of the 42 event tables hold exactly one row in each
      // sample. Event-driven UI has to render that as a constant rather than
      // as an empty chart.
      final single =
          StepSeries.fromRows(const [(23.5975, 0)], eventName: 'In Pits');
      expect(single.isConstant, isTrue);
      expect(single.valueAt(1000), 0);

      final repeated = StepSeries.fromRows(
        const [(10.0, 2), (20.0, 2), (30.0, 2)],
        eventName: 'TCLevel',
      );
      expect(repeated.isConstant, isTrue);
    });

    test('reports its extent for an axis', () {
      final series = StepSeries.fromRows(
        const [(10.0, 2), (20.0, 6), (30.0, 1)],
        eventName: 'Gear',
      );
      expect(series.minValue, 1);
      expect(series.maxValue, 6);
      expect(series.isConstant, isFalse);
    });
  });

  group('eventLogSql', () {
    const gear = EventDescriptor(
        name: 'Gear', unit: '', valueColumnCount: 1, rowCount: 758);
    const surfaces = EventDescriptor(
        name: 'SurfaceTypes', unit: '', valueColumnCount: 4, rowCount: 7212);

    test('does not reach back before the window', () {
      // The contrast with eventWindowSql is the whole point: a log lists what
      // changed *in* the window, and a row stamped before it did not.
      final sql = eventLogSql(gear, startSeconds: 100, endSeconds: 200);
      expect(sql, isNot(contains('UNION')));
      expect(sql, contains('ts >= 100.0'));
      expect(sql, contains('ts < 200.0'));
    });

    test('reads the whole table when unbounded', () {
      final sql = eventLogSql(gear);
      expect(sql, isNot(contains('WHERE')));
      expect(sql, contains('ORDER BY ts'));
    });

    test('bounds one side without inventing the other', () {
      expect(eventLogSql(gear, startSeconds: 50), contains('WHERE ts >= 50.0'));
      expect(eventLogSql(gear, endSeconds: 50), contains('WHERE ts < 50.0'));
    });

    test('projects every value column of a per-corner event', () {
      final sql = eventLogSql(surfaces);
      for (final c in ['value1', 'value2', 'value3', 'value4']) {
        expect(sql, contains('"$c"'));
      }
    });

    test('quotes identifiers', () {
      const odd = EventDescriptor(
          name: 'Brake Bias Rear', unit: '', valueColumnCount: 1, rowCount: 1);
      expect(eventLogSql(odd), contains('"Brake Bias Rear"'));
    });

    test('applies a limit when given one', () {
      expect(eventLogSql(gear, limit: 10), endsWith('LIMIT 10'));
      expect(eventLogSql(gear), isNot(contains('LIMIT')));
    });

    test('rejects a window and a limit that cannot mean anything', () {
      expect(() => eventLogSql(gear, startSeconds: 200, endSeconds: 100),
          throwsArgumentError);
      expect(() => eventLogSql(gear, limit: 0), throwsArgumentError);
      expect(() => eventLogSql(gear, columns: const []), throwsArgumentError);
    });
  });
}
