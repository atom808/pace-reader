import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

/// Feeds [monitor] [count] frames 1/60 s apart from [from], each taking
/// [cost]; true if any of them tipped it.
bool _feed(
  StutterMonitor monitor, {
  required int count,
  required Duration cost,
  Duration from = Duration.zero,
}) {
  var tipped = false;
  for (var i = 0; i < count; i++) {
    final at = from + Duration(microseconds: (i * 1e6 / 60).round());
    tipped = monitor.add(at, cost) || tipped;
  }
  return tipped;
}

const _fast = Duration(milliseconds: 8);
const _slow = Duration(milliseconds: 30);

void main() {
  test('smooth frames never tip it', () {
    expect(_feed(StutterMonitor(), count: 600, cost: _fast), isFalse);
  });

  test('a run of slow frames tips it once a full window has passed', () {
    final monitor = StutterMonitor();
    // Two seconds of slow frames: not yet a full three-second window.
    expect(_feed(monitor, count: 120, cost: _slow), isFalse);
    expect(
      _feed(monitor, count: 70, cost: _slow, from: const Duration(seconds: 2)),
      isTrue,
    );
  });

  test('a single hitch on the first press of play is forgiven', () {
    final monitor = StutterMonitor();
    monitor.add(Duration.zero, const Duration(milliseconds: 200));
    expect(
      _feed(
        monitor,
        count: 300,
        cost: _fast,
        from: const Duration(milliseconds: 16),
      ),
      isFalse,
    );
  });

  test('a fifth of the frames slow is the line', () {
    // One in four frames slow: over the share.
    final over = StutterMonitor();
    var tipped = false;
    for (var i = 0; i < 240; i++) {
      final at = Duration(microseconds: (i * 1e6 / 60).round());
      tipped = over.add(at, i % 4 == 0 ? _slow : _fast) || tipped;
    }
    expect(tipped, isTrue);

    // One in ten: under it.
    final under = StutterMonitor();
    tipped = false;
    for (var i = 0; i < 240; i++) {
      final at = Duration(microseconds: (i * 1e6 / 60).round());
      tipped = under.add(at, i % 10 == 0 ? _slow : _fast) || tipped;
    }
    expect(tipped, isFalse);
  });

  test('reset forgets, so a paused run starts afresh', () {
    final monitor = StutterMonitor();
    _feed(monitor, count: 150, cost: _slow);
    monitor.reset();
    expect(
      _feed(monitor, count: 60, cost: _slow, from: const Duration(seconds: 9)),
      isFalse,
      reason: 'one second since the reset is not a full window',
    );
  });
}
