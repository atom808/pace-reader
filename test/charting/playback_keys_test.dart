// The lap stage's keys (map stage proposal §5.1): ←/→ nudge the playhead
// by 1 % of the trace window, Shift+←/→ jump between timing lines.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

const _window = ChartViewport(1000, 2000);

void main() {
  group('nudgePlayhead', () {
    test('moves 1 % of the window either way', () {
      expect(
        nudgePlayhead(playhead: 1500, window: _window, fraction: 0.01),
        1510,
      );
      expect(
        nudgePlayhead(playhead: 1500, window: _window, fraction: -0.01),
        1490,
      );
    });

    test('stays inside the window', () {
      expect(
        nudgePlayhead(playhead: 1995, window: _window, fraction: 0.01),
        2000,
      );
      expect(
        nudgePlayhead(playhead: 1002, window: _window, fraction: -0.01),
        1000,
      );
    });

    test('with no playhead starts from the window\'s start', () {
      expect(
        nudgePlayhead(playhead: null, window: _window, fraction: 0.01),
        1010,
      );
    });
  });

  group('jumpToMark', () {
    const marks = [500.0, 1200.0, 1600.0, 2400.0];

    test('goes to the next mark inside the window either way', () {
      expect(
        jumpToMark(playhead: 1300, window: _window, marks: marks, direction: 1),
        1600,
      );
      expect(
        jumpToMark(
          playhead: 1300,
          window: _window,
          marks: marks,
          direction: -1,
        ),
        1200,
      );
    });

    test('past the last mark, the window\'s end; before the first, its '
        'start', () {
      expect(
        jumpToMark(playhead: 1700, window: _window, marks: marks, direction: 1),
        2000,
        reason: '2400 is outside the window',
      );
      expect(
        jumpToMark(
          playhead: 1100,
          window: _window,
          marks: marks,
          direction: -1,
        ),
        1000,
        reason: '500 is outside the window',
      );
    });

    test('a playhead on a mark moves off it rather than staying', () {
      expect(
        jumpToMark(playhead: 1201, window: _window, marks: marks, direction: 1),
        1600,
      );
      expect(
        jumpToMark(
          playhead: 1599,
          window: _window,
          marks: marks,
          direction: -1,
        ),
        1200,
      );
    });

    test('unsorted marks are fine', () {
      expect(
        jumpToMark(
          playhead: 1000,
          window: _window,
          marks: const [1600, 1200],
          direction: 1,
        ),
        1200,
      );
    });
  });
}
