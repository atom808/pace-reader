/// The class's cars by typical lap (results proposal, R2): the list behind
/// Lap Analysis's band, and the field on a timing-only session's page.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../domain/field_pace.dart';

/// Cars by typical lap, and this car's line under them when it is not
/// among them.
class FieldCarsList extends StatelessWidget {
  const FieldCarsList({super.key, required this.pace, required this.cars});

  final FieldPace pace;
  final List<FieldCar> cars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final head = theme.textTheme.labelSmall?.copyWith(color: muted);
    final rows = [
      ...cars,
      if (!cars.contains(pace.me) && pace.me.typical != null) pace.me,
    ];

    // Bounded, so a whole class scrolls inside the popover.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 440),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('By typical lap', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _TopCarsRow(
            cells: [
              const SizedBox.shrink(),
              Text('Car', style: head),
              Text('Typical', style: head),
              Text('Best', style: head),
              Text('Laps', style: head),
            ],
          ),
          const Divider(height: 1),
          // Scrolls when a whole class is listed; five rows never need to.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, car) in rows.indexed) ...[
                    if (i == cars.length && i > 0) const Divider(height: 9),
                    _CarRow(
                      car: car,
                      rank:
                          1 +
                          pace.classCars
                              .where((c) => c.typical! < car.typical!)
                              .length,
                      isMe: car == pace.me,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'From LMU’s results file for this session, '
            '${pace.classSize} cars in class. The typical lap is the median of '
            'a car’s laps with all three sectors and no stop.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _TopCarsRow extends StatelessWidget {
  const _TopCarsRow({required this.cells});

  /// Rank, car, typical, best, laps.
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    Widget right(double width, Widget child) => SizedBox(
      width: width,
      child: Align(alignment: Alignment.centerRight, child: child),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 32, child: cells[0]),
          Expanded(child: cells[1]),
          right(84, cells[2]),
          right(84, cells[3]),
          right(44, cells[4]),
        ],
      ),
    );
  }
}

class _CarRow extends StatelessWidget {
  const _CarRow({required this.car, required this.rank, required this.isMe});

  final FieldCar car;
  final int rank;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = isMe ? scheme.primary : scheme.onSurface;
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 13, color: ink);
    final d = car.driver;
    return _TopCarsRow(
      cells: [
        Text('$rank', style: numeral.copyWith(color: scheme.onSurfaceVariant)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (d.carNumber.isNotEmpty) '#${d.carNumber}',
                d.carType,
              ].join(' '),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ink,
                fontWeight: isMe ? FontWeight.w600 : null,
              ),
            ),
            Text(
              isMe ? '${d.name} · you' : d.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(formatLapTime(car.typical!), style: numeral),
        Text(formatLapTime(car.best!), style: numeral),
        Text('${car.paceLaps.length}', style: numeral),
      ],
    );
  }
}
