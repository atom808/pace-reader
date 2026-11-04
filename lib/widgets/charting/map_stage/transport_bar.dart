/// The play bar along the stage's foot (map stage proposal §2, §5.1), and
/// the ticker behind ▶.
///
/// [PlaybackDriver] advances the shared playhead while [playbackProvider]
/// says playing; [TransportBar] shows and sets it: ▶, the rate, the loop,
/// where the lap is, and a scrubber over the whole lap with the trace window
/// marked on it.
library;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design_system/design_system.dart';
import '../decimation.dart';
import '../playback.dart';
import '../sync/chart_sync.dart';
import '../sync/sync_owner.dart';
import '../viewport.dart';

/// Ticks the playhead along while playing. Wrap the stage in one: nothing
/// plays while no stage is on screen.
class PlaybackDriver extends ConsumerStatefulWidget {
  const PlaybackDriver({
    super.key,
    required this.bounds,
    required this.child,
    this.distanceAxis,
  });

  /// The lap's extent on the current axis.
  final ChartViewport bounds;

  /// What converts lap time to metres on the Distance axis.
  final DistanceAxis? distanceAxis;
  final Widget child;

  @override
  ConsumerState<PlaybackDriver> createState() => _PlaybackDriverState();
}

class _PlaybackDriverState extends ConsumerState<PlaybackDriver>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late final PlaybackController _playback;
  Duration? _last;

  @override
  void initState() {
    super.initState();
    _playback = ref.read(playbackProvider.notifier);
    if (ref.read(playbackProvider).playing) _start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    // Leaving the stage stops the lap, after this frame: a provider may not
    // change while the tree is being torn down — and by then the whole
    // container may have gone with it.
    final playback = _playback;
    Future.microtask(() {
      playback.pauseIfMounted();
    });
    super.dispose();
  }

  void _start() {
    if (_ticker.isActive) return;
    _last = null;
    // One moving line while playing: the probe goes until the pointer moves.
    ref.read(chartSyncProvider.notifier).setProbe(null);
    _ticker.start();
  }

  void _stop() {
    _ticker.stop();
    _last = null;
  }

  void _tick(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    if (last == null) return;
    final seconds = (elapsed - last).inMicroseconds / 1e6;
    final sync = ref.read(chartSyncProvider);
    final controller = ref.read(chartSyncProvider.notifier);
    final playback = ref.read(playbackProvider);
    final bounds = widget.bounds;
    final window = sync.visible(bounds);
    final step = advancePlayhead(
      playhead: sync.playhead,
      seconds: seconds,
      rate: playback.rate,
      axis: sync.axis,
      distanceAxis: widget.distanceAxis,
      range: playback.loop ? window : bounds,
      loop: playback.loop,
    );
    controller.setPlayhead(step.playhead);
    if (!playback.loop) {
      final next = keepUpWindow(
        window: window,
        bounds: bounds,
        playhead: step.playhead,
      );
      if (next != null) controller.showWindow(next, bounds: bounds);
    }
    if (step.ended) _playback.pause();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playbackProvider.select((s) => s.playing), (_, playing) {
      playing ? _start() : _stop();
    });
    return widget.child;
  }
}

/// ▶, rate, loop, where the lap is, and the scrubber.
class TransportBar extends ConsumerWidget {
  const TransportBar({
    super.key,
    required this.bounds,
    required this.formatDomain,
    this.markers = const [],
    this.trailing = const [],
    this.compactTrailing = const [],
  });

  /// Below this width the bar drops the loop toggle, and [compactTrailing]
  /// stands in for [trailing]: the scrubber keeps room to be dragged.
  static const compactBelow = 620.0;

  final ChartViewport bounds;

  /// The readout of where the playhead is: `1 234 m`, `1:12.448`.
  final String Function(double) formatDomain;

  /// `(position, label)`: the sector boundaries, ticked on the scrubber.
  final List<(double, String)> markers;

  /// What follows the scrubber: the gap, the axis switch.
  final List<Widget> trailing;

