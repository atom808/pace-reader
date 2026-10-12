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
import 'package:path/path.dart' as p;

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

  // Both styles run on every CI runner: the rules are injected, not read from
  // the machine the test happens to run on.
  group('canonical paths', () {
    final windows = p.Context(style: p.Style.windows);
    final posix = p.Context(style: p.Style.posix);

    test('Windows rules: case and separators do not make a second file', () {
      expect(
        canonicalSessionPath('C:/x/Race.duckdb', context: windows),
        canonicalSessionPath(r'c:\x\race.duckdb', context: windows),
      );
      expect(
        canonicalSessionPath(r'C:\x\..\x\.\Race.duckdb', context: windows),
        canonicalSessionPath(r'c:\x\race.duckdb', context: windows),
      );
      expect(
        canonicalSessionPath(r'C:\x\Race.duckdb', context: windows),
        isNot(canonicalSessionPath(r'C:\x\Spa.duckdb', context: windows)),
      );
    });

    test('posix rules leave the path as it is', () {
      // Linux is case-sensitive: folding would merge two different files.
      expect(
        canonicalSessionPath('/x/Race.duckdb', context: posix),
        isNot(canonicalSessionPath('/x/race.duckdb', context: posix)),
      );
      expect(canonicalSessionPath('/x//Race.duckdb', context: posix),
          '/x//Race.duckdb');
    });

    group('as the family key', () {
      late p.Context previous;
      setUp(() => previous = FileTelemetrySource.pathContext);
      tearDown(() => FileTelemetrySource.pathContext = previous);

      test('under Windows rules two spellings are one source', () {
        FileTelemetrySource.pathContext = windows;
        const a = TelemetrySource.path('C:/x/Race.duckdb');
        const b = TelemetrySource.path(r'c:\x\race.duckdb');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        // The label keeps the spelling the user gave, for display.
        expect(a.label, 'C:/x/Race.duckdb');
      });

      test('under posix rules they stay two sources', () {
        FileTelemetrySource.pathContext = posix;
        expect(
          const TelemetrySource.path('/x/Race.duckdb'),
          isNot(equals(const TelemetrySource.path('/x/race.duckdb'))),
        );
      });
    });
  });

  test('a path source never equals a bytes source', () {
    expect(
      const TelemetrySource.path('upload.duckdb'),
      isNot(equals(TelemetrySource.bytes('upload.duckdb', Uint8List(0)))),
    );
  });
}
