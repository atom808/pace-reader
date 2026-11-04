/// Where on the track (SPEC.md §8.13.5, §8.13.7): the lap's path on the inset
/// map stage, with the segments as numbered bands and the corners as
/// chevrons.
///
/// The two are told apart by shape, never by colour (§8.13.8): bands
/// alternate two neutral tones and carry a number, because a segment is
/// *where the time goes*; a chevron sits on the inside of each corner's apex
/// pointing the way the car travels, because a corner is *what the road
/// does*. Hovering either lifts its band and links the whole screen.
library;

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/technique_providers.dart';
import '../domain/corner_table.dart';
import '../domain/countersteer.dart';
import '../domain/geometric_corners.dart';
import 'technique_widgets.dart';

class TrackPanel extends ConsumerWidget {
  const TrackPanel({super.key, required this.source, required this.episodes});

  final TelemetrySource source;

  /// The selected lap's caught slides, marked where they began.
  final List<CountersteerEpisode> episodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(techniqueCourseProvider(source));
    final focus = ref.watch(techniqueFocusStateProvider(source));
    final theme = Theme.of(context);
    final active = focus.active;
    final c = course.value;
    String? caption;
    if (c != null && active != null) {
      final segment = c.segments
          .where((s) => s.number == active.segment)
          .firstOrNull;
      if (segment != null) {
        final corner = active.corner == null
            ? null
            : c.corners?.corners
                  .where((k) => k.number == active.corner)
                  .firstOrNull;
        final inSegment = c.cornersIn(segment);
        caption = corner == null
            ? '${segment.name} · ${segment.start.toStringAsFixed(0)}–'
                  '${segment.end.toStringAsFixed(0)} m · '
                  '${inSegment.length} corner${inSegment.length == 1 ? '' : 's'}'
            : cornerLabel(corner, segment, inSegment.indexOf(corner) + 1);
      }
    }
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Where on the track',
            caption:
                'Bands are segments, chevrons are corners · drag to pan, '
                'Ctrl+scroll to zoom',
            trailing: FadeOnChange(
              value: caption,
              duration: AppMotion.duration(context, AppDurations.fast),
              child: Text(
                caption ?? '',
                style: AppTextStyles.numeral.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          AsyncValueView<TechniqueCourse>(
            value: course,
            loading: (context) => const AspectRatio(
              aspectRatio: 1.7,
              child: Skeleton(height: double.infinity, radius: AppRadii.md),
            ),
            data: (context, course) {
              final map = course.map;
              if (map == null || course.table == null) {
                return AbsenceNote(
                  course.unavailable ??
                      'No map: the recording lacks the position channels.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TrackCanvas(
                    source: source,
                    course: course,
                    map: map,
                    episodes: episodes,
                    active: active,
                    selected: focus.selected,
                  ),
                  const SizedBox(height: 10),
                  const _Legend(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.bodySmall?.copyWith(color: muted);
    Widget swatch(Widget glyph, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        const SizedBox(width: 6),
        Text(text, style: style),
      ],
    );
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        swatch(
          Container(
            width: 18,
            height: 7,
            decoration: ShapeDecoration(
              shape: AppRadii.squircle(4),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.22),
            ),
          ),
          'segment: where the time goes',
        ),
        swatch(
          Icon(Icons.chevron_right, size: 16, color: muted),
          'corner: what the road does',
        ),
        swatch(
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: ChannelColors.resolve(context).steering,
                width: 1.5,
              ),
            ),
          ),
          'caught slide on this lap',
        ),
      ],
    );
  }
}

/// The course on the inset stage (map stage proposal §9): segments as bands
/// under the line, corners as chevrons, segment numbers in discs, and this
/// lap's caught slides ringed. The pointer over the line focuses the
/// segment or corner there; a click selects it.
class _TrackCanvas extends ConsumerStatefulWidget {
  const _TrackCanvas({
    required this.source,
    required this.course,
    required this.map,
    required this.episodes,
    required this.active,
    required this.selected,
  });

  final TelemetrySource source;
  final TechniqueCourse course;
  final TrackPath map;
  final List<CountersteerEpisode> episodes;
  final StretchRef? active;
  final StretchRef? selected;

  @override
  ConsumerState<_TrackCanvas> createState() => _TrackCanvasState();
}

