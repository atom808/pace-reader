// How the Session Library words its dates, sizes and counts (SPEC.md §8.1).
//
// Small, but they sit on every row: a date in the wrong zone disagrees with
// the filename next to it, and "1 laps" reads as a bug.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/features/session_library/presentation/library_formatting.dart';

void main() {
  group('recording date and time', () {
    // The Race sample's RecordingTime is `2026-07-07T06_42_17Z`, which is also
    // in its filename; the row must say the same.
    final race = DateTime.utc(2026, 7, 7, 6, 42, 17);

    test('are the recording\'s own UTC clock', () {
      expect(formatRecordedDate(race), '7 Jul 2026');
      expect(formatRecordedTime(race), '06:42 UTC');
    });

    test('do not move with the machine\'s zone', () {
      // The same instant built in local time still prints the UTC day.
      final local = race.toLocal();
      expect(formatRecordedDate(local), '7 Jul 2026');
      expect(formatRecordedTime(local), '06:42 UTC');
    });

    test('pad the hour and minute', () {
      expect(
        formatRecordedTime(DateTime.utc(2026, 7, 24, 2, 6, 11)),
        '02:06 UTC',
      );
    });
  });

  group('relative times', () {
    final now = DateTime.utc(2026, 9, 30, 12);

    String ago(Duration d) => formatRelative(now.subtract(d), now);

    test('step from "just now" up to a date', () {
      expect(ago(const Duration(seconds: 10)), 'just now');
      expect(ago(const Duration(seconds: 44)), 'just now');
      expect(ago(const Duration(seconds: 50)), '1 min ago');
      expect(ago(const Duration(minutes: 14)), '14 min ago');
      expect(ago(const Duration(minutes: 59)), '59 min ago');
      expect(ago(const Duration(hours: 3)), '3 h ago');
      expect(ago(const Duration(hours: 25)), 'yesterday');
      expect(ago(const Duration(days: 12)), '12 days ago');
      expect(ago(const Duration(days: 45)), '16 Aug 2026');
    });
  });

  group('file sizes', () {
    test('are decimal megabytes, as SPEC §5.5 quotes them', () {
      expect(formatFileSize(25358336), '25.4 MB');
      expect(formatFileSize(8810496), '8.8 MB');
    });

    test('fall back to kB and bytes for small files', () {
      expect(formatFileSize(23000), '23 kB');
      expect(formatFileSize(512), '512 B');
    });
  });

  group('plurals', () {
    test('say 1 lap and 19 laps', () {
      expect(plural(1, 'lap'), '1 lap');
      expect(plural(19, 'lap'), '19 laps');
      expect(plural(0, 'lap'), '0 laps');
    });

    test('take an irregular plural', () {
      expect(plural(1, 'time'), '1 time');
      expect(plural(2, 'file', 'files'), '2 files');
    });
  });
}
