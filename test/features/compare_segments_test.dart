// Segment tables through the providers (comparison proposal §5 "Frozen",
// §9, step 4): which lap the table is cut from, what detection reads, and
// that nothing but the store decides a course's segments once it has some.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/features/driver_comparison/application/segment_tables.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/domain/segments.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';
import 'compare_harness.dart';

final _a = CompareFile('/segments/a.duckdb');
final _b = CompareFile(
  '/segments/b.duckdb',
  metadata: sebringMetadata.copyWith(recordingTime: '2026-07-07T05_57_04Z'),
);

ComparisonSet _pair(CompareFile base, CompareFile target, {int? targetLap}) =>
    ComparisonSet(
      LapRef(base.source, sebringLapIndex),
      LapRef(target.source, targetLap ?? sebringLap3Index),
    );

class _Setup {
  _Setup(this.container, this.speedReads);

  final ProviderContainer container;
  final LapReadLog speedReads;

  Future<ComparisonSegments> segments(ComparisonSet set) async =>
      (await readFuture<ComparisonSegments?>(
        container,
        comparisonSegmentsProvider(set).future,
      ))!;

  SegmentTable? table(TrackKey key) =>
      container.read(segmentTableProvider(key));
}

_Setup _setup(List<CompareFile> files) {
  final speedReads = <(String, int)>[];
  final container = ProviderContainer(
    overrides: [
      openSessionsProvider.overrideWith(
        () => FixedOpenSessions([for (final f in files) f.source]),
      ),
      ...compareFileOverrides(files, speedReads: speedReads),
    ],
  );
  addTearDown(container.dispose);
  return _Setup(container, speedReads);
}

final _key = TrackKey.of(sebringMetadata);

void main() {
  group('the canonical lap', () {
    test('is the faster clean lap of Base and the Target', () async {
      final s = _setup([_a, _b]);
      final table = (await s.segments(_pair(_a, _b))).table!;
      // Base, lap 2, recorded contact; the Target's lap 4 is clean.
      expect(table.canonical.recording, _b.metadata.recordingIdentity);
      expect(table.canonical.lapIndex, sebringLap3Index);
      expect(table.canonical.lapNumber, 4);
    });

    test("never the recording's first lap, nor a lap with contact: neither "
        'is even read', () async {
      final s = _setup([_a, _b]);
      await s.segments(_pair(_a, _b));
      expect(s.speedReads.toSet(), {
        (_a.path, sebringLap3Index),
        (_b.path, sebringLap3Index),
      });
    });

    test('not a stall lap, however fast', () async {
      final clean = CompareFile('/segments/clean.duckdb', contact: false);
      final stalled = CompareFile(
        '/segments/stalled.duckdb',
        metadata: _b.metadata,
        stalledLap: sebringLap3Index,
      );
      final s = _setup([clean, stalled]);
      final table = (await s.segments(_pair(clean, stalled))).table!;
      expect(table.canonical.lapIndex, sebringLapIndex);
      expect(table.canonical.recording, clean.metadata.recordingIdentity);
    });

    test("neither clean: the fastest clean lap of their files", () async {
      final stalled = CompareFile(
        '/segments/stalled.duckdb',
        metadata: _b.metadata,
        stalledLap: sebringLap3Index,
      );
      final s = _setup([_a, stalled]);
      final table = (await s.segments(_pair(_a, stalled))).table!;
      expect(table.canonical.recording, _a.metadata.recordingIdentity);
      expect(table.canonical.lapIndex, sebringLap3Index);
    });

    test('no clean lap anywhere: no segments, and why', () async {
      final stalled = CompareFile('/segments/stalled.duckdb', stalledLap: 3);
      final s = _setup([stalled]);
      final segments = await s.segments(
        _pair(stalled, stalled, targetLap: sebringLap3Index),
      );
      expect(segments.segments, isNull);
      expect(segments.unavailable, contains('Neither file has a clean lap'));
      // The sectors are the game's own, and still there.
      expect(segments.sectors.stretches, hasLength(3));
    });
  });

  group('frozen', () {
    test('the boundaries are the detected ones', () async {
      final s = _setup([_a, _b]);
      final segments = await s.segments(_pair(_a, _b));
      expect(
        segments.table!.boundaries,
        pairwiseCompare(
          [354, 698, 1156, 1407, 2400],
          (num expected, num actual) => (actual - expected).abs() <= 5,
          'within 5 m of',
        ),
      );
      expect(segments.segments!.worst!.segment.number, 3);
      expect(s.table(_key), same(segments.table));
    });

    test('unchanged by a Swap, another Target, or the canonical file '
        'closing', () async {
      final s = _setup([_a, _b]);
      final table = (await s.segments(_pair(_a, _b))).table!;
      final reads = s.speedReads.length;

      final swapped = await s.segments(_pair(_a, _b).swapped());
      expect(swapped.table, same(table));

      final sameFile = await s.segments(
        ComparisonSet(
          LapRef(_a.source, sebringLapIndex),
          LapRef(_a.source, sebringLap3Index),
        ),
      );
      expect(sameFile.table, same(table));

      // The canonical lap was the Target's, in b.
      await s.container.read(openSessionsProvider.notifier).close(_b.source);
      expect(s.table(_key), same(table));
      final afterClose = await s.segments(
        ComparisonSet(
          LapRef(_a.source, sebringLapIndex),
          LapRef(_a.source, sebringLap3Index),
        ),
      );
      expect(afterClose.table, same(table));
      // Nothing was detected again.
      expect(s.speedReads, hasLength(reads));
    });

    test('Swap flips every sign over the same metres', () async {
      final s = _setup([_a, _b]);
      final forward = (await s.segments(_pair(_a, _b))).segments!;
      final back = (await s.segments(_pair(_a, _b).swapped())).segments!;
      for (var k = 0; k < forward.stretches.length; k++) {
        expect(back.stretches[k].segment, forward.stretches[k].segment);
        expect(
          back.stretches[k].loss,
          closeTo(-forward.stretches[k].loss!, 1e-9),
        );
      }
    });
  });

  test('sector lines 8 m apart: no segments, the sectors stay', () async {
    final far = CompareFile('/segments/far.duckdb', stationOffset: 8);
    final s = _setup([_a, far]);
    final segments = await s.segments(_pair(_a, far));
    expect(segments.segments, isNull);
    expect(segments.unavailable, contains('withheld'));
    // The copy's splits are timed at its own sector lines, 8 m on.
    expect(segments.sectors.stretches.every((s) => s.measured), isTrue);
    // Nothing was detected for a pair with no delta.
    expect(s.speedReads, isEmpty);
  });
}
