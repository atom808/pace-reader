/// Widgets held to a point of the map: a site a user can hover, click and
/// read a tooltip on, which a painted layer cannot be (map stage proposal
/// §9, Suspension's sites). The camera places them; they stay their own
/// size at any zoom.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import 'camera.dart';

/// [child] centred on [at], in the map's metres, in a box [size] across.
@immutable
class StagePin {
  const StagePin({
    required this.key,
    required this.at,
    required this.size,
    required this.child,
  });

  /// Keeps each pin's state — an entrance, a hover — across rebuilds.
  final Key key;
  final Offset at;
  final double size;
  final Widget child;
}

/// [pins] where [camera] puts them; those off screen are left out.
class StagePins extends StatelessWidget {
  const StagePins({super.key, required this.camera, required this.pins});

  final ValueListenable<MapCamera> camera;
  final List<StagePin> pins;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ValueListenableBuilder<MapCamera>(
      valueListenable: camera,
      builder: (context, camera, _) {
        final area = (Offset.zero & constraints.biggest).inflate(24);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final pin in pins)
              if (camera.toScreen(pin.at) case final at when area.contains(at))
                Positioned(
                  key: pin.key,
                  left: at.dx - pin.size / 2,
                  top: at.dy - pin.size / 2,
                  width: pin.size,
                  height: pin.size,
                  child: pin.child,
                ),
          ],
        );
      },
    ),
  );
}
