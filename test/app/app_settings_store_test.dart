// The settings' store is a seam: the real app keeps a file, an integration
// test hands the real app a store of its own so the developer's preferences
// neither shape its layout nor get overwritten by it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/features/settings/application/app_settings.dart';

void main() {
  test(
    'the notifier reads what the store keeps, and writes changes to it',
    () async {
      final store = MemoryAppSettingsStore({'uiScale': 1.5});
      final container = ProviderContainer(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(container.read(appSettingsProvider).uiScale, 1.0);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appSettingsProvider).uiScale, 1.5);

      container.read(appSettingsProvider.notifier).setSpeedZoom(false);
      await Future<void>.delayed(Duration.zero);
      expect((await store.read())!['speedZoom'], isFalse);
      expect((await store.read())!['uiScale'], 1.5);
    },
  );

  test('a change before the store answers wins over what it held', () async {
    final store = MemoryAppSettingsStore({'performanceMode': false});
    final container = ProviderContainer(
      overrides: [appSettingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    container.read(appSettingsProvider.notifier).setPerformanceMode(true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appSettingsProvider).performanceMode, isTrue);
  });

  test('an empty store is the defaults', () async {
    final container = ProviderContainer(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(MemoryAppSettingsStore()),
      ],
    );
    addTearDown(container.dispose);
    container.read(appSettingsProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(appSettingsProvider).uiScale, 1.0);
    expect(container.read(appSettingsProvider).speedZoom, isTrue);
  });
}
