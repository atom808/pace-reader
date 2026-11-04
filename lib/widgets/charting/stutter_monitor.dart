/// Whether playback is stuttering on this machine (map stage proposal §7.4):
/// the evidence behind the one-time offer of Performance mode.
library;

import 'dart:collection';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/widgets.dart';

/// Watches frames during playback, and says when more than [share] of them
/// over the last [window] took longer than [budget] to raster.
///
/// Pure: it is fed `(when, how long)` pairs, so the rule is checkable
/// without a frame being drawn. Silent until it has a full [window] of
/// frames, so a single slow frame on the first press of ▶ — a shader
/// compiling — is never mistaken for a machine that can't keep up.
class StutterMonitor {
  StutterMonitor({
    this.window = const Duration(seconds: 3),
    this.budget = const Duration(microseconds: 16667),
    this.share = 0.2,
  });

  final Duration window;
  final Duration budget;
  final double share;

  final _frames = Queue<(Duration at, bool slow)>();
  var _slow = 0;

  /// Adds a frame finished at [at] that took [raster]; true once the last
  /// [window] holds enough slow frames to call it stuttering.
  bool add(Duration at, Duration raster) {
    final slow = raster > budget;
    _frames.add((at, slow));
    if (slow) _slow++;
    while (_frames.isNotEmpty && at - _frames.first.$1 > window) {
      if (_frames.removeFirst().$2) _slow--;
    }
    final span = at - _frames.first.$1;
    // Within a frame of the full window: frames rarely land on it exactly.
    if (span < window - const Duration(milliseconds: 50)) return false;
    return _slow / _frames.length > share;
  }

  /// Forgets every frame: playback paused, so the next run starts afresh.
  void reset() {
    _frames.clear();
    _slow = 0;
  }
}

/// Feeds the engine's frame timings to a [StutterMonitor] while [active] —
/// playback running with the costly effects on — and calls [onStutter] the
/// first time it judges the frames too slow. Paused, it forgets.
class StutterWatch extends StatefulWidget {
  const StutterWatch({
    super.key,
    required this.active,
    required this.onStutter,
    required this.child,
  });

  final bool active;
  final VoidCallback onStutter;
  final Widget child;

  @override
  State<StutterWatch> createState() => _StutterWatchState();
}

class _StutterWatchState extends State<StutterWatch> {
  final _monitor = StutterMonitor();
  var _listening = false;
  var _told = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(StutterWatch old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active == _listening) return;
    _listening = widget.active;
    if (_listening) {
      _told = false;
      SchedulerBinding.instance.addTimingsCallback(_timings);
    } else {
      SchedulerBinding.instance.removeTimingsCallback(_timings);
      _monitor.reset();
    }
  }

  void _timings(List<FrameTiming> timings) {
    if (_told || !mounted) return;
    for (final t in timings) {
      final at = Duration(
        microseconds: t.timestampInMicroseconds(FramePhase.rasterFinish),
      );
      // The slower half of the frame: blur costs the raster thread, a busy
      // layout the build one, and either drops the frame.
      final cost = t.buildDuration > t.rasterDuration
          ? t.buildDuration
          : t.rasterDuration;
      if (_monitor.add(at, cost)) {
        _told = true;
        widget.onStutter();
        return;
      }
    }
  }

  @override
  void dispose() {
    if (_listening) SchedulerBinding.instance.removeTimingsCallback(_timings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
