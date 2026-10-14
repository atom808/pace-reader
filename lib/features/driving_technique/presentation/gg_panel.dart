/// The friction circle (SPEC.md §8.13.3 "Friction circle", §8.13.7 "G-G
/// panel", §8.13.8): the selected lap's 10 Hz G over the session's density
/// grid and envelope.
///
/// One painter draws the lap, driven by animations rather than a widget per
/// point. On a lap change each point travels from where the previous lap was
/// at the same `Lap Dist`, so the eye sees how the lap differed. Hovering a
/// segment or corner fades the lap's other points to a quarter.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/technique_providers.dart';
import '../data/technique_reads.dart';
import '../domain/lap_technique.dart';
import '../domain/technique_thresholds.dart';
import 'technique_widgets.dart';

/// The lap change's morph (§8.13.8 "Lap change").
const _morph = Duration(milliseconds: 450);

/// What the points outside a hovered stretch fade to.
const _faded = 0.25;

/// Bins with fewer samples than this leave the envelope to their
/// neighbours: a p99 of a handful of samples is noise.
const _envelopeMinimumSamples = 20;

class GgPanel extends HookConsumerWidget {
  const GgPanel({
    super.key,
    required this.source,
    required this.overview,
    required this.lap,
  });

  final TelemetrySource source;
  final TechniqueOverview overview;
  final LapTechnique lap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final band = useState(SpeedBand.all);
    final gg = overview.gg;
    final points = ref.watch(techniqueLapPointsProvider(source, lap.lap.index));
    final course = ref.watch(techniqueCourseProvider(source)).value;
    final active = ref.watch(
      techniqueFocusStateProvider(source).select((f) => f.active),
    );
    final bands = gg == null
        ? const <SpeedBand>[]
        : [
            for (final b in SpeedBand.values)
              if ((gg.envelope[b]?.length ?? 0) >= 12) b,
          ];

    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Friction circle',
            caption: 'Lap ${lap.lap.displayNumber} over the session',
            trailing: const InfoPopoverButton(
              title: 'Friction circle',
              paragraphs: [
                'Each dot is a tenth of a second of this lap: how hard the car '
                    'was braking or accelerating (up and down) and turning '
                    '(left and right).',
                'The shaded grid underneath is every racing lap of the '
                    'session. The outline is the session\'s 99th percentile '
                    'in each direction: the grip the car showed it had, at '
                    'the speeds you pick.',
                'Grip used is this lap\'s average share of the session\'s '
                    'limit over the samples above 0.5 G, when the car was '
                    'actually loaded. It is measured against this session '
                    'only, so it compares laps, not cars or tracks.',
              ],
              footer: [
                'Its rank correlation with lap time was negative in all 16 '
                    'sessions measured.',
              ],
            ),
          ),
          if (gg == null || gg.envelope.isEmpty)
            const AbsenceNote(
              'This file has no G channels on the 10 Hz frame, so there is no '
              'friction circle to draw.',
            )
          else ...[
            if (bands.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BandSelector(
                    bands: bands,
                    selected: bands.contains(band.value)
                        ? band.value
                        : bands.last,
                    onChanged: (b) => band.value = b,
                  ),
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final side = math.min(constraints.maxWidth, 440.0);
                return Center(
                  child: SizedBox.square(
                    dimension: side,
                    child: _GgCanvas(
                      gg: gg,
                      band: bands.contains(band.value)
                          ? band.value
                          : SpeedBand.all,
                      points: points.value,
                      active: active,
                      contains: _stretchTest(course, active),
                    ),
                  ),
                );
              },
            ),
            if (points.hasError)
              AbsenceNote('This lap\'s G could not be read: ${points.error}'),
            const SizedBox(height: 10),
            _Legend(band: band.value),
            const SizedBox(height: 10),
            Wrap(
              spacing: 22,
              runSpacing: 6,
              children: [
                _Fact(
                  label: 'Sustained peak',
                  value: lap.gg?.sustainedPeak,
                  decimals: 2,
                  unit: 'G',
                ),
                _Fact(
                  label: 'Grip used',
                  value: TechniqueMeasure.gripUsed.of(lap),
                  decimals: 1,
                  unit: '%',
                ),
                if (gg.e case final e?)
                  _Fact(
                    label: 'Session limit',
                    value: e,
                    decimals: 2,
                    unit: 'G',
                  ),
              ],
            ),
            if (active != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Bright points: ${_stretchName(course, active)}.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Whether a station lies in [active], or null for every station.
bool Function(double)? _stretchTest(
  TechniqueCourse? course,
  StretchRef? active,
) {
  if (course == null || active == null) return null;
  final corner = active.corner;
  if (corner != null) {
    final c = course.corners?.corners
        .where((c) => c.number == corner)
        .firstOrNull;
    return c?.contains;
  }
  final s = course.segments
      .where((s) => s.number == active.segment)
      .firstOrNull;
  return s?.contains;
}

String _stretchName(TechniqueCourse? course, StretchRef active) {
  final segment = course?.segments
      .where((s) => s.number == active.segment)
      .firstOrNull;
  final name = segment?.name ?? 'Seg ${active.segment}';
  final corner = active.corner;
  if (corner == null || segment == null || course == null) return name;
  final inSegment = course.cornersIn(segment);
  final k = inSegment.indexWhere((c) => c.number == corner);
  if (k < 0) return name;
  final c = inSegment[k];
  return '$name · corner ${k + 1} · ${c.direction.letter}, '
      '${c.radius.toStringAsFixed(0)} m';
}

class _BandSelector extends StatelessWidget {
  const _BandSelector({
    required this.bands,
    required this.selected,
    required this.onChanged,
  });

  final List<SpeedBand> bands;
  final SpeedBand selected;
  final ValueChanged<SpeedBand> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<SpeedBand>(
    segments: [
      for (final b in bands)
        ButtonSegment(
          value: b,
          tooltip: 'The session\'s limit at ${b.label}',
          label: Text(switch (b) {
            SpeedBand.slow => '< 150',
            SpeedBand.medium => '150–200',
            SpeedBand.fast => '≥ 200',
            SpeedBand.all => 'All',
          }),
        ),
    ],
    selected: {selected},
    showSelectedIcon: false,
    style: ButtonStyle(
      visualDensity: VisualDensity.compact,
      shape: WidgetStatePropertyAll(AppRadii.squircle(AppRadii.sm)),
      textStyle: WidgetStatePropertyAll(
        AppTextStyles.numeral.copyWith(fontSize: 11.5),
      ),
    ),
    onSelectionChanged: (s) => onChanged(s.first),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    required this.decimals,
    required this.unit,
  });

  final String label;
  final double? value;
  final int decimals;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        const SizedBox(height: 2),
        RollingNumber(
          value: value,
          format: (v) => v.toStringAsFixed(decimals),
          style: AppTextStyles.numeral.copyWith(fontSize: 17),
          unit: unit,
          unitStyle: AppTextStyles.numeral.copyWith(fontSize: 11, color: muted),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.band});

  final SpeedBand band;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final c = ChannelColors.resolve(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: muted);
    Widget dot(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: style),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        dot(c.throttle, 'on throttle'),
        dot(c.brake, 'on the brake'),
        dot(c.steering, 'neither'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 2,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              band == SpeedBand.all
                  ? 'session limit (p99)'
                  : 'session limit, ${band.label}',
              style: style,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: ShapeDecoration(
                shape: AppRadii.squircle(2),
                color: c.line.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 6),
            Text('every racing lap', style: style),
          ],
        ),
      ],
    );
  }
}

