import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/settings/application/app_settings.dart';
import '../widgets/design_system/design_system.dart';
import 'router.dart';

class PaceReaderApp extends ConsumerStatefulWidget {
  const PaceReaderApp({super.key});

  @override
  ConsumerState<PaceReaderApp> createState() => _PaceReaderAppState();
}

class _PaceReaderAppState extends ConsumerState<PaceReaderApp> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Ctrl +, Ctrl - and Ctrl 0 zoom the whole interface, as in a browser.
  /// Global rather than a shortcut under the router so it works wherever
  /// focus is, including in a text field or a dialog.
  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    if (!(keyboard.isControlPressed || keyboard.isMetaPressed)) return false;
    final key = event.logicalKey;
    final settings = ref.read(appSettingsProvider.notifier);
    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      settings.stepUiScale(1);
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      settings.stepUiScale(-1);
    } else if (key == LogicalKeyboardKey.digit0 ||
        key == LogicalKeyboardKey.numpad0) {
      settings.resetUiScale();
    } else {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scale = ref.watch(appSettingsProvider.select((s) => s.uiScale));
    final performance = ref.watch(
      appSettingsProvider.select((s) => s.performanceMode),
    );
    return MaterialApp.router(
      title: 'Pace Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: appRouter,
      builder: (context, child) => EffectsQuality(
        level: performance ? EffectsLevel.performance : EffectsLevel.full,
        child: UiScale(scale: scale, child: child!),
      ),
    );
  }
}

/// Draws [child] [scale] times larger by laying it out in a window
/// 1/[scale] the size and magnifying that.
///
/// Scaling the layout rather than the text means a fixed-width readout grows
/// with its label instead of being overrun by it, and the breakpoints that
/// choose between a side pane and a tab respond to the zoom as they would to
/// a smaller window: at 150 % a 1600 px window lays out as 1067 px. Pointer
/// positions go through the same transform, so hit-testing, tooltips and
/// dialogs, which all live under [child], stay on target.
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale == 1.0) return child;
    final media = MediaQuery.of(context);
    // The box this is given, not the view's size: the two are the same in
    // the app, and the box is what the scaled window must fill exactly.
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest / scale;
        return _scaled(media, size);
      },
    );
  }

  Widget _scaled(MediaQueryData media, Size size) {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: MediaQuery(
            data: media.copyWith(
              size: size,
              padding: media.padding / scale,
              viewPadding: media.viewPadding / scale,
              viewInsets: media.viewInsets / scale,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
