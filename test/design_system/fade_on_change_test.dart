// FadeOnChange (SPEC.md §9.7.4): a cross-fade on a value that can come back.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

const _fade = Duration(milliseconds: 120);

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  builder: (context, page) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: page!,
  ),
  home: Scaffold(body: Center(child: child)),
);

/// 1, 2, 1, 2 inside one fade. A switcher only drops the *incoming* key from
/// its fading-out children, so it takes a value coming back twice to leave
/// two 1s fading out at once — an [AnimatedSwitcher] with `ValueKey(value)`
/// children throws "Duplicate keys found" on exactly this sequence.
Future<void> _backAndForth(
  WidgetTester tester,
  Widget Function(String value) build,
) async {
  await tester.pumpWidget(_host(build('corner 1')));
  for (final value in ['corner 2', 'corner 1', 'corner 2']) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(_host(build(value)));
  }
  await tester.pump(const Duration(milliseconds: 20));
}

Widget _labelled(String value) => Builder(
  builder: (context) => FadeOnChange(
    value: value,
    duration: AppMotion.duration(context, _fade),
    child: Text(value),
  ),
);

void main() {
  testWidgets('values that come back mid-fade cross-fade cleanly', (
    tester,
  ) async {
    await _backAndForth(
      tester,
      (value) =>
          FadeOnChange(value: value, duration: _fade, child: Text(value)),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('corner 2'), findsOneWidget);
    expect(find.text('corner 1'), findsNothing);
  });

  testWidgets('a transition that keys itself by its child is safe too', (
    tester,
  ) async {
    // The default transition copies its child's key, as this one does: the
    // keys it sees are generations, never values.
    Widget scale(Widget child, Animation<double> animation) => ScaleTransition(
      key: ValueKey(child.key),
      scale: animation,
      child: child,
    );
    await _backAndForth(
      tester,
      (value) => FadeOnChange(
        value: value,
        duration: _fade,
        switchInCurve: AppCurves.entrance,
        transitionBuilder: scale,
        child: Text(value),
      ),
    );
    expect(tester.takeException(), isNull);
    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.switchInCurve, AppCurves.entrance);
    expect(switcher.transitionBuilder, scale);
    expect(
      find.ancestor(
        of: find.text('corner 2'),
        matching: find.byType(ScaleTransition),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the same value rebuilds in place, without a fade', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(FadeOnChange(value: 1, duration: _fade, child: const Text('a'))),
    );
    await tester.pumpWidget(
      _host(FadeOnChange(value: 1, duration: _fade, child: const Text('b'))),
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('a'), findsNothing);
  });

  testWidgets('normal motion: both values show while one fades to the next', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_labelled('lap 18')));
    await tester.pumpWidget(_host(_labelled('lap 19')));
    expect(find.text('lap 18'), findsOneWidget);
    expect(find.text('lap 19'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('reduced motion: the new value replaces the old in one frame', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_labelled('lap 18'), reduceMotion: true));
    await tester.pumpWidget(_host(_labelled('lap 19'), reduceMotion: true));
    expect(find.text('lap 18'), findsNothing);
    expect(find.text('lap 19'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
