/// The map stage's minimap (map stage proposal §4): the whole lap, what the
/// camera shows of it, and the cars — and the camera's controls under it.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
import 'package:material_ui/material_ui.dart';

import '../../design_system/design_system.dart';
import '../track_path.dart';
import 'camera.dart';
import 'camera_rig.dart';
import 'stage_layers.dart';

/// What the camera is doing, in words for the minimap's caption.
String cameraModeLabel(CameraMode mode, {required bool framingWindow}) =>
    switch (mode) {
      CameraMode.follow => 'Following the car',
      CameraMode.free => 'Free',
      CameraMode.fit => framingWindow ? 'Trace window' : 'Whole lap',
    };

class MapMinimap extends StatelessWidget {
  const MapMinimap({
    super.key,
    required this.path,
    required this.camera,
    required this.visible,
    required this.cars,
    required this.mode,
    required this.framingWindow,
    required this.canFollow,
    required this.zoom,
    required this.onZoom,
    required this.onCentre,
    required this.onMode,
    this.speedZoom,
    this.onSpeedZoom,
  });

  final TrackPath path;
  final ValueListenable<MapCamera> camera;

  /// The part of the stage the panels leave clear, in its pixels: the
  /// camera's rectangle is drawn for this, not for what lies under glass.
  final Rect visible;
  final List<CarGlyph> cars;
  final CameraMode mode;
  final bool framingWindow;
  final bool canFollow;

  /// The zoom between the whole lap (0) and the closest the camera goes (1).
  final double zoom;
  final ValueChanged<double> onZoom;

  /// A point of the lap, in metres, to centre the camera on.
  final ValueChanged<Offset> onCentre;
  final ValueChanged<CameraMode> onMode;

  /// Whether the camera breathes with speed, and how to change it; the menu
  /// is absent when [onSpeedZoom] is null.
  final bool? speedZoom;
  final ValueChanged<bool>? onSpeedZoom;

  static const width = 208.0;

  /// The card's height at the default text scale: the corner it keeps.
  static const height = 216.0;
  static const _mapHeight = 112.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final caption = cameraModeLabel(mode, framingWindow: framingWindow);

    Widget modeButton(
      CameraMode target,
      IconData icon,
      String tip, {
      bool enabled = true,
    }) {
      final selected = mode == target;
      return AppTooltip(
        message: tip,
        child: IconButton(
          onPressed: enabled ? () => onMode(target) : null,
          isSelected: selected,
          icon: Icon(icon, size: 16),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: selected ? scheme.secondaryContainer : null,
            foregroundColor: selected
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
            shape: AppRadii.squircle(AppRadii.sm),
          ),
        ),
      );
    }

    final bounds = path.projection.boundsMetres;
    return Semantics(
      container: true,
      label: 'Minimap: $caption',
      child: SizedBox(
        width: width,
        child: GlassSurface(
          radius: AppRadii.md,
          tint: 0.6,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _mapHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    final fit = _MiniFit(bounds, size);
                    void centre(Offset local) => onCentre(fit.toMetres(local));
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => centre(d.localPosition),
                        onPanStart: (d) => centre(d.localPosition),
                        onPanUpdate: (d) => centre(d.localPosition),
                        child: CustomPaint(
                          size: size,
                          painter: _MinimapPainter(
                            path: path,
                            fit: fit,
                            camera: camera,
                            visible: visible,
                            cars: cars,
                            line: scheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                            frame: scheme.primary,
                            car: scheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      caption,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (onSpeedZoom case final toggle?)
                    PopupMenuButton<bool>(
                      tooltip: 'Map options',
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      shape: AppRadii.squircle(AppRadii.sm),
                      onSelected: toggle,
                      itemBuilder: (context) => [
                        CheckedPopupMenuItem(
                          value: !(speedZoom ?? true),
                          checked: speedZoom ?? true,
                          child: const Text('Zoom out with speed'),
                        ),
                      ],
                    ),
                ],
              ),
              Row(
                children: [
                  modeButton(
                    CameraMode.follow,
                    Icons.my_location,
                    mode == CameraMode.free
                        ? 'Back to the car (Esc)'
                        : 'Follow the car (Esc)',
                    enabled: canFollow,
                  ),
                  modeButton(
                    CameraMode.fit,
                    Icons.fit_screen_outlined,
                    framingWindow
                        ? 'The trace window (F)'
                        : 'The whole lap (F)',
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                      ),
                      child: Semantics(
                        label: 'Map zoom',
                        child: Slider(
                          value: zoom.clamp(0.0, 1.0),
                          onChanged: onZoom,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The whole lap fitted into the minimap, keeping its proportions.
class _MiniFit {
  _MiniFit(this.bounds, Size size) {
    const pad = 6.0;
    final w = math.max(size.width - pad * 2, 1.0);
    final h = math.max(size.height - pad * 2, 1.0);
    scale = math.min(
      w / math.max(bounds.width, 1),
      h / math.max(bounds.height, 1),
    );
    offset = Offset(
      pad + (w - bounds.width * scale) / 2,
      pad + (h - bounds.height * scale) / 2,
    );
  }

  final Rect bounds;
  late final double scale;
  late final Offset offset;

  // The same orientation as the stage's camera, which maps the projection's
  // metres onto pixels without a flip.
  Offset toPixels(Offset metres) => (metres - bounds.topLeft) * scale + offset;

  Offset toMetres(Offset pixels) => (pixels - offset) / scale + bounds.topLeft;
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.path,
    required this.fit,
    required this.camera,
    required this.visible,
    required this.cars,
    required this.line,
    required this.frame,
    required this.car,
  }) : super(repaint: camera);

  final TrackPath path;
  final _MiniFit fit;
  final ValueListenable<MapCamera> camera;
  final Rect visible;
  final List<CarGlyph> cars;
  final Color line;
  final Color frame;
  final Color car;

  @override
  void paint(Canvas canvas, Size size) {
    final points = path.projection.points;
    if (points.length < 2) return;
    final lap = Path();
    final first = fit.toPixels(points.first);
    lap.moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final p = fit.toPixels(points[i]);
      lap.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      lap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = line,
    );

    final cam = camera.value;
    final shown = Rect.fromPoints(
      fit.toPixels(cam.toMetres(visible.topLeft)),
      fit.toPixels(cam.toMetres(visible.bottomRight)),
    ).intersect(Offset.zero & size);
    if (!shown.isEmpty) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(shown, const Radius.circular(3)),
        Paint()..color = frame.withValues(alpha: 0.12),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(shown, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = frame,
      );
    }

    for (final c in cars) {
      final at = fit.toPixels(c.at);
      canvas.drawCircle(
        at,
        3.5,
        Paint()
          ..style = c.hollow ? PaintingStyle.stroke : PaintingStyle.fill
          ..strokeWidth = 1.4
          ..color = c.hollow ? c.colour : car,
      );
    }
  }

  @override
  bool shouldRepaint(_MinimapPainter old) =>
      !identical(old.path, path) ||
      old.visible != visible ||
      !listEquals(old.cars, cars) ||
      old.line != line ||
      old.frame != frame ||
      old.car != car ||
      old.fit.scale != fit.scale;
}