/// The circle itself: a still background (rings, the session grid, the
/// envelope) under the lap's moving points, each behind its own repaint
/// boundary.
class _GgCanvas extends StatefulWidget {
  const _GgCanvas({
    required this.gg,
    required this.band,
    required this.points,
    required this.active,
    required this.contains,
  });

  final GgReads gg;
  final SpeedBand band;

  /// Null while the lap's points load: the previous lap stays up.
  final List<GgPoint>? points;
  final StretchRef? active;
  final bool Function(double station)? contains;

  @override
  State<_GgCanvas> createState() => _GgCanvasState();
}

class _GgCanvasState extends State<_GgCanvas> with TickerProviderStateMixin {
  late final _morphing = AnimationController(vsync: this, value: 1);
  late final _fading = AnimationController(vsync: this, value: 1);
  late final _banding = AnimationController(vsync: this, value: 1);
  late final _morphCurve = CurvedAnimation(
    parent: _morphing,
    curve: AppCurves.entrance,
  );
  late final _bandCurve = CurvedAnimation(
    parent: _banding,
    curve: AppCurves.entrance,
  );
  final _cloud = _Cloud();
  late _Envelopes _envelopes = _Envelopes.of(widget.gg);
  late Float64List _bandFrom = _envelopes.radii(widget.band);
  late Float64List _bandTo = _bandFrom;
  List<GgPoint>? _shown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Here rather than in initState: the first morph's duration reads the
    // reduced-motion setting from the MediaQuery.
    final points = widget.points;
    if (_shown == null && points != null) _show(points, first: true);
  }

  @override
  void didUpdateWidget(_GgCanvas old) {
    super.didUpdateWidget(old);
    if (!identical(widget.gg, old.gg)) {
      _envelopes = _Envelopes.of(widget.gg);
      _bandFrom = _bandTo = _envelopes.radii(widget.band);
    }
    final points = widget.points;
    if (points != null && !identical(points, _shown)) {
      _show(points, first: _shown == null);
    } else if (widget.active != old.active) {
      _cloud.refocus(widget.contains, _fading.value);
      _run(_fading, AppDurations.fast);
    }
    if (widget.band != old.band) {
      _bandFrom = _lerpRadii(_bandFrom, _bandTo, _bandCurve.value);
      _bandTo = _envelopes.radii(widget.band);
      _run(_banding, AppDurations.medium);
    }
  }

  void _show(List<GgPoint> points, {required bool first}) {
    _shown = points;
    _cloud.retarget(
      points,
      progress: _morphCurve.value,
      contains: widget.contains,
      first: first,
    );
    _run(_morphing, _morph);
  }

  void _run(AnimationController controller, Duration duration) {
    final d = AppMotion.duration(context, duration);
    if (d == Duration.zero) {
      controller.value = 1;
      return;
    }
    controller
      ..duration = d
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _morphCurve.dispose();
    _bandCurve.dispose();
    _morphing.dispose();
    _fading.dispose();
    _banding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = ChannelColors.resolve(context);
    final extent = _envelopes.extent;
    final label = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.4,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _BackgroundPainter(
              gg: widget.gg,
              extent: extent,
              from: _bandFrom,
              to: _bandTo,
              allBand: _envelopes.radii(SpeedBand.all),
              showAll: widget.band != SpeedBand.all,
              progress: _bandCurve,
              ring: scheme.outlineVariant,
              ringLabel: scheme.onSurfaceVariant,
              density: c.line,
              envelope: scheme.onSurface,
            ),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: _PointsPainter(
              cloud: _cloud,
              extent: extent,
              morph: _morphCurve,
              fade: _fading,
              colors: [c.throttle, c.brake, c.steering],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Text('BRAKING', style: label),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Text('ACCELERATING', style: label),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('← LEFT', style: label),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text('RIGHT →', style: label),
        ),
      ],
    );
  }
}

