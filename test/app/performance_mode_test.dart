// Performance mode (map stage proposal §7.4): one setting, kept between
// runs, that every glass surface obeys without reading it itself.

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/features/settings/application/app_settings.dart';
import 'package:pace_reader/features/settings/presentation/settings_screen.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

Widget _glass(EffectsLevel level, {bool grouped = false}) => MaterialApp(
  theme: AppTheme.dark(),
  home: EffectsQuality(
    level: level,
    child: BackdropGroup(
      child: Center(
        child: SizedBox(
          width: 200,
          height: 100,
          child: GlassSurface(grouped: grouped, child: const Text('glass')),
        ),
      ),
    ),
  ),
);

void main() {
  test('the setting survives a round trip, and is off by default', () {
    expect(const AppSettings().performanceMode, isFalse);
    final on = const AppSettings().copyWith(performanceMode: true);
    expect(AppSettings.fromJson(on.toJson()).performanceMode, isTrue);
    expect(AppSettings.fromJson(const {}).performanceMode, isFalse);
  });

  test('speed zoom survives a round trip, and is on by default', () {
    expect(const AppSettings().speedZoom, isTrue);
    final off = const AppSettings().copyWith(speedZoom: false);
    expect(AppSettings.fromJson(off.toJson()).speedZoom, isFalse);
    expect(AppSettings.fromJson(const {}).speedZoom, isTrue);
    expect(off.copyWith(performanceMode: true).speedZoom, isFalse);
  });

  testWidgets('glass blurs what is behind it', (tester) async {
    await tester.pumpWidget(_glass(EffectsLevel.full));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('the stage\'s glass shares one backdrop', (tester) async {
    await tester.pumpWidget(_glass(EffectsLevel.full, grouped: true));
    final filter = tester.renderObject<RenderBackdropFilter>(
      find.byType(BackdropFilter),
    );
    expect(filter.backdropKey, isNotNull);
  });

  testWidgets('under Performance mode glass blurs nothing, and still reads '
      'as a surface', (tester) async {
    await tester.pumpWidget(_glass(EffectsLevel.performance, grouped: true));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('glass'), findsOneWidget);
  });

  testWidgets('Settings turns it on', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const SettingsScreen(),
        ),
      ),
    );
    expect(find.text('Performance mode'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(container.read(appSettingsProvider).performanceMode, isTrue);
  });
}