  /// [trailing] for a narrow bar.
  final List<Widget> compactTrailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) =>
        _bar(context, ref, compact: constraints.maxWidth < compactBelow),
  );

  Widget _bar(BuildContext context, WidgetRef ref, {required bool compact}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final (state: sync, :owns) = watchChartSync(ref, context);
    final playhead = sync.playhead;
    final rate = playback.rate;
    final rateText = rate < 1
        ? '×${rate.toString().replaceFirst('0.', '.')}'
        : '×${rate.toStringAsFixed(0)}';

    return Row(
      children: [
        AppTooltip(
          message: playback.playing ? 'Pause (Space)' : 'Play (Space)',
          child: IconButton.filledTonal(
            onPressed: owns ? controller.toggle : null,
            icon: AnimatedSwitcher(
              duration: AppMotion.duration(context, AppDurations.fast),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                playback.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                key: ValueKey(playback.playing),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        AppTooltip(
          message: 'Playback speed',
          child: TextButton(
            onPressed: controller.cycleRate,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 36),
              shape: AppRadii.squircle(AppRadii.sm),
              foregroundColor: rate == 1
                  ? scheme.onSurfaceVariant
                  : scheme.primary,
            ),
            child: Text(rateText, style: AppTextStyles.numeral),
          ),
        ),
        if (!compact)
          AppTooltip(
            message: playback.loop
                ? 'Looping the trace window'
                : 'Loop the trace window',
            child: IconButton(
              onPressed: () => controller.setLoop(!playback.loop),
              isSelected: playback.loop,
              icon: const Icon(Icons.repeat_rounded, size: 18),
              selectedIcon: Icon(
                Icons.repeat_on_rounded,
                size: 18,
                color: scheme.primary,
              ),
            ),
          ),
        const SizedBox(width: 8),
        SizedBox(
          width: compact ? 72 : 84,
          child: Text(
            formatDomain(playhead ?? bounds.start),
            textAlign: TextAlign.right,
            style: AppTextStyles.numeral.copyWith(
              color: playhead == null
                  ? scheme.onSurfaceVariant
                  : scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: IgnorePointer(
            ignoring: !owns,
            child: _Scrubber(
              bounds: bounds,
              window: sync.visible(bounds),
              playhead: playhead,
              markers: markers,
              onSeek: ref.read(chartSyncProvider.notifier).setPlayhead,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ...compact ? compactTrailing : trailing,
      ],
    );
  }
}

/// The whole lap as a track: the trace window lit, the played part filled,
/// a thumb at the playhead. A click or a drag puts the playhead there.
class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.bounds,
    required this.window,
    required this.playhead,
    required this.markers,
    required this.onSeek,
  });

  final ChartViewport bounds;
  final ChartViewport window;
  final double? playhead;
  final List<(double, String)> markers;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void seek(Offset local) =>
            onSeek(bounds.toDomain(local.dx.clamp(0.0, width), width));
        return Semantics(
          slider: true,
          label: 'Playhead',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => seek(d.localPosition),
              onHorizontalDragStart: (d) => seek(d.localPosition),
              onHorizontalDragUpdate: (d) => seek(d.localPosition),
              child: SizedBox(
                height: 32,
                child: CustomPaint(
                  painter: _ScrubberPainter(
                    bounds: bounds,
                    window: window,
                    playhead: playhead,
                    markers: markers,
                    track: scheme.onSurface.withValues(alpha: 0.12),
                    lit: scheme.onSurface.withValues(alpha: 0.24),
                    fill: scheme.primary,
                    thumb: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  const _ScrubberPainter({
    required this.bounds,
    required this.window,
    required this.playhead,
    required this.markers,
    required this.track,
    required this.lit,
    required this.fill,
    required this.thumb,
  });

  final ChartViewport bounds;
  final ChartViewport window;
  final double? playhead;
  final List<(double, String)> markers;
  final Color track;
  final Color lit;
  final Color fill;
  final Color thumb;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    double x(double domain) =>
        bounds.toPixels(domain, size.width).clamp(0.0, size.width);
    RRect bar(double from, double to, double height) => RRect.fromLTRBR(
      from,
      y - height / 2,
      to,
      y + height / 2,
      Radius.circular(height / 2),
    );

    canvas.drawRRect(bar(0, size.width, 4), Paint()..color = track);
    if (window != bounds) {
      canvas.drawRRect(
        bar(x(window.start), x(window.end), 8),
        Paint()..color = lit,
      );
    }
    final tick = Paint()
      ..color = thumb.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (final (at, _) in markers) {
      final mx = x(at);
      canvas.drawLine(Offset(mx, y - 7), Offset(mx, y + 7), tick);
    }
    final at = playhead;
    if (at == null) return;
    final px = x(at);
    canvas.drawRRect(bar(0, px, 4), Paint()..color = fill);
    canvas.drawCircle(Offset(px, y), 7, Paint()..color = fill);
    canvas.drawCircle(Offset(px, y), 3, Paint()..color = thumb);
  }

  @override
  bool shouldRepaint(_ScrubberPainter old) =>
      old.playhead != playhead ||
      old.window != window ||
      old.bounds != bounds ||
      old.markers != markers ||
      old.fill != fill;
}
