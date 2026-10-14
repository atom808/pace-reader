/// Where on the track (SPEC.md §8.13.5, §8.13.7): the lap's path with the
/// segments as numbered bands and the corners as chevrons.
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
import '../../driver_comparison/domain/segments.dart';
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
            caption: 'Bands are segments, chevrons are corners',
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
  final TechniqueMapPath map;
  final List<CountersteerEpisode> episodes;
  final StretchRef? active;
  final StretchRef? selected;

  @override
  ConsumerState<_TrackCanvas> createState() => _TrackCanvasState();
}

class _TrackCanvasState extends ConsumerState<_TrackCanvas>
    with SingleTickerProviderStateMixin {
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

  StretchRef? _hit(Offset local, Size size) {
    final map = widget.map;
    final fit = TrackFit.of(map.bounds, Offset.zero & size, padding: _padding);
    var best = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < map.points.length; i++) {
      final d = (fit.toPixels(map.points[i]) - local).distanceSquared;
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    if (best < 0 || bestDistance > 26 * 26) return null;
    final station = map.stations[best];
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

  static const _padding = 30.0;

  @override
  Widget build(BuildContext context) {
    final focus = ref.read(techniqueFocusStateProvider(widget.source).notifier);
    final scheme = Theme.of(context).colorScheme;
    final bounds = widget.map.bounds;
    final aspect = bounds.height <= 0
        ? 1.6
        : (bounds.width / bounds.height).clamp(0.9, 2.4);
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return MouseRegion(
            onHover: (e) => focus.hover(_hit(e.localPosition, size)),
            onExit: (_) => focus.hover(null),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTapUp: (e) {
                final hit = _hit(e.localPosition, size);
                focus.select(hit == widget.selected ? null : hit);
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: _TrackPainter(
                    map: widget.map,
                    segments: widget.course.segments,
                    corners: widget.course.corners?.corners ?? const [],
                    lift: Map.of(_lift),
                    activeCorner: widget.active?.corner,
                    episodes: [for (final e in widget.episodes) e.station],
                    ink: scheme.onSurface,
                    muted: scheme.onSurfaceVariant,
                    badge: AppColors.surfaceHigh,
                    slide: ChannelColors.resolve(context).steering,
                    padding: _padding,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.map,
    required this.segments,
    required this.corners,
    required this.lift,
    required this.activeCorner,
    required this.episodes,
    required this.ink,
    required this.muted,
    required this.badge,
    required this.slide,
    required this.padding,
  });

  final TechniqueMapPath map;
  final List<Segment> segments;
  final List<GeoCorner> corners;
  final Map<int, double> lift;
  final int? activeCorner;
  final List<double> episodes;
  final Color ink;
  final Color muted;
  final Color badge;
  final Color slide;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = TrackFit.of(map.bounds, Offset.zero & size, padding: padding);
    final pts = [for (final p in map.points) fit.toPixels(p)];
    if (pts.length < 2) return;
    final centre = fit.toPixels(map.bounds.center);

    int? segmentAt(double station) {
      for (final s in segments) {
        if (s.contains(station)) return s.number;
      }
      return null;
    }

    // Runs of consecutive points in one segment, each joined to the next
    // run's first point so the bands meet without a gap.
    final runs = <(int, List<Offset>)>[];
    for (var i = 0; i < pts.length; i++) {
      final s = segmentAt(map.stations[i]);
      if (s == null) continue;
      if (runs.isEmpty || runs.last.$1 != s) {
        if (runs.isNotEmpty) runs.last.$2.add(pts[i]);
        runs.add((s, [pts[i]]));
      } else {
        runs.last.$2.add(pts[i]);
      }
    }

    Path pathOf(List<Offset> run) {
      final p = Path()..moveTo(run.first.dx, run.first.dy);
      for (final o in run.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      return p;
    }

    final toneA = ink.withValues(alpha: 0.11);
    final toneB = ink.withValues(alpha: 0.30);
    final lifted = ink.withValues(alpha: 0.58);
    // Unlifted bands first, then lifted ones over them.
    final order = [...runs]
      ..sort((a, b) => (lift[a.$1] ?? 0).compareTo(lift[b.$1] ?? 0));
    for (final (s, run) in order) {
      final l = lift[s] ?? 0;
      final base = s.isOdd ? toneA : toneB;
      if (l > 0) {
        canvas.drawPath(
          pathOf(run),
          Paint()
            ..color = ink.withValues(alpha: 0.10 * l)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 22 * l
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawPath(
        pathOf(run),
        Paint()
          ..color = Color.lerp(base, lifted, l)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9 + 5 * l
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // The driven line itself, thin, over the bands.
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      line.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.surfaceBase.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // The start/finish line: the point where Lap Dist is smallest.
    var zero = 0;
    for (var i = 1; i < map.stations.length; i++) {
      if (map.stations[i] < map.stations[zero]) zero = i;
    }
    _crossTick(canvas, pts, zero, ink.withValues(alpha: 0.9));

    // Corner chevrons, on the inside of the turn, pointing the way of travel.
    for (final c in corners) {
      final i = map.indexAt(c.apex).clamp(1, pts.length - 2);
      final heading = pts[i + 1] - pts[i - 1];
      if (heading.distance == 0) continue;
      final h = heading / heading.distance;
      // Screen y grows down, so the left of travel is (h.dy, −h.dx).
      final left = Offset(h.dy, -h.dx);
      final inside = c.direction == TurnDirection.left ? left : -left;
      final isActive = c.number == activeCorner;
      final at = pts[i] + inside * (isActive ? 17 : 15);
      final s = isActive ? 6.5 : 4.5;
      if (isActive) {
        canvas.drawCircle(at, 10, Paint()..color = badge);
        canvas.drawCircle(
          at,
          10,
          Paint()
            ..color = ink.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      final chevron = Path()
        ..moveTo(at.dx - h.dx * s + left.dx * s, at.dy - h.dy * s + left.dy * s)
        ..lineTo(at.dx + h.dx * s * 0.6, at.dy + h.dy * s * 0.6)
        ..lineTo(
          at.dx - h.dx * s - left.dx * s,
          at.dy - h.dy * s - left.dy * s,
        );
      canvas.drawPath(
        chevron,
        Paint()
          ..color = isActive ? ink : ink.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 2 : 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Caught slides on the selected lap.
    for (final station in episodes) {
      final p = pts[map.indexAt(station).clamp(0, pts.length - 1)];
      canvas.drawCircle(
        p,
        6.5,
        Paint()
          ..color = slide
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // Segment numbers, pushed outward from the map's centre.
    for (final (s, run) in runs) {
      if (run.length < 2) continue;
      // A segment split by the line has two runs; number the longer one.
      final longest = runs
          .where((r) => r.$1 == s)
          .reduce((a, b) => b.$2.length > a.$2.length ? b : a);
      if (!identical(longest.$2, run)) continue;
      final mid = run[run.length ~/ 2];
      final out = mid - centre;
      final push = out.distance == 0 ? Offset.zero : out / out.distance * 17;
      final at = mid + push;
      final l = lift[s] ?? 0;
      canvas.drawCircle(at, 10, Paint()..color = Color.lerp(badge, ink, l)!);
      canvas.drawCircle(
        at,
        10,
        Paint()
          ..color = ink.withValues(alpha: 0.35 + 0.4 * l)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '$s',
          style: AppTextStyles.numeral.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color.lerp(ink, AppColors.surfaceBase, l),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
    }
  }

  void _crossTick(Canvas canvas, List<Offset> pts, int i, Color color) {
    final a = pts[(i - 1).clamp(0, pts.length - 1)];
    final b = pts[(i + 1).clamp(0, pts.length - 1)];
    final h = b - a;
    if (h.distance == 0) return;
    final n = Offset(h.dy, -h.dx) / h.distance;
    canvas.drawLine(
      pts[i] - n * 9,
      pts[i] + n * 9,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.map != map ||
      old.activeCorner != activeCorner ||
      !_sameLift(old.lift, lift) ||
      old.episodes.length != episodes.length ||
      (episodes.isNotEmpty && old.episodes.first != episodes.first) ||
      old.ink != ink;

  static bool _sameLift(Map<int, double> a, Map<int, double> b) {
    if (a.length != b.length) return false;
    for (final MapEntry(:key, :value) in a.entries) {
      if (b[key] != value) return false;
    }
    return true;
  }
}
