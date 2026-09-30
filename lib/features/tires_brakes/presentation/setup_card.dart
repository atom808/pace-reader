/// The setup facts the tyres and brakes are read against (SPEC.md §8.6).
library;

import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
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

    final groups = <(String, List<(String, String)>)>[
      ('Compound', describeAxles(setup.compound)),
      ('Cold pressure', describeAxles(setup.coldPressure)),
      ('Camber', describeAxles(setup.camber)),
      ('Brake disc', describeAxles(setup.discThickness)),
      ('Brake balance', [
        if (setup.brakeBalance case final balance?)
          ('Setup', '${balance.text} F:R'),
        if (report.brakeBiasRear case final bias?)
          ('Recorded', _biasText(bias)),
      ]),
      ('Brake migration', [
        if (setup.brakeMigration case final migration?)
          ('Setup', migration.text),
        if (report.brakeMigration case final migration?)
          ('Recorded', _changes(migration)),
      ]),
      ('Max pedal force', [
        if (setup.brakePressure case final pressure?) ('Setup', pressure.text),
      ]),
    ].where((group) => group.$2.isNotEmpty).toList();

    return SquircleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Setup', style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text('As the car left the garage',
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
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
          if (report.compoundChanges > 0)
            Text(
              // The event's values are an index nothing decodes, so the
              // screen says a change happened rather than naming a compound.
              'The compound changed ${report.compoundChanges} '
              '${report.compoundChanges == 1 ? 'time' : 'times'} during the '
              'recording; the setup names only the one it started on.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
        ],
      ),
    );
  }

  /// `Brake Bias Rear` holds the rear share; shown the way the setup writes
  /// balance, front first — 0.4875 is 51.2 : 48.8, the setup's own figure.
  static String _biasText(RecordedSetting bias) {
    String split(double rear) => '${((1 - rear) * 100).toStringAsFixed(1)}:'
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

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

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
                        child: Text(label,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: muted)),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: AppTextStyles.numeral.copyWith(fontSize: 13),
                        ),
                      ),
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
