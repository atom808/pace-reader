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

    test('inputs draw the token squircle, not Material\'s rounded rectangle',
        () {
      // The regression this locks down is subtle enough to survive review by
      // eye: an `OutlineInputBorder` set to a token *radius* still draws a
      // circular-arc corner next to a squircle button, and a field that
      // spells out a bare `OutlineInputBorder()` silently takes Material's
      // 4px default and matches nothing at all.
      final inputs = AppTheme.dark().inputDecorationTheme;
      for (final border in [
        inputs.border,
        inputs.enabledBorder,
        inputs.focusedBorder,
      ]) {
        expect(border, isA<SquircleInputBorder>());
        expect(border, isNot(isA<OutlineInputBorder>()));
        expect((border! as SquircleInputBorder).radius, AppRadii.md);
      }
    });

    test('the surface ramp is the explicit one, not the generated one', () {
      final scheme = AppTheme.dark().colorScheme;
      final generated = ColorScheme.fromSeed(
        seedColor: AppColors.seed,
        brightness: Brightness.dark,
      );

      // §9.7.1 asks the base for one thing and the ramp above it for
      // another: a genuinely dark field — under half the generated base's
      // luminance — with the container tones still stepping monotonically
      // above it, so a card is never *darker* than the page it sits on.
      //
      // Deliberately not asserted: that the card-to-background contrast beat
      // the generated ramp's. It doesn't, and it isn't the mechanism — see
      // the note on the ramp in `color_tokens.dart`. A test that claimed it
      // would be a test that forces the ramp lighter to stay green.
      expect(
        scheme.surface.computeLuminance(),
        lessThan(generated.surface.computeLuminance() / 2),
      );

      final ramp = [
        scheme.surface,
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ].map((c) => c.computeLuminance()).toList();
      for (var i = 1; i < ramp.length; i++) {
        expect(ramp[i], greaterThan(ramp[i - 1]));
      }
    });

    test('the accent roles are iris, and are not the brand', () {
      final scheme = AppTheme.dark().colorScheme;
      // One accent, two Material role slots that want it (§9.7.1) — and
      // neither may collapse back onto the wine primary, which is the whole
      // point of adding a second seed.
      expect(scheme.secondary, scheme.tertiary);
      expect(scheme.secondary, isNot(scheme.primary));
      // Blue channel dominant: iris, not the wine family.
      expect(scheme.secondary.b, greaterThan(scheme.secondary.r));
      expect(scheme.primary.r, greaterThan(scheme.primary.b));
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
