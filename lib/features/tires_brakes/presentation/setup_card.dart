/// The setup facts the tyres and brakes are read against (SPEC.md §8.6).
library;

import 'package:material_ui/material_ui.dart';

import '../../../data/models/models.dart';
import '../../../data/reference/tyre_compound.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/identity/compound_badge.dart';
import '../application/tire_brake_report.dart';
import '../application/tyre_setup.dart';

/// Compound, cold pressures, camber, disc thickness and the brake settings —
/// the setup's words, plus what the telemetry recorded of the settings a
/// driver can change on track.
class TyreSetupCard extends StatelessWidget {
  const TyreSetupCard({super.key, required this.report});

  final TireBrakeReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final setup = report.setup;
    Widget text(String value) =>
        Text(value, style: AppTextStyles.numeral.copyWith(fontSize: 13));

    final groups = <(String, List<(String, Widget)>)>[
      ('Compound', _compoundRows(setup, report.compoundStints, muted)),
      for (final (title, rows) in [
        ('Cold pressure', describeAxles(setup.coldPressure)),
        ('Camber', describeAxles(setup.camber)),
        ('Brake disc', describeAxles(setup.discThickness)),
        (
          'Brake balance',
          [
            if (setup.brakeBalance case final balance?)
              ('Setup', '${balance.text} F:R'),
            if (report.brakeBiasRear case final bias?)
              ('Recorded', _biasText(bias)),
          ],
        ),
        (
          'Brake migration',
          [
            if (setup.brakeMigration case final migration?)
              ('Setup', migration.text),
            if (report.brakeMigration case final migration?)
              ('Recorded', _changes(migration)),
          ],
        ),
        (
          'Max pedal force',
          [
            if (setup.brakePressure case final pressure?)
              ('Setup', pressure.text),
          ],
        ),
      ])
        (title, [for (final (label, value) in rows) (label, text(value))]),
    ].where((group) => group.$2.isNotEmpty).toList();

    return SquircleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Setup', style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            'As the car left the garage',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            Text(
              'This recording’s setup carries no tyre or brake values.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            )
          else
            for (final (title, rows) in groups) ...[
              _Group(title: title, rows: rows),
              const SizedBox(height: 10),
            ],
          // Only where the event is not recorded per corner, so there are no
          // stints to name.
          if (report.compoundStints.isEmpty && report.compoundChanges > 0)
            Text(
              'The compound changed ${report.compoundChanges} '
              '${report.compoundChanges == 1 ? 'time' : 'times'} during the '
              'recording; the setup names only the one it started on.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
        ],
      ),
    );
  }

  /// The compound rows: what the setup fitted, axle by axle, then each tyre
  /// change the event recorded, by the lap it came in. A start that differs
  /// from the setup (tyres changed in the garage after it was written) gets
  /// a row of its own.
  static List<(String, Widget)> _compoundRows(
    TyreSetup setup,
    List<CompoundStint> stints,
    Color muted,
  ) {
    final fitted = setup.compoundMarks;
    final rows = <(String, Widget)>[];
    // Grouped by compound, not by tread: four used Mediums worn to four
    // different depths are one row, with their treads beneath.
    final plain = {
      for (final MapEntry(key: c, value: m) in fitted.entries)
        c: CompoundMark(kind: m.kind, name: m.name),
    };
    final groups = plain.length == Corner.values.length
        ? axleGroups([for (final corner in Corner.values) plain[corner]!])
        : [
            for (final MapEntry(key: c, value: m) in plain.entries)
              (c.short, m),
          ];
    for (final (axle, mark) in groups) {
      final corners = switch (axle) {
        null => Corner.values,
        'F' => [Corner.frontLeft, Corner.frontRight],
        'R' => [Corner.rearLeft, Corner.rearRight],
        final short => Corner.values.where((c) => c.short == short).toList(),
      };
      final label = switch (axle) {
        null => 'All four',
        'F' => 'Front',
        'R' => 'Rear',
        final corner => corner,
      };
      rows.add((
        label,
        _SetupCompound(
          mark: mark,
          treads: {for (final c in corners) c: ?fitted[c]?.treadLeft},
          muted: muted,
        ),
      ));
    }
    for (final (i, stint) in stints.indexed) {
      if (i == 0 &&
          Corner.values.indexed.every(
            (c) => stint.marks[c.$1].kind == fitted[c.$2]?.kind,
          )) {
        continue;
      }
      rows.add((
        i == 0
            ? 'Recorded'
            : stint.lap == null
            ? 'Later'
            : 'Lap ${stint.lap!.displayNumber}',
        CompoundBadges(
          marks: stint.marks,
          size: CompoundBadgeSize.regular,
          showName: true,
        ),
      ));
    }
    return rows;
  }

  /// `Brake Bias Rear` holds the rear share; shown the way the setup writes
  /// balance, front first — 0.4875 is 51.2 : 48.8, the setup's own figure.
  static String _biasText(RecordedSetting bias) {
    String split(double rear) =>
        '${((1 - rear) * 100).toStringAsFixed(1)}:'
        '${(rear * 100).toStringAsFixed(1)}';
    if (bias.isConstant) return '${split(bias.initial)} · never changed';
    return '${split(bias.max)} to ${split(bias.min)} · '
        'changed ${bias.changes} ${bias.changes == 1 ? 'time' : 'times'}';
  }

  static String _changes(RecordedSetting setting) => setting.isConstant
      ? 'never changed'
      : 'changed ${setting.changes} '
            '${setting.changes == 1 ? 'time' : 'times'}';
}

/// A compound as the setup fitted it: badge and name, and beneath, the tread
/// a used set had left on each corner it covers.
class _SetupCompound extends StatelessWidget {
  const _SetupCompound({
    required this.mark,
    required this.treads,
    required this.muted,
  });

  final CompoundMark mark;

  /// Tread left per corner a used set is on; empty for new sets.
  final Map<Corner, double> treads;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    String pc(double v) => v.toStringAsFixed(0);
    final values = treads.values.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CompoundBadge(mark: mark, showTread: false),
            const SizedBox(width: 7),
            // The badge already says the compound to a screen reader.
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  mark.label,
                  style: AppTextStyles.numeral.copyWith(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
        // The range fits the card's narrow column; the corners are a hover
        // away.
        if (values.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppTooltip(
              message:
                  'Used sets, with this much of their tread left: '
                  '${[for (final MapEntry(key: c, value: v) in treads.entries) '${c.short} ${pc(v)} %'].join(', ')}.',
              child: Text(
                pc(values.first) == pc(values.last)
                    ? '${pc(values.first)} % tread'
                    : '${pc(values.first)}–${pc(values.last)} % tread',
                style: AppTextStyles.numeral.copyWith(
                  fontSize: 11.5,
                  color: muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<(String, Widget)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(title, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ),
                      Expanded(child: value),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
