// Reduced motion across the shared motion code (SPEC.md §9.7.4, §10).
//
// The setting is Flutter's `MediaQuery.disableAnimations`, which the platform
// fills in from the OS "reduce motion" preference (or `prefers-reduced-motion`
// on web). Nothing in the framework's implicit animations reads it, so every
// animation in shared code has to, and each test here pairs the reduced case
// with a control run at normal motion — an assertion that a page is instant
// means nothing unless the same page, the same frames, is *not* instant when
// the setting is off.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/fl_chart_theme/per_lap_bar_chart.dart';

void _reduceMotion(WidgetTester tester, {bool on = true}) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: on);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// How visible [finder] is *now*: the product of every [FadeTransition] above
/// it. 1 is fully there, 0 is not drawn.
double _opacityOf(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  final fades = find.ancestor(of: finder, matching: find.byType(FadeTransition));
  for (final element in fades.evaluate()) {
    opacity *= (element.widget as FadeTransition).opacity.value;
  }
  return opacity;
}

/// How far [finder] is still to travel: the sum of every [SlideTransition]
/// above it, as a fraction of its own size.
double _slideOf(WidgetTester tester, Finder finder) {
  var slide = 0.0;
  final slides = find.ancestor(
    of: finder,
    matching: find.byType(SlideTransition),
  );
  for (final element in slides.evaluate()) {
    slide += (element.widget as SlideTransition).position.value.distance;
  }
  return slide;
}

