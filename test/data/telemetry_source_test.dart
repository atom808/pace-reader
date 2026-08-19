// `TelemetrySource` equality (SPEC.md §9.2, §9.3).
//
// This is the key of the Riverpod family that owns an open DuckDB connection,
// so its equality decides whether reading a session twice reuses the
// connection or reopens the file. That makes it worth pinning: the failure
// mode is not a crash but a silent performance collapse — every widget
// rebuild reopening a multi-hundred-megabyte file and re-scanning its clock.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';

void main() {
  group('FileTelemetrySource', () {
    test('two sources for the same path are the same family key', () {
      const a = TelemetrySource.path('/telemetry/sebring.duckdb');
      const b = TelemetrySource.path('/telemetry/sebring.duckdb');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different paths are different keys', () {
      const a = TelemetrySource.path('/telemetry/sebring.duckdb');
      const b = TelemetrySource.path('/telemetry/spa.duckdb');
      expect(a, isNot(equals(b)));
    });

    test('exposes the path as its label for error messages', () {
      expect(const TelemetrySource.path('/x/y.duckdb').label, '/x/y.duckdb');
    });
  });

  group('BytesTelemetrySource', () {
    test('the same buffer under the same name is the same key', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final a = TelemetrySource.bytes('upload.duckdb', bytes);
      final b = TelemetrySource.bytes('upload.duckdb', bytes);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equal content in a different buffer is NOT the same key', () {
      // Deliberate: these are whole telemetry files, so comparing content
      // element-wise on every provider read would cost more than the reopen
      // it prevents. The import flow passes one buffer instance per file.
      final a = TelemetrySource.bytes('upload.duckdb', Uint8List.fromList([1, 2, 3]));
      final b = TelemetrySource.bytes('upload.duckdb', Uint8List.fromList([1, 2, 3]));
      expect(a, isNot(equals(b)));
    });

    test('a different name is a different key', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(
        TelemetrySource.bytes('a.duckdb', bytes),
        isNot(equals(TelemetrySource.bytes('b.duckdb', bytes))),
      );
    });
  });

  test('a path source never equals a bytes source', () {
    expect(
      const TelemetrySource.path('upload.duckdb'),
      isNot(equals(TelemetrySource.bytes('upload.duckdb', Uint8List(0)))),
    );
  });
}
