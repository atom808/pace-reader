import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pace_reader/app/app.dart';
import 'package:pace_reader/app/app_shell.dart';

void main() {
  testWidgets('App shell renders the initial route and side nav', (tester) async {
    // The side nav's ListView.builder only lays out visible items, and its
    // 13 destinations (~64px each) need more height than flutter_test's
    // default surface — a real desktop-sized viewport is needed for all of
    // them to actually build, not just a scroll workaround for the test.
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: PaceReaderApp()));
    await tester.pumpAndSettle();

    expect(find.text('Session library — coming soon'), findsOneWidget);
    for (final destination in appNavDestinations) {
      // >=1, not ==1: the active screen's own placeholder icon can repeat
      // its nav-rail icon (e.g. Sessions shows folder_open_outlined twice).
      expect(find.byIcon(destination.icon), findsAtLeastNWidgets(1));
    }
  });
}
