/// The dock's tab bar (map stage proposal §6.2): a squircle bar whose
/// selected pill glides between tabs, each with its glyph, dropping to the
/// glyph alone when the dock is narrow.
library;

import 'package:material_ui/material_ui.dart';

import '../../design_system/design_system.dart';
import '../trace_tab.dart';

class DockTabs extends StatelessWidget {
  const DockTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<TraceTab> tabs;
  final TraceTab selected;
  final ValueChanged<TraceTab> onSelected;

  /// A tab's width with its name, and as its glyph alone.
  static const labelledWidth = 100.0;
  static const glyphWidth = 44.0;

  /// Each tab is its glyph, with its name in a tooltip, where the names
  /// don't all fit in [width].
  static bool glyphOnlyAt(double width, int tabs) =>
      tabs * labelledWidth + 6 > width;

  /// Where even the glyphs don't fit, as in a phone-width sheet (P9e), the
  /// bar scrolls sideways rather than shrink a tab under a finger's width.
  static bool scrollsAt(double width, int tabs) =>
      tabs * glyphWidth + 6 > width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final index = tabs.indexOf(selected).clamp(0, tabs.length - 1);
    final duration = AppMotion.duration(
      context,
      const Duration(milliseconds: 260),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final glyphOnly = glyphOnlyAt(constraints.maxWidth, tabs.length);
        final width = glyphOnly ? glyphWidth : labelledWidth;
        final scrolls = scrollsAt(constraints.maxWidth, tabs.length);
        final bar = Container(
          padding: const EdgeInsets.all(3),
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            shape: AppRadii.squircle(AppRadii.sm),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: AppCurves.standard,
                left: index * width,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: GradientSquircleBorder(radius: AppRadii.sm - 3),
                    color: scheme.secondaryContainer,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tab in tabs)
                    _Tab(
                      tab: tab,
                      width: width,
                      glyphOnly: glyphOnly,
                      selected: tab == selected,
                      onTap: () => onSelected(tab),
                    ),
                ],
              ),
            ],
          ),
        );
        return Semantics(
          container: true,
          label: 'Trace tabs',
          child: scrolls
              ? _ScrollingBar(
                  offset: index * width,
                  tabWidth: width,
                  child: bar,
                )
              : bar,
        );
      },
    );
  }
}

/// The bar sideways in a strip too narrow for it, kept scrolled so the
/// selected tab is in view: picked by a key or a link, it may be off the end.
class _ScrollingBar extends StatefulWidget {
  const _ScrollingBar({
    required this.offset,
    required this.tabWidth,
    required this.child,
  });

  /// Where the selected tab starts, from the bar's left.
  final double offset;
  final double tabWidth;
  final Widget child;

  @override
  State<_ScrollingBar> createState() => _ScrollingBarState();
}

class _ScrollingBarState extends State<_ScrollingBar> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(jump: true));
  }

  @override
  void didUpdateWidget(_ScrollingBar old) {
    super.didUpdateWidget(old);
    if (old.offset != widget.offset) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _reveal({bool jump = false}) {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    final left = widget.offset;
    final right = left + widget.tabWidth + 6;
    final view = position.viewportDimension;
    final target = left < position.pixels
        ? left
        : right > position.pixels + view
        ? right - view
        : null;
    if (target == null) return;
    final to = target.clamp(0.0, position.maxScrollExtent);
    if (jump || AppMotion.reduced(context)) {
      _scroll.jumpTo(to);
    } else {
      _scroll.animateTo(
        to,
        duration: AppDurations.medium,
        curve: AppCurves.standard,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: _scroll,
    scrollDirection: Axis.horizontal,
    child: widget.child,
  );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.width,
    required this.glyphOnly,
    required this.selected,
    required this.onTap,
  });

  final TraceTab tab;
  final double width;
  final bool glyphOnly;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final body = InkWell(
      onTap: onTap,
      customBorder: AppRadii.squircle(AppRadii.sm - 3),
      child: SizedBox(
        width: width,
        height: 32,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 16, color: colour),
            if (!glyphOnly) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  tab.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: colour),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      label: glyphOnly ? tab.label : null,
      child: glyphOnly ? AppTooltip(message: tab.label, child: body) : body,
    );
  }
}
