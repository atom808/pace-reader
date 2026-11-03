import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/settings/application/app_settings.dart';
import '../design_system/design_system.dart';

/// The traces ([main]) and the pane beside them ([side]: the track map, or
/// Compare's map and detail), divided by a handle that drags the pane wider
/// or narrower.
///
/// One width for every screen that has such a pane: it is the same decision
/// ("how much of the window should the map get?") wherever it is made, and
/// the width is kept between runs. Double-clicking the handle puts it back.
///
/// The traces keep at least [minMain] logical pixels, so dragging far enough
/// stops short of squeezing them away rather than overflowing.
class ResizableSplit extends ConsumerStatefulWidget {
  const ResizableSplit({
    super.key,
    required this.main,
    required this.side,
    this.minMain = 360,
  });

  final Widget main;
  final Widget side;
  final double minMain;

  @override
  ConsumerState<ResizableSplit> createState() => _ResizableSplitState();
}

class _ResizableSplitState extends ConsumerState<ResizableSplit> {
  static const _handleWidth = 12.0;

  bool _dragging = false;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(
      appSettingsProvider.select((s) => s.sidePaneWidth),
    );
    final notifier = ref.read(appSettingsProvider.notifier);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final ceiling = (constraints.maxWidth - widget.minMain - _handleWidth)
            .clamp(AppSettings.minSidePaneWidth, double.infinity);
        final width = stored.clamp(AppSettings.minSidePaneWidth, ceiling);
        final active = _dragging || _hovering;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: widget.main),
            // A 12 px grab area around a 1 px rule: easy to hit, quiet to
            // look at until the pointer is on it.
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => setState(() => _dragging = true),
                onHorizontalDragUpdate: (details) => notifier.setSidePaneWidth(
                  (ref.read(appSettingsProvider).sidePaneWidth
                          .clamp(AppSettings.minSidePaneWidth, ceiling)) -
                      details.delta.dx,
                  commit: false,
                ),
                onHorizontalDragEnd: (_) {
                  setState(() => _dragging = false);
                  notifier.setSidePaneWidth(
                    ref.read(appSettingsProvider).sidePaneWidth,
                  );
                },
                onDoubleTap: notifier.resetSidePaneWidth,
                child: SizedBox(
                  width: _handleWidth,
                  child: Center(
                    child: AnimatedContainer(
                      duration: AppMotion.duration(context, AppDurations.fast),
                      width: active ? 3 : 1,
                      decoration: ShapeDecoration(
                        shape: AppRadii.squircle(2),
                        color: _dragging
                            ? theme.colorScheme.primary
                            : _hovering
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.dividerColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: width, child: widget.side),
          ],
        );
      },
    );
  }
}