Float64List _lerpRadii(Float64List a, Float64List b, double t) =>
    Float64List.fromList([
      for (var i = 0; i < a.length; i++) a[i] + (b[i] - a[i]) * t,
    ]);

/// The session's envelope per speed band, as 36 radii with the thin bins
/// filled from their neighbours.
class _Envelopes {
  _Envelopes(this._radii, this.extent);

  factory _Envelopes.of(GgReads gg) {
    final radii = <SpeedBand, Float64List>{};
    var top = 0.0;
    for (final MapEntry(key: band, value: bins) in gg.envelope.entries) {
      final r = Float64List(36);
      final known = <int>[];
      for (var k = 0; k < 36; k++) {
        final bin = bins[k];
        if (bin != null && bin.n >= _envelopeMinimumSamples) {
          r[k] = bin.g;
          known.add(k);
          if (bin.g > top) top = bin.g;
        }
      }
      if (known.isEmpty) continue;
      // Each missing bin takes the straight line between its nearest known
      // neighbours round the circle.
      for (var k = 0; k < 36; k++) {
        if (known.contains(k)) continue;
        var before = k;
        var stepsBack = 0;
        do {
          before = (before + 35) % 36;
          stepsBack++;
        } while (!known.contains(before));
        var after = k;
        var stepsOn = 0;
        do {
          after = (after + 1) % 36;
          stepsOn++;
        } while (!known.contains(after));
        final t = stepsBack / (stepsBack + stepsOn);
        r[k] = r[before] + (r[after] - r[before]) * t;
      }
      radii[band] = r;
    }
    // A round half-G past the largest limit, so the outline never touches
    // the edge and the rings fall on round numbers.
    final extent = math.max(1.0, ((top * 1.08) / 0.5).ceil() * 0.5);
    return _Envelopes(radii, extent);
  }

