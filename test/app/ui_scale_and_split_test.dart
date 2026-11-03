import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/app/app.dart';
import 'package:pace_reader/features/settings/application/app_settings.dart';
import 'package:pace_reader/widgets/common/resizable_side_pane.dart';

void main() {
  group('AppSettings', () {
    test('steps the interface size along the zoom steps and stops at the ends',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final settings = container.read(appSettingsProvider.notifier);
      double scale() => container.read(appSettingsProvider).uiScale;

      settings.stepUiScale(1);
      expect(scale(), 1.1);
      settings.stepUiScale(1);
      expect(scale(), 1.25);
      for (var i = 0; i < 10; i++) {
        settings.stepUiScale(1);
      }
      expect(scale(), 2.0);
      settings.resetUiScale();
      for (var i = 0; i < 10; i++) {
        settings.stepUiScale(-1);
      }
      expect(scale(), 0.8);
    });

    test('reads damaged or out-of-range values as sensible ones', () {
      expect(AppSettings.fromJson({}).uiScale, 1.0);
      expect(AppSettings.fromJson({'uiScale': 9}).uiScale, 2.0);
      expect(
        AppSettings.fromJson({'sidePaneWidth': 10}).sidePaneWidth,
        AppSettings.minSidePaneWidth,
      );
    });
  });

  testWidgets('UiScale lays out in a smaller window and draws it larger', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late Size seen;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => UiScale(scale: 1.5, child: child!),
        home: Builder(
          builder: (context) {
            seen = MediaQuery.sizeOf(context);
            return const Align(
              alignment: Alignment.topLeft,
              child: SizedBox(key: Key('box'), width: 100, height: 100),
            );
          },
        ),
      ),
    );
    expect(seen, const Size(1000, 600));
    final rect = tester.getRect(find.byKey(const Key('box')));
    expect(rect.size, const Size(150, 150));
  });

  testWidgets('dragging the divider widens the side pane, within limits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ResizableSplit(
            main: SizedBox.expand(key: Key('main')),
            side: SizedBox.expand(key: Key('side')),
          ),
        ),
      ),
    );
    double side() => tester.getSize(find.byKey(const Key('side'))).width;
    expect(side(), AppSettings.defaultSidePaneWidth);

    final handle = tester.getTopRight(find.byKey(const Key('main'))) +
        const Offset(6, 300);
    await tester.dragFrom(handle, const Offset(-200, 0));
    await tester.pump();
    expect(side(), closeTo(AppSettings.defaultSidePaneWidth + 200, 20));

    // Far past the traces' minimum: the pane stops, the traces keep 360.
    await tester.dragFrom(
      tester.getTopRight(find.byKey(const Key('main'))) + const Offset(6, 300),
      const Offset(-2000, 0),
    );
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('main'))).width, 360);
    // Let the double-click recogniser's window close.
    await tester.pump(const Duration(seconds: 1));
  });
}
