import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pace_reader/widgets/design_system/design_system.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    );

void main() {
  group('AsyncValueView (SPEC.md §9.7.6)', () {
    testWidgets('shows the shimmer skeleton while loading, then the data',
        (tester) async {
      // Covers the Skeleton -> useShimmer hook path too: a HookWidget with a
      // misused hook fails at build time, and nothing else in the app renders
      // one yet.
      await tester.pumpWidget(_wrap(
        const AsyncValueView<String>(
          value: AsyncValue.loading(),
          data: _text,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(Skeleton), findsWidgets);
      expect(find.text('best lap'), findsNothing);

      await tester.pumpWidget(_wrap(
        const AsyncValueView<String>(
          value: AsyncValue.data('best lap'),
          data: _text,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('best lap'), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
    });

    testWidgets('surfaces an error instead of a blank pane', (tester) async {
      // §10: "a malformed/unexpected schema... should produce a clear error,
      // not a crash" — the shared error branch is where that shows up.
      await tester.pumpWidget(_wrap(
        AsyncValueView<String>(
          value: AsyncValue.error(
            const FormatException('unreadable telemetry'),
            StackTrace.empty,
          ),
          data: _text,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('unreadable telemetry'), findsOneWidget);
    });

    testWidgets('holds the shimmer still under reduced motion (§9.7.4)',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(const Skeleton()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // A repeating controller never settles; a stopped one does. The short
      // explicit timeout keeps a reduced-motion regression failing in seconds
      // rather than after pumpAndSettle's 10-minute default.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(find.byType(Skeleton), findsOneWidget);
    });
  });

  group('design tokens (SPEC.md §9.7.1, §9.7.2)', () {
    test('every radius token is a continuous squircle, never a pill', () {
      for (final radius in [AppRadii.sm, AppRadii.md, AppRadii.lg, AppRadii.xl]) {
        expect(AppRadii.squircle(radius), isA<ContinuousRectangleBorder>());
        expect(AppRadii.squircle(radius), isNot(isA<StadiumBorder>()));
      }
    });

    test('the dark theme carries the channel palette as an extension', () {
      final channels = AppTheme.dark().extension<ChannelColors>();
      expect(channels, isNotNull);
      // §9.7.1: delta is deliberately reassigned to a cool blue so it never
      // reads as brand chrome, since the brand itself is purple.
      expect(channels!.delta, AppColors.channelDelta);
      expect(channels.delta, isNot(AppColors.seed));
    });
  });
}

Widget _text(BuildContext context, String value) => Text(value);