  final Map<SpeedBand, Float64List> _radii;

  /// The plot's radius, G.
  final double extent;

  Float64List radii(SpeedBand band) =>
      _radii[band] ?? _radii[SpeedBand.all] ?? Float64List(36);
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({
    required this.gg,
    required this.extent,
    required this.from,
    required this.to,
    required this.allBand,
    required this.showAll,
    required this.progress,
    required this.ring,
    required this.ringLabel,
    required this.density,
    required this.envelope,
  }) : super(repaint: progress);

  final GgReads gg;
  final double extent;
  final Float64List from;
  final Float64List to;
  final Float64List allBand;
  final bool showAll;
  final Animation<double> progress;
  final Color ring;
  final Color ringLabel;
  final Color density;
  final Color envelope;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 18;
    final scale = radius / extent;

    // Rings every half G, the whole ones a touch stronger and labelled.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var g = 0.5; g <= extent + 1e-9; g += 0.5) {
      final whole = (g - g.roundToDouble()).abs() < 1e-9;
      ringPaint.color = ring.withValues(alpha: whole ? 0.9 : 0.45);
      canvas.drawCircle(centre, g * scale, ringPaint);
      if (whole) {
        final text = TextPainter(
          text: TextSpan(
            text: '${g.toStringAsFixed(0)} G',
            style: AppTextStyles.numeral.copyWith(
              fontSize: 9.5,
              color: ringLabel,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final at = centre + Offset.fromDirection(-math.pi / 4, g * scale);
        text.paint(canvas, at + const Offset(3, -12));
        text.dispose();
      }
    }
    final axis = Paint()
      ..color = ring.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    canvas
      ..drawLine(centre - Offset(radius, 0), centre + Offset(radius, 0), axis)
      ..drawLine(centre - Offset(0, radius), centre + Offset(0, radius), axis);

    // The session's samples: one hue, the alpha on a log ramp so the
    // sparse edge still shows against the dense middle.
    if (gg.density.isNotEmpty) {
      var most = 1;
      for (final n in gg.density.values) {
        if (n > most) most = n;
      }
      const levels = 8;
      final buckets = List.generate(levels, (_) => <double>[]);
      final top = math.log(1 + most);
      final cell = TechniqueThresholds.ggCell;
      for (final MapEntry(key: (x, y), value: n) in gg.density.entries) {
        final level = ((levels - 1) * math.log(1 + n) / top).round();
        buckets[level]
          ..add(centre.dx + (x + 0.5) * cell * scale)
          ..add(centre.dy - (y + 0.5) * cell * scale);
      }
      final paint = Paint()
        ..strokeCap = StrokeCap.square
        ..strokeWidth = cell * scale + 0.4;
      for (var level = 0; level < levels; level++) {
        if (buckets[level].isEmpty) continue;
        paint.color = density.withValues(
          alpha: 0.07 + 0.43 * (level + 1) / levels,
        );
        canvas.drawRawPoints(
          ui.PointMode.points,
          Float32List.fromList(buckets[level]),
          paint,
        );
      }
    }

    if (showAll) {
      canvas.drawPath(
        _outline(allBand, centre, scale),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = envelope.withValues(alpha: 0.22),
      );
    }
    final radii = _lerpRadii(from, to, progress.value);
    final path = _outline(radii, centre, scale);
    canvas
      ..drawPath(path, Paint()..color = envelope.withValues(alpha: 0.035))
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round
          ..color = envelope.withValues(alpha: 0.72),
      );
  }

