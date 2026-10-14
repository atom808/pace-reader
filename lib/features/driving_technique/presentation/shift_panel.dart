/// The shift panel (SPEC.md §8.13.3 "Shifts", §8.13.7): where upshifts fall
/// against the rev limiter, by band and by gear, with what each band did to
/// acceleration.
///
/// It states the band and the measured da. It never calls an early shift a
/// mistake: short-shifting saves fuel.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/reference/car_class.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/technique_providers.dart';
import '../domain/lap_technique.dart';
import '../domain/shifts.dart';
import 'technique_widgets.dart';

/// How far below the limiter the gear strips reach, rpm.
const _stripReach = 1200.0;

/// How far past it, for shifts read a few rpm over.
const _stripOver = 40.0;

class ShiftPanel extends StatelessWidget {
  const ShiftPanel({super.key, required this.overview, required this.lap});

  final TechniqueOverview overview;
  final LapTechnique lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final limiter = overview.session.revLimiter;
    final placed = [
      for (final u in overview.upshifts)
        if (u.band != null && u.read?.rpm != null) u,
    ];
    final counts = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${lap.upshifts}',
            style: AppTextStyles.numeral.copyWith(fontSize: 12),
          ),
          const TextSpan(text: ' up · '),
          TextSpan(
            text: '${lap.downshifts}',
            style: AppTextStyles.numeral.copyWith(fontSize: 12),
          ),
          const TextSpan(text: ' down this lap'),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(color: muted),
    );

    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Upshifts',
            caption: limiter == null
                ? null
                : 'against the rev limiter, '
                      '${_thousands(limiter)} rpm',
            trailing: const InfoPopoverButton(
              title: 'Upshifts against the limiter',
              width: 340,
              paragraphs: [
                'An upshift\'s RPM is the highest Engine RPM in the 0.3 s '
                    'before the gearbox went to neutral, read against the '
                    'rev limiter in the car\'s setup.',
                'Each band is graded by what the shift did to the car\'s '
                    'drive: Ground Speed\'s acceleration in the quarter '
                    'second after the shift minus the quarter second '
                    'before, at full throttle. Nearer zero, or above it, '
                    'means the shift cost less.',
                'An early shift is not a mistake. Short-shifting saves '
                    'fuel, and some races are run that way on purpose.',
              ],
              footer: [
                'Library figures: 14,440 full-throttle upshifts on 13 '
                    'files. A GT3 lost nothing measurable shifting up to '
                    '500 rpm early; a Hypercar or LMP2 lost from 200 rpm.',
              ],
            ),
          ),
          if (limiter == null) ...[
            const AbsenceNote(
              'This file\'s setup has no rev limiter, so upshifts cannot be '
              'placed against it.',
            ),
            counts,
          ] else if (placed.isEmpty) ...[
            const AbsenceNote(
              'No upshift on a racing lap had an Engine RPM to read.',
            ),
            counts,
          ] else ...[
            _BandBar(upshifts: placed),
            const SizedBox(height: 14),
            _BandTable(
              upshifts: placed,
              lap: lap.lap.index,
              carClass: overview.session.metadata.carClass,
            ),
            const SizedBox(height: 18),
            _GearStrips(upshifts: placed, lap: lap.lap.index, limiter: limiter),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 4,
              children: [
                counts,
                _Dwell(upshifts: placed, lap: lap.lap.index),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _thousands(double v) {
  final s = v.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

String _signed(double v, int decimals) =>
    '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(decimals)}';

/// A band's tint: the RPM channel's amber, strongest at the limiter. One hue,
/// so the bands read as an order, not as categories.
Color _bandColor(BuildContext context, ShiftBand band) =>
    ChannelColors.resolve(context).rpm.withValues(
      alpha: switch (band) {
        ShiftBand.atLimiter => 1.0,
        ShiftBand.late => 0.78,
        ShiftBand.early => 0.56,
        ShiftBand.short => 0.38,
        ShiftBand.wellBefore => 0.22,
      },
    );

/// The session's upshifts by band, as one bar.
class _BandBar extends StatelessWidget {
  const _BandBar({required this.upshifts});

  final List<Upshift> upshifts;

  @override
  Widget build(BuildContext context) {
    final total = upshifts.length;
    final shares = {
      for (final b in ShiftBand.values)
        b: upshifts.where((u) => u.band == b).length / total,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.duration(context, AppDurations.slow),
      curve: AppCurves.entrance,
      builder: (context, grow, _) => ClipPath(
        clipper: ShapeBorderClipper(shape: AppRadii.squircle(5)),
        child: SizedBox(
          height: 10,
          child: Row(
            children: [
              for (final b in ShiftBand.values.reversed)
                if (shares[b]! > 0)
                  Expanded(
                    flex: math.max(1, (1000 * shares[b]! * grow).round()),
                    child: AppTooltip(
                      message:
                          '${b.label}: '
                          '${(100 * shares[b]!).toStringAsFixed(0)} % of the '
                          'session\'s upshifts',
                      child: Container(
                        margin: const EdgeInsets.only(right: 1.5),
                        color: _bandColor(context, b),
                      ),
                    ),
                  ),
              Expanded(
                flex: math.max(0, (1000 * (1 - grow)).round()),
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BandTable extends StatelessWidget {
  const _BandTable({
    required this.upshifts,
    required this.lap,
    required this.carClass,
  });

  final List<Upshift> upshifts;
  final int lap;
  final String carClass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final head = theme.textTheme.labelSmall?.copyWith(
      color: muted,
      letterSpacing: 0.3,
    );
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 12);
    final library = {
      for (final b in ShiftBand.values) b: libraryAcceleration(carClass, b),
    };
    final hasLibrary = library.values.any((v) => v != null);
    final total = upshifts.length;

    Widget right(Widget child, double width) => SizedBox(
      width: width,
      child: Align(alignment: Alignment.centerRight, child: child),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('BAND', style: head)),
            right(Text('LAP', style: head), 36),
            right(Text('SESSION', style: head), 60),
            right(
              AppTooltip(
                message:
                    'Mean change in acceleration across the shift, km/h per '
                    's, over this session\'s full-throttle upshifts (n)',
                child: Text('DA', style: head),
              ),
              100,
            ),
            if (hasLibrary)
              right(
                AppTooltip(
                  message:
                      'The same, over the library\'s '
                      '${CarClass.parse(carClass).label} upshifts (n)',
                  child: Text('LIBRARY', style: head),
                ),
                100,
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final b in ShiftBand.values)
          if (upshifts.any((u) => u.band == b) || library[b] != null)
            Builder(
              builder: (context) {
                final inBand = [
                  for (final u in upshifts)
                    if (u.band == b) u,
                ];
                final onLap = inBand.where((u) => u.lap == lap).length;
                final graded = [
                  for (final u in inBand)
                    if (u.atFullThrottle) ?u.read?.accelerationChange,
                ];
                final mean = graded.isEmpty
                    ? null
                    : graded.reduce((a, c) => a + c) / graded.length;
                final lib = library[b];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: ShapeDecoration(
                          shape: AppRadii.squircle(2.5),
                          color: _bandColor(context, b),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppTooltip(
                          message: b.range,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: b.label),
                                TextSpan(
                                  text: '  ${b.range}',
                                  style: TextStyle(color: muted, fontSize: 11),
                                ),
                              ],
                            ),
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      right(
                        RollingNumber(
                          value: onLap.toDouble(),
                          format: (v) => v.round().toString(),
                          style: numeral.copyWith(
                            color: onLap == 0 ? muted : null,
                          ),
                        ),
                        36,
                      ),
                      right(
                        Text(
                          '${(100 * inBand.length / total).toStringAsFixed(0)} %',
                          style: numeral.copyWith(color: muted),
                        ),
                        60,
                      ),
                      right(
                        Text(
                          mean == null
                              ? '—'
                              : '${_signed(mean, 2)} (${graded.length})',
                          // A mean of a handful of shifts is shown, quietly.
                          style: graded.length < 5
                              ? numeral.copyWith(color: muted)
                              : numeral,
                        ),
                        100,
                      ),
                      if (hasLibrary)
                        right(
                          Text(
                            lib == null
                                ? '—'
                                : '${_signed(lib.da, 2)} (${lib.n})',
                            style: numeral.copyWith(color: muted),
                          ),
                          100,
                        ),
                    ],
                  ),
                );
              },
            ),
      ],
    );
  }
}

/// One strip per gear: the session's upshifts out of it as faint dots, this
/// lap's as bright ones that slide to their new place when the lap changes.
class _GearStrips extends StatelessWidget {
  const _GearStrips({
    required this.upshifts,
    required this.lap,
    required this.limiter,
  });

  final List<Upshift> upshifts;
  final int lap;
  final double limiter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final gears = {for (final u in upshifts) u.shift.from}.toList()..sort();
    final label = theme.textTheme.labelSmall?.copyWith(color: muted);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gutter = 40.0;
        final width = constraints.maxWidth - gutter;
        double xOf(double rpm) {
          final below = (limiter - rpm).clamp(-_stripOver, _stripReach);
          return width * (_stripReach - below) / (_stripReach + _stripOver);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: gutter),
              child: SizedBox(
                height: 14,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final (below, text) in const [
                      (1000.0, '−1,000'),
                      (500.0, '−500'),
                      (200.0, '−200'),
                      (0.0, 'L'),
                    ])
                      Positioned(
                        left: xOf(limiter - below) - 20,
                        width: 40,
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.numeral.copyWith(
                            fontSize: 9.5,
                            color: muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final gear in gears)
              SizedBox(
                height: 20,
                child: Row(
                  children: [
                    SizedBox(
                      width: gutter,
                      child: Text(
                        '$gear→${gear + 1}',
                        style: label?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _Strip(
                        session: [
                          for (final u in upshifts)
                            if (u.shift.from == gear) xOf(u.read!.rpm!),
                        ],
                        lap: [
                          for (final u in upshifts)
                            if (u.shift.from == gear && u.lap == lap) u,
                        ],
                        xOf: xOf,
                        ticks: [
                          for (final below in const [
                            1000.0,
                            500.0,
                            200.0,
                            20.0,
                          ])
                            xOf(limiter - below),
                        ],
                        limiterX: xOf(limiter),
                        limiter: limiter,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.session,
    required this.lap,
    required this.xOf,
    required this.ticks,
    required this.limiterX,
    required this.limiter,
  });

  final List<double> session;
  final List<Upshift> lap;
  final double Function(double rpm) xOf;
  final List<double> ticks;
  final double limiterX;
  final double limiter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rpm = ChannelColors.resolve(context).rpm;
    const dot = 9.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _StripPainter(
              session: session,
              ticks: ticks,
              limiterX: limiterX,
              dot: rpm.withValues(alpha: 0.32),
              rule: scheme.outlineVariant,
              limiterColor: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        for (final (k, u) in lap.indexed)
          AnimatedPositioned(
            key: ValueKey(k),
            duration: AppMotion.duration(context, rollDuration),
            curve: AppCurves.entrance,
            left: xOf(u.read!.rpm!) - dot / 2,
            top: 10 - dot / 2,
            width: dot,
            height: dot,
            child: AppTooltip(
              message: _describe(u),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rpm,
                  border: Border.all(
                    color: scheme.surface.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _describe(Upshift u) {
    final read = u.read!;
    final below = limiter - read.rpm!;
    final where = below.abs() <= 20
        ? 'at the limiter'
        : below > 0
        ? '${below.toStringAsFixed(0)} rpm before the limiter'
        : '${(-below).toStringAsFixed(0)} rpm over it';
    final da = read.accelerationChange;
    return '${u.shift.from}→${u.shift.to} at '
        '${_thousands(read.rpm!)} rpm, $where'
        '${da != null && u.atFullThrottle ? '\nda ${_signed(da, 2)} km/h per s' : ''}'
        '${u.atFullThrottle ? '' : '\nNot at full throttle, so not graded'}';
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.session,
    required this.ticks,
    required this.limiterX,
    required this.dot,
    required this.rule,
    required this.limiterColor,
  });

  final List<double> session;
  final List<double> ticks;
  final double limiterX;
  final Color dot;
  final Color rule;
  final Color limiterColor;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = rule.withValues(alpha: 0.6)
        ..strokeWidth = 1,
    );
    final tick = Paint()
      ..color = rule
      ..strokeWidth = 1;
    for (final x in ticks) {
      canvas.drawLine(Offset(x, mid - 4), Offset(x, mid + 4), tick);
    }
    canvas.drawLine(
      Offset(limiterX, 1),
      Offset(limiterX, size.height - 1),
      Paint()
        ..color = limiterColor
        ..strokeWidth = 1.5,
    );
    // A fixed jitter spreads the stack of dots at one RPM so its depth shows.
    final paint = Paint()..color = dot;
    for (final (i, x) in session.indexed) {
      final jitter = ((i * 2654435761) % 1000) / 1000 - 0.5;
      canvas.drawCircle(Offset(x, mid + jitter * 9), 2, paint);
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.limiterX != limiterX ||
      old.dot != dot ||
      old.session.length != session.length ||
      !identical(old.session, session);
}

/// Time on the limiter before an upshift. Most shifts never reach it, so a
/// median over all of them is zero: the line counts the ones that did, and
/// gives their median.
class _Dwell extends StatelessWidget {
  const _Dwell({required this.upshifts, required this.lap});

  final List<Upshift> upshifts;
  final int lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 12);
    final dwelt = [
      for (final u in upshifts)
        if ((u.read?.limiterSeconds ?? 0) > 0) u,
    ];
    final onLap = upshifts.where((u) => u.lap == lap).length;
    final dweltOnLap = [
      for (final u in dwelt)
        if (u.lap == lap) u.read!.limiterSeconds,
    ];
    final session = medianOf([for (final u in dwelt) u.read!.limiterSeconds]);
    final mine = medianOf(dweltOnLap);
    return AppTooltip(
      message:
          'Time within 100 rpm of the limiter in the second before an '
          'upshift. Library medians: GT3 0.045 s, Hypercar 0.078 s, LMP2 '
          '0.24 s.',
      child: Text.rich(
        TextSpan(
          children: session == null
              ? const [
                  TextSpan(
                    text: 'no upshift this session reached the limiter first',
                  ),
                ]
              : [
                  const TextSpan(text: 'reached the limiter before '),
                  TextSpan(text: '${dweltOnLap.length}', style: numeral),
                  TextSpan(text: ' of $onLap shifts this lap'),
                  if (mine != null) ...[
                    const TextSpan(text: ', '),
                    TextSpan(text: mine.toStringAsFixed(3), style: numeral),
                    const TextSpan(text: ' s median'),
                  ],
                  const TextSpan(text: ' · session '),
                  TextSpan(text: session.toStringAsFixed(3), style: numeral),
                  const TextSpan(text: ' s'),
                ],
        ),
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
    );
  }
}