class _TrackCanvasState extends ConsumerState<_TrackCanvas>
    with SingleTickerProviderStateMixin
    implements StageHitTarget {
  /// How far each segment's band is lifted, 0..1, eased toward its target
  /// every frame: moving across segments hands the lift from one band to the
  /// next without either restarting from zero (§8.13.8 "Linking").
  final Map<int, double> _lift = {};
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  /// The time constant of the ease, so a lift settles in about 120 ms.
  static const _tau = 0.04;

  int? get _target => widget.active?.segment;

  @override
  void didUpdateWidget(_TrackCanvas old) {
    super.didUpdateWidget(old);
    if (old.active?.segment != widget.active?.segment) _start();
  }

  void _start() {
    if (AppMotion.reduced(context)) {
      _lift
        ..clear()
        ..addAll({?_target: 1.0});
      setState(() {});
      return;
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final k = 1 - math.exp(-dt / _tau);
    var moving = false;
    final keys = {..._lift.keys, ?_target};
    for (final s in keys) {
      final goal = s == _target ? 1.0 : 0.0;
      final now = _lift[s] ?? 0;
      final next = now + (goal - now) * k;
      if ((goal - next).abs() < 0.004) {
        if (goal == 0) {
          _lift.remove(s);
        } else {
          _lift[s] = 1;
        }
      } else {
        _lift[s] = next;
        moving = true;
      }
    }
    setState(() {});
    if (!moving) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// The segment, or the corner within it, at `Lap Dist` [station].
  StretchRef? _refAt(double? station) {
    if (station == null) return null;
    final segment = widget.course.segments
        .where((s) => s.contains(station))
        .firstOrNull;
    if (segment == null) return null;
    final corner = widget.course.corners?.corners
        .where((c) => c.contains(station))
        .firstOrNull;
    return corner == null
        ? StretchRef.segment(segment.number)
        : StretchRef.corner(segment.number, corner.number);
  }

  TechniqueFocusState get _focus =>
      ref.read(techniqueFocusStateProvider(widget.source).notifier);

  @override
  void hover(double? station) => _focus.hover(_refAt(station));

  @override
  void tap(double? station) {
    final hit = _refAt(station);
    _focus.select(hit == widget.selected ? null : hit);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = ChartPalette.of(context, series: scheme.onSurface);
    final map = widget.map;
    final bounds = map.projection.boundsMetres;
    final aspect = bounds.height <= 0
        ? 1.6
        : (bounds.width / bounds.height).clamp(0.9, 2.4);
    final segments = widget.course.segments;
    final ink = scheme.onSurface;
    // The start/finish line: where `Lap Dist` is zero.
    final zero = indexAtStation(map, 0)?.round();
    return AspectRatio(
      aspectRatio: aspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: MapStage.inset(
          path: map,
          colouring: SolidColouring(
            AppColors.surfaceBase.withValues(alpha: 0.7),
          ),
          strokeWidth: 1.2,
          markers: [if (zero != null) (zero, '')],
          hits: this,
          underlays: [
            TrackBandLayer(
              path: map,
              ink: ink,
              bands: [
                for (final s in segments)
                  TrackBand(
                    from: s.start,
                    to: s.end,
                    alternate: s.number.isEven,
                    lift: _lift[s.number] ?? 0,
                  ),
              ],
            ),
          ],
          overlays: [
            TrackChevronLayer(
              path: map,
              ink: ink,
              badge: AppColors.surfaceHigh,
              chevrons: [
                for (final c in widget.course.corners?.corners ?? const [])
                  TrackChevron(
                    apex: c.apex,
                    leftHander: c.direction == TurnDirection.left,
                    active: c.number == widget.active?.corner,
                  ),
              ],
            ),
            TrackMarkLayer(
              ink: ChannelColors.resolve(context).steering,
              surface: palette.surface,
              marks: [
                for (final e in widget.episodes)
                  if (map.positionAtStation(e.station) case final at?)
                    TrackMark(at: at, shape: TrackMarkShape.ring),
              ],
            ),
            TrackLabelLayer(
              path: map,
              palette: palette,
              ink: ink,
              radius: 10,
              labels: [
                for (final s in segments)
                  if ((s.start + s.end).isFinite)
                    TrackLabel(
                      station: (s.start + s.end) / 2,
                      text: '${s.number}',
                      lift: _lift[s.number] ?? 0,
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