  /// A closed Catmull-Rom curve through each bin's centre.
  static Path _outline(Float64List radii, Offset centre, double scale) {
    final points = <Offset>[
      for (var k = 0; k < 36; k++)
        centre +
            Offset.fromDirection(
              // Bin k spans k×10° − 180° of atan2(braking, right); screen y
              // points down, so the angle flips.
              -((k + 0.5) * math.pi / 18 - math.pi),
              radii[k] * scale,
            ),
    ];
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var k = 0; k < 36; k++) {
      final p0 = points[(k + 35) % 36];
      final p1 = points[k];
      final p2 = points[(k + 1) % 36];
      final p3 = points[(k + 2) % 36];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      !identical(old.gg, gg) ||
      old.extent != extent ||
      !identical(old.from, from) ||
      !identical(old.to, to) ||
      old.showAll != showAll ||
      old.ring != ring ||
      old.density != density ||
      old.envelope != envelope;
}

/// The lap's points mid-flight: where each starts and ends, in G, and how
/// bright it is.
class _Cloud {
  Float64List stations = Float64List(0);

  /// Right (−lateral) and braking, G.
  Float32List fromX = Float32List(0);
  Float32List fromY = Float32List(0);
  Float32List toX = Float32List(0);
  Float32List toY = Float32List(0);

  /// 0 throttle, 1 brake, 2 neither.
  Uint8List kind = Uint8List(0);
  Float32List alphaFrom = Float32List(0);
  Float32List alphaTo = Float32List(0);

  /// The first lap shown fades in rather than flying from nowhere.
  bool appearing = false;

  /// Bumped on every change, so a change that lands without an animation
  /// (reduced motion) still repaints.
  int revision = 0;

  int get length => toX.length;

  /// Moves to [points]: each starts where the shown cloud is, at
  /// [progress], nearest the same `Lap Dist`.
  void retarget(
    List<GgPoint> points, {
    required double progress,
    required bool Function(double)? contains,
    required bool first,
  }) {
    final n = points.length;
    final oldStations = stations;
    final oldX = Float32List(length);
    final oldY = Float32List(length);
    for (var i = 0; i < length; i++) {
      oldX[i] = fromX[i] + (toX[i] - fromX[i]) * progress;
      oldY[i] = fromY[i] + (toY[i] - fromY[i]) * progress;
    }
    final order = List<int>.generate(oldStations.length, (i) => i)
      ..sort((a, b) => oldStations[a].compareTo(oldStations[b]));

    stations = Float64List(n);
    fromX = Float32List(n);
    fromY = Float32List(n);
    toX = Float32List(n);
    toY = Float32List(n);
    kind = Uint8List(n);
    alphaTo = Float32List(n);
    for (var i = 0; i < n; i++) {
      final p = points[i];
      stations[i] = p.station;
      toX[i] = -p.lateral;
      toY[i] = p.longitudinal;
      final brake = (p.brake ?? 0) > TechniqueThresholds.applied;
      final throttle = (p.throttle ?? 0) > TechniqueThresholds.applied;
      kind[i] = brake
          ? 1
          : throttle
          ? 0
          : 2;
      alphaTo[i] = contains == null || contains(p.station) ? 1 : _faded;
      if (order.isEmpty) {
        fromX[i] = toX[i];
        fromY[i] = toY[i];
      } else {
        final j = order[_nearest(order, oldStations, p.station)];
        fromX[i] = oldX[j];
        fromY[i] = oldY[j];
      }
    }
    alphaFrom = Float32List.fromList(alphaTo);
    appearing = first || order.isEmpty;
    revision++;
  }