void main() {
  group('AppMotion', () {
    testWidgets('returns the duration it was given at normal motion', (
      tester,
    ) async {
      late Duration seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = AppMotion.duration(context, AppDurations.medium);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, AppDurations.medium);
    });

    testWidgets('returns zero under reduced motion', (tester) async {
      _reduceMotion(tester);
      late Duration seen;
      late bool reduced;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = AppMotion.duration(context, AppDurations.medium);
              reduced = AppMotion.reduced(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, Duration.zero);
      expect(reduced, isTrue);
    });

    testWidgets('follows the setting when it changes mid-session', (
      tester,
    ) async {
      final durations = <Duration>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              durations.add(AppMotion.duration(context, AppDurations.fast));
              return const SizedBox();
            },
          ),
        ),
      );
      _reduceMotion(tester);
      await tester.pump();

      expect(durations.first, AppDurations.fast);
      expect(durations.last, Duration.zero);
    });

    testWidgets('does not throw where there is no MediaQuery at all', (
      tester,
    ) async {
      // `Hoverable` and friends are built in isolation by other people's
      // tests; asking a question of a tree that has no MediaQuery is "no".
      late bool reduced;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            reduced = AppMotion.reduced(context);
            return const SizedBox();
          },
        ),
      );
      expect(reduced, isFalse);
    });
  });

  group('page transitions (appPage)', () {
    GoRouter buildRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const Text('home')),
        ),
        GoRoute(
          path: '/next',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const Text('next')),
        ),
      ],
    );

    Future<GoRouter> pumpApp(WidgetTester tester) async {
      final router = buildRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return router;
    }

    /// Navigates and stops on the first frame the new page is in the tree —
    /// `go` resolves the location asynchronously, so it takes a frame to get
    /// there and the animation, if there is one, has not yet advanced.
    Future<void> goTo(WidgetTester tester, GoRouter router, String path) async {
      router.go(path);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('normal motion: the new page fades and slides in', (
      tester,
    ) async {
      final router = await pumpApp(tester);

      await goTo(tester, router, '/next');
      expect(_opacityOf(tester, find.text('next')), 0);
      expect(_slideOf(tester, find.text('next')), greaterThan(0));

      await tester.pump(const Duration(milliseconds: 40));
      expect(_opacityOf(tester, find.text('next')), inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(_opacityOf(tester, find.text('next')), 1);
      expect(_slideOf(tester, find.text('next')), 0);
    });

    testWidgets('reduced motion: the new page is there at once, in place', (
      tester,
    ) async {
      _reduceMotion(tester);
      final router = await pumpApp(tester);

      await goTo(tester, router, '/next');

      // The very first frame of the navigation, before any time has passed.
      expect(find.text('next'), findsOneWidget);
      expect(_opacityOf(tester, find.text('next')), 1);
      expect(_slideOf(tester, find.text('next')), 0);
    });

    testWidgets('the builder skips both effects rather than shortening them', (
      tester,
    ) async {
      final page = appPage<void>(
        key: const ValueKey('p'),
        child: const Text('x'),
      );
      Widget host({required bool reduced}) => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Builder(
            builder: (context) => page.transitionsBuilder(
              context,
              const AlwaysStoppedAnimation(0.2),
              const AlwaysStoppedAnimation(0),
              const Text('x'),
            ),
          ),
        ),
      );

      // Control: mid-transition at normal motion, the child is wrapped in
      // both effects.
      await tester.pumpWidget(host(reduced: false));
      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.byType(SlideTransition), findsOneWidget);

      // Same frame, same progress, reduced: the child, bare.
      await tester.pumpWidget(host(reduced: true));
      expect(find.byType(FadeTransition), findsNothing);
      expect(find.byType(SlideTransition), findsNothing);
      expect(find.text('x'), findsOneWidget);
    });
  });

  group('AsyncValueView', () {
    Widget host(AsyncValue<String> value) => MaterialApp(
      home: Scaffold(
        body: AsyncValueView<String>(
          value: value,
          loading: (_) => const Text('skeleton'),
          data: (_, data) => Text(data),
        ),
      ),
    );

    testWidgets('normal motion: the skeleton dissolves into the data', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AsyncValue.loading()));
      await tester.pumpWidget(host(const AsyncValue.data('1:04.497')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Mid cross-fade: both are in the tree.
      expect(find.text('skeleton'), findsOneWidget);
      expect(find.text('1:04.497'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('skeleton'), findsNothing);
    });

    testWidgets('reduced motion: the data replaces the skeleton outright', (
      tester,
    ) async {
      _reduceMotion(tester);
      await tester.pumpWidget(host(const AsyncValue.loading()));
      await tester.pumpWidget(host(const AsyncValue.data('1:04.497')));
      await tester.pump();

      expect(find.text('skeleton'), findsNothing);
      expect(find.text('1:04.497'), findsOneWidget);
      expect(_opacityOf(tester, find.text('1:04.497')), 1);
    });
  });

  group('useFadeInOnMount', () {
    Widget probe(List<double> values) => MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final controller = useFadeInOnMount(duration: AppDurations.slow);
          values.add(controller.value);
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              values.add(controller.value);
              return const SizedBox();
            },
          );
        },
      ),
    );

    testWidgets('normal motion starts at 0 and runs to 1', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(probe(values));
      expect(values.first, 0);

      await tester.pump(const Duration(milliseconds: 100));
      expect(values.last, inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(values.last, 1);
    });

    testWidgets('reduced motion is at 1 from the first frame', (tester) async {
      _reduceMotion(tester);
      final values = <double>[];
      await tester.pumpWidget(probe(values));
      await tester.pump();

      expect(values.last, 1);
    });

    testWidgets('jumps to the end if reduced motion is switched on mid-way', (
      tester,
    ) async {
      final values = <double>[];
      await tester.pumpWidget(probe(values));
      await tester.pump(const Duration(milliseconds: 50));
      expect(values.last, lessThan(1));

      _reduceMotion(tester);
      await tester.pump();
      await tester.pump();

      expect(values.last, 1);
    });
  });

  group('PerLapBarChart', () {
    Widget chart() => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: PerLapBarChart(
          bars: const [
            PerLapBar(lapNumber: 1, value: 2.5),
            PerLapBar(lapNumber: 2, value: 2.6),
          ],
          color: AppColors.channelFuel,
          formatValue: (v) => v.toStringAsFixed(2),
        ),
      ),
    );

    testWidgets('grows bars to a new value at normal motion', (tester) async {
      await tester.pumpWidget(chart());
      expect(tester.widget<BarChart>(find.byType(BarChart)).duration,
          AppDurations.medium);
    });

    testWidgets('lands them on it under reduced motion', (tester) async {
      _reduceMotion(tester);
      await tester.pumpWidget(chart());
      expect(
          tester.widget<BarChart>(find.byType(BarChart)).duration, Duration.zero);
    });
  });
}
