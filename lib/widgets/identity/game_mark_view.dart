import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/game_marks/game_marks.dart';
import '../../data/reference/car_catalog.dart';
import '../../data/reference/track_catalog.dart';
import '../design_system/design_system.dart';

/// A game logo drawn into a box that is reserved before it loads, so a row
/// never reflows when the marks arrive, and faded in rather than popped.
class GameMarkView extends StatelessWidget {
  const GameMarkView({
    super.key,
    required this.mark,
    required this.width,
    required this.height,
    this.alignment = Alignment.center,
  });

  final GameMark mark;
  final double width;
  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final picture = mark.isRaster
        ? Image.memory(
            mark.bytes,
            width: width,
            height: height,
            fit: BoxFit.contain,
            alignment: alignment,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          )
        : SvgPicture.memory(
            mark.bytes,
            width: width,
            height: height,
            fit: BoxFit.contain,
            alignment: alignment,
          );
    return SizedBox(width: width, height: height, child: picture);
  }
}

/// The make's logo from the player's install, or null when there is none
/// (no game, the make is not placed, or the game has no logo for it).
GameMark? makeMarkOf(WidgetRef ref, CarModel? model) {
  if (model == null) return null;
  final marks = ref.watch(gameMarksProvider).value;
  return marks?.makes[model.make.label];
}

/// The circuit's logo, in a box [height] tall and as wide as the logo is,
/// up to [maxWidth]. Nothing at all where the game has none for this
/// circuit: a missing logo is not worth a placeholder, and the name beside
/// it says the same.
class CircuitLogo extends ConsumerWidget {
  const CircuitLogo({
    super.key,
    required this.trackName,
    this.trackLayout = '',
    this.height = 56,
    this.maxWidth = 160,
  });

  final String trackName;
  final String trackLayout;
  final double height;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = circuitLogoFor(trackName, trackLayout);
    final mark = file == null
        ? null
        : ref.watch(gameMarksProvider).value?.circuits[file];
    if (mark == null) return const SizedBox.shrink();
    return Semantics(
      label: '$trackName logo',
      image: true,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppMotion.duration(context, AppDurations.medium),
          curve: AppCurves.standard,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: GameMarkView(
            mark: mark,
            width: maxWidth,
            height: height,
            alignment: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}