  /// Re-aims each point's brightness at [contains], starting from where the
  /// running fade has it, so moving across stretches chains rather than
  /// restarting.
  void refocus(bool Function(double)? contains, double progress) {
    final now = Float32List(length);
    for (var i = 0; i < length; i++) {
      now[i] = alphaFrom[i] + (alphaTo[i] - alphaFrom[i]) * progress;
      alphaTo[i] = contains == null || contains(stations[i]) ? 1 : _faded;
    }
    alphaFrom = now;
    revision++;
  }

  /// The position in [order] of the station nearest [station].
  static int _nearest(List<int> order, Float64List stations, double station) {
    var lo = 0;
    var hi = order.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (stations[order[mid]] < station) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0 &&
        (stations[order[lo - 1]] - station).abs() <
            (stations[order[lo]] - station).abs()) {
      return lo - 1;
    }
    return lo;
  }
}

class _PointsPainter extends CustomPainter {
  _PointsPainter({
    required this.cloud,
    required this.extent,
    required this.morph,
    required this.fade,
    required this.colors,
  }) : revision = cloud.revision,
       super(repaint: Listenable.merge([morph, fade]));

  final _Cloud cloud;
  final int revision;
  final double extent;
  final Animation<double> morph;
  final Animation<double> fade;

  /// Throttle, brake, neither.
  final List<Color> colors;

  /// Brightness steps the points are drawn in: a handful of batched draws
  /// rather than one per point.
  static const _levels = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final n = cloud.length;
    if (n == 0) return;
    final centre = size.center(Offset.zero);
    final scale = (size.shortestSide / 2 - 18) / extent;
    final t = morph.value;
    final f = fade.value;
    final buckets = 3 * _levels;
    final counts = Int32List(buckets + 1);
    final bucketOf = Uint8List(n);
    for (var i = 0; i < n; i++) {
      final a =
          cloud.alphaFrom[i] + (cloud.alphaTo[i] - cloud.alphaFrom[i]) * f;
      final level = (((a - _faded) / (1 - _faded)) * (_levels - 1))
          .round()
          .clamp(0, _levels - 1);
      final b = cloud.kind[i] * _levels + level;
      bucketOf[i] = b;
      counts[b + 1]++;
    }
    for (var b = 0; b < buckets; b++) {
      counts[b + 1] += counts[b];
    }
    final start = Int32List.fromList(counts);
    final xy = Float32List(2 * n);
    for (var i = 0; i < n; i++) {
      final x = cloud.fromX[i] + (cloud.toX[i] - cloud.fromX[i]) * t;
      final y = cloud.fromY[i] + (cloud.toY[i] - cloud.fromY[i]) * t;
      final slot = start[bucketOf[i]]++;
      xy[2 * slot] = centre.dx + x * scale;
      xy[2 * slot + 1] = centre.dy - y * scale;
    }
    final appear = cloud.appearing ? t : 1.0;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.4;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var b = 0; b < buckets; b++) {
      final from = counts[b];
      final to = counts[b + 1];
      if (to == from) continue;
      final level = b % _levels;
      final alpha = _faded + (1 - _faded) * level / (_levels - 1);
      paint.color = colors[b ~/ _levels].withValues(
        alpha: 0.82 * alpha * appear,
      );
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(xy, 2 * from, 2 * to),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PointsPainter old) =>
      !identical(old.cloud, cloud) ||
      old.revision != revision ||
      old.extent != extent ||
      !listEquals(old.colors, colors);
}

/// Where [painter] puts the lap's points at its morph's current progress,
/// in G (right, braking); null for any other painter. The painter is
/// private, so this is how a test sees the cloud land (§8.13.8 "Verified").
@visibleForTesting
List<Offset>? ggPointsNow(CustomPainter? painter) {
  if (painter is! _PointsPainter) return null;
  final cloud = painter.cloud;
  final t = painter.morph.value;
  return [
    for (var i = 0; i < cloud.length; i++)
      Offset(
        cloud.fromX[i] + (cloud.toX[i] - cloud.fromX[i]) * t,
        cloud.fromY[i] + (cloud.toY[i] - cloud.fromY[i]) * t,
      ),
  ];
}
