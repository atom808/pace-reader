import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pace_reader/app/app.dart';
import 'package:pace_reader/app/app_shell.dart';

void main() {
  testWidgets('App shell renders the session library and side nav',
      (tester) async {
    // The side nav's ListView.builder only lays out visible items, and its
    // destinations (~64px each) need more height than flutter_test's default
    // surface — a real desktop-sized viewport is needed for all of them to
    // actually build, not just a scroll workaround for the test.
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: PaceReaderApp()));
    await tester.pumpAndSettle();

    // With nothing imported yet, the library is the import surface.
    expect(find.text('Open a telemetry session'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);

    for (final destination in appNavDestinations) {
      // >=1, not ==1: a screen's own iconography can repeat a nav-rail icon.
      expect(find.byIcon(destination.icon), findsAtLeastNWidgets(1));
    }
  });

  testWidgets('a feature screen reached with no session offers a way out',
      (tester) async {
    // Every screen from §8.2 on needs a session, and the rail can reach them
    // all at any time, so this is a normal state rather than an error.
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: PaceReaderApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.timer_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('No session open'), findsOneWidget);
    expect(find.text('Go to sessions'), findsOneWidget);
  });
}
