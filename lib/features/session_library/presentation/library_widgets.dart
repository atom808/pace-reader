/// Small pieces shared by the Session Library's sections.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/library_query.dart';
import '../data/library_entry.dart';

/// [base], or zero under the platform's reduced-motion setting (§9.7.4,
/// §10).
///
/// A zero [Duration] rather than "skip the widget": an implicit animation
/// with no time still lands on its end state, so a row that appears or a
/// banner that opens keeps its meaning and only stops travelling. Reads the
/// `MediaQuery` as a dependency, so a change to the setting while the app
/// runs is picked up.
Duration libraryMotion(BuildContext context, Duration base) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : base;

/// An [AnimatedSize] that steps aside under reduced motion.
///
/// Not `AnimatedSize(duration: Duration.zero)`: a zero-duration
/// `AnimatedSize` restarts its controller inside its own layout pass, which
/// Flutter asserts against ("mutated in its own performLayout") as soon as
/// the child's size changes. Not building the animation is the only correct
/// way to stop it.
class MotionSize extends StatelessWidget {
  const MotionSize({
    super.key,
    required this.duration,
    required this.curve,
    this.alignment = Alignment.center,
    required this.child,
  });

  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: duration,
      curve: curve,
      alignment: alignment,
      child: child,
    );
  }
}

/// Text whose digits are set in the numeral face (§9.7.7).
///
/// For sentences that carry a count — "Indexing 3 of 12", "19 laps" — where
/// the words belong to the UI voice but the numbers still have to be
/// JetBrains Mono like every other number in the app. Splitting the string
/// on digit runs keeps the copy readable at the call site instead of
/// hand-building a span per number.
class MixedNumeralText extends StatelessWidget {
  const MixedNumeralText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  static final _digits = RegExp(r'\d[\d.:,]*');

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final numeral = AppTextStyles.numeral.copyWith(
      fontSize: base.fontSize,
      color: base.color,
      fontWeight: base.fontWeight,
      height: base.height,
    );
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in _digits.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: numeral));
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

/// The session-type letter (`P`/`Q`/`R`) on the brand gradient.
class SessionTypeBadge extends StatelessWidget {
  const SessionTypeBadge({super.key, required this.type, this.size = 44});

  final SessionType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: type.rawValue,
      child: Container(
        width: size,
        height: size,
        decoration: const ShapeDecoration(
          shape: GradientSquircleBorder(
            radius: AppRadii.sm,
            gradient: AppGradients.hairlineStrong,
          ),
          gradient: AppGradients.brand,
        ),
        alignment: Alignment.center,
        child: Text(
          type.filenameCode,
          style: AppTextStyles.numeral.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// "PB" — this session holds the personal best for its circuit and class.
///
/// Iris, via `tertiary`: purple is the fastest-time colour on every timing
/// screen in motorsport, and it is the role `tertiary` already plays in the
/// lap table (§8.3, §9.7.1). The scope is never hidden behind the hover: the
/// row the badge sits on already names the circuit, layout and class it is
/// the best of, and the badge sits beside the lap number ("PB lap 11"). The
/// tooltip adds the lap time and how many sessions it beat.
class PersonalBestBadge extends StatelessWidget {
  const PersonalBestBadge({super.key, required this.entry, required this.best});

  final LibraryEntry entry;
  final PersonalBest best;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scope = '${entry.circuitLabel}, ${entry.carClass}';
    final of = best.sessionCount == 1
        ? 'the only timed session here so far'
        : 'fastest of ${best.sessionCount} sessions';
    return Tooltip(
      message:
          'Personal best — $scope\n'
          '${formatLapTime(best.lapSeconds)}, $of',
      child: Semantics(
        label: 'Personal best',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: ShapeDecoration(
            shape: AppRadii.squircle(10),
            color: scheme.tertiaryContainer,
          ),
          child: Text(
            'PB',
            style: AppTextStyles.numeral.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onTertiaryContainer,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

/// A section title with a count and an optional caption.
class LibrarySectionHeader extends StatelessWidget {
  const LibrarySectionHeader({
    super.key,
    required this.title,
    this.count,
    this.caption,
    this.trailing,
  });

  final String title;
  final int? count;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (count != null) ...[
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '$count',
              style: AppTextStyles.numeral.copyWith(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (caption != null) ...[
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                caption!,
                style: muted,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ] else
          const Spacer(),
        ?trailing,
      ],
    );
  }
}
