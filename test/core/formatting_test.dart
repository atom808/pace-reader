import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/core/formatting.dart';

void main() {
  group('formatLapTime', () {
    test('renders a real lap time as m:ss.mmm', () {
      // The Race sample's best lap.
      expect(formatLapTime(64.02963256835938), '1:04.030');
      expect(formatLapTime(71.24098205566406), '1:11.241');
      expect(formatLapTime(122.73663330078125), '2:02.737');
    });

    test('pads seconds so the column holds its width', () {
      expect(formatLapTime(60.5), '1:00.500');
      expect(formatLapTime(65.0), '1:05.000');
    });

    test('handles sub-minute and zero values', () {
      expect(formatLapTime(23.347), '0:23.347');
      expect(formatLapTime(0), '0:00.000');
    });

    test('does not hide an implausible value behind an hours field', () {
      expect(formatLapTime(4392.004), '73:12.004');
    });

    test('renders non-finite values as an em dash rather than "NaN"', () {
      expect(formatLapTime(double.nan), '—');
      expect(formatLapTime(double.infinity), '—');
    });
  });

  group('formatSectorTime', () {
    test('renders sectors as plain seconds', () {
      expect(formatSectorTime(23.346588134765625), '23.347');
      expect(formatSectorTime(12.914), '12.914');
    });

    test('falls back to the lap format past a minute', () {
      // 49.760 is a real S2 on the Practice sample; 84 would be unusual but
      // must not read as a plain "84.213".
      expect(formatSectorTime(49.76), '49.760');
      expect(formatSectorTime(84.213), '1:24.213');
    });
  });

  group('formatDelta', () {
    test('always carries a sign, including zero', () {
      expect(formatDelta(0.467), '+0.467');
      expect(formatDelta(-1.204), '-1.204');
      expect(formatDelta(0), '+0.000');
    });

    test('uses the lap format for large gaps', () {
      expect(formatDelta(-64.5), '-1:04.500');
    });
  });

  group('formatSessionDuration', () {
    test('omits hours when there are none', () {
      expect(formatSessionDuration(1340.58), '22:21');
      expect(formatSessionDuration(65), '1:05');
    });

    test('shows hours for endurance-length sessions', () {
      expect(formatSessionDuration(21600), '6:00:00');
      expect(formatSessionDuration(3661), '1:01:01');
    });

    test('rejects negatives rather than rendering them', () {
      expect(formatSessionDuration(-5), '—');
    });
  });

  group('optional formatters', () {
    test('null renders as an em dash', () {
      // Null is the norm, not an edge case: untimed out-laps, invalidated
      // laps, and sectors the game wrote as 0.0.
      expect(formatOptionalLapTime(null), '—');
      expect(formatOptionalSectorTime(null), '—');
      expect(formatOptionalLapTime(64.03), '1:04.030');
    });
  });
}
