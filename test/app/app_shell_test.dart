// The app shell's rail, keyboard layer and session switcher (SPEC.md §8.1,
// §9.7.4, §10).
//
// The screens are probes rather than the real ones: what is under test is the
// chrome, and a real screen would need a session, a database and a dozen
// providers to say "I am at /laps". The one test that does want the real
// screens — that a destination marked not-ready really is a placeholder — uses
// them.
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/app/app.dart';
import 'package:pace_reader/app/app_shell.dart';
import 'package:pace_reader/app/router.dart';
import 'package:pace_reader/app/shell_actions.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_library/application/session_import.dart';
import 'package:pace_reader/widgets/common/feature_placeholder_screen.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/identity/class_chip.dart';

import '../design_system/portal_semantics.dart';
import '../fixtures/sample_sessions.dart';

class _Seeded extends OpenSessions {
  _Seeded(this.seed);

  final List<TelemetrySource> seed;

  @override
  List<TelemetrySource> build() => seed;
}

/// Stands in for the file picker: counts the calls, and leaves behind whatever
/// state the test wants the import to have ended in.
class _FakeImport extends SessionImport {
  _FakeImport({this.initial = const SessionImportIdle(), this.result});

  final SessionImportState initial;
  final SessionImportState? result;
  int picks = 0;

  @override
  SessionImportState build() => initial;

  @override
  Future<void> pickFile() async {
    picks++;
    if (result != null) state = result!;
  }
}

GoRouter _router(String initialLocation, {bool pageButton = true}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        for (final destination in appNavDestinations)
          GoRoute(
            path: destination.path,
            pageBuilder: (context, state) => appPage(
              key: state.pageKey,
              child: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('at ${destination.path}'),
                      if (pageButton)
                        TextButton(
                          onPressed: () {},
                          child: const Text('page button'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  ],
);

class _Shell {
  const _Shell(this.router, this.import, this.container);

  final GoRouter router;
  final _FakeImport import;
  final ProviderContainer container;

  List<TelemetrySource> get open => container.read(openSessionsProvider);
}

Future<_Shell> _pumpShell(
  WidgetTester tester, {
  List<TelemetrySource> open = const [],
  String at = '/sessions',
  bool pageButton = true,
  _FakeImport? import,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final fake = import ?? _FakeImport();
  final router = _router(at, pageButton: pageButton);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _Seeded(open)),
        sessionImportProvider.overrideWith(() => fake),
        sessionMetadataProvider(interlagosSource)
            .overrideWith((ref) async => interlagosMetadata),
        sessionMetadataProvider(spaSource).overrideWith((ref) async => spaMetadata),
        sessionMetadataProvider(sebringSource)
            .overrideWith((ref) async => sebringMetadata),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return _Shell(
    router,
    fake,
    ProviderScope.containerOf(tester.element(find.byType(AppShell))),
  );
}

/// The platform's shortcut modifier, held.
LogicalKeyboardKey get _modifier => usesCommandKey(defaultTargetPlatform)
    ? LogicalKeyboardKey.metaLeft
    : LogicalKeyboardKey.controlLeft;

Future<void> _chord(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(_modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(_modifier);
  await tester.pumpAndSettle();
}

/// The semantic label of the [Hoverable] that has keyboard focus, or null when
/// focus is on something else.
String? _focusedLabel() => FocusManager.instance.primaryFocus?.context
    ?.findAncestorWidgetOfExactType<Hoverable>()
    ?.semanticLabel;

/// Tabs until the slot named [label] has focus, so a test does not depend on
/// how many stops come before it.
Future<void> _focusRailSlot(WidgetTester tester, String label) async {
  for (var i = 0; i < 40 && _focusedLabel() != label; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(_focusedLabel(), label);
}

/// Tabs to the session switcher's badge.
Future<void> _focusTrigger(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    if (_focusedLabel()?.startsWith('Sessions:') ?? false) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  fail('the session switcher never received focus');
}

Future<void> _tabTimes(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  }
  await tester.pump();
}

/// A tooltip by its message. `find.byTooltip` matches the framework's own
/// semantics tooltip, which a `Tooltip` with `excludeFromSemantics` (as the
/// rail's have, so a slot is not announced twice) does not produce.
Finder _tip(String message) => find.byWidgetPredicate(
  (widget) => widget is Tooltip && widget.message == message,
);

/// The trigger's tooltip, which is also how to find and tap it.
Finder _trigger(String message) => _tip(message);

const _threeOpen = [sebringSource, spaSource, interlagosSource];

/// The popover's own fade: the nearest `FadeTransition`-over-`SlideTransition`
/// above its header. (The pages' route transitions have the same shape, and
/// are further up.) Under reduced motion it is at full strength on the first
/// frame; at normal motion it starts at nothing.
double _popoverOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Open sessions'),
            matching: find.byWidgetPredicate(
              (w) => w is FadeTransition && w.child is SlideTransition,
            ),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  group('nav rail: ready and not ready', () {
    testWidgets('marks exactly the two unbuilt destinations as not ready', (
      tester,
    ) async {
      final notReady = [
        for (final d in appNavDestinations)
          if (!d.ready) d.path,
      ];
      expect(notReady, ['/car-behavior', '/settings']);
    });

    testWidgets('says "coming soon" in the tooltip of a not-ready slot only', (
      tester,
    ) async {
      await _pumpShell(tester);

      expect(_tip('Car behavior — coming soon'), findsOneWidget);
      expect(_tip('Settings — coming soon'), findsOneWidget);

      // A ready one says what it is and how to get there, and nothing more.
      expect(_tip('Overview  (Ctrl+2)'), findsOneWidget);
      expect(_tip('Compare  (Ctrl+8)'), findsOneWidget);
      // The ninth is the last with a key; the tenth on has the name only.
      expect(_tip('Race pace  (Ctrl+9)'), findsOneWidget);
      expect(_tip('Setup'), findsOneWidget);
      expect(_tip('Events'), findsOneWidget);
      // Technique is the 12th slot, past the last digit key, so its tooltip
      // has no shortcut.
      expect(_tip('Technique'), findsOneWidget);
    });

    testWidgets('dims the icon of a not-ready slot, not of a ready one', (
      tester,
    ) async {
      await _pumpShell(tester);

      double alpha(IconData icon) =>
          tester.widget<Icon>(find.byIcon(icon)).color!.a;

      expect(alpha(Icons.directions_car_outlined), lessThan(0.5));
      expect(alpha(Icons.settings_outlined), lessThan(0.5));
      expect(alpha(Icons.timer_outlined), 1);
      expect(alpha(Icons.compare_arrows_outlined), 1);
      expect(alpha(Icons.insights_outlined), 1);
    });

    testWidgets('a dimmed slot still opens its screen', (tester) async {
      final shell = await _pumpShell(tester);

      await tester.tap(find.byIcon(Icons.directions_car_outlined));
      await tester.pumpAndSettle();

      expect(find.text('at /car-behavior'), findsOneWidget);
      expect(shell.router.state.uri.path, '/car-behavior');
    });

    testWidgets('the selected slot is announced as selected, and named', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpShell(tester, at: '/laps');

      expect(
        tester.getSemantics(find.bySemanticsLabel('Laps')),
        matchesSemantics(
          label: 'Laps',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        find.bySemanticsLabel('Car behavior, coming soon'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'every destination flagged not ready is still a placeholder screen',
      (tester) async {
        // The flag is maintained by hand. When a screen is built and the flag
        // is forgotten the rail goes on saying "coming soon" about a finished
        // feature; this makes that a failing build instead. It checks one
        // direction only — a ready destination may show a real screen or, in a
        // branch where another feature is still being written, a placeholder.
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(const ProviderScope(child: PaceReaderApp()));
        await tester.pumpAndSettle();

        for (final destination in appNavDestinations.where((d) => !d.ready)) {
          appRouter.go(destination.path);
          await tester.pumpAndSettle();
          expect(
            find.byType(FeaturePlaceholderScreen),
            findsOneWidget,
            reason:
                '${destination.path} is marked not ready but no longer shows a '
                'FeaturePlaceholderScreen — set `ready: true` on it in '
                'appNavDestinations',
          );
        }
        appRouter.go('/sessions');
        await tester.pumpAndSettle();
      },
    );
  });

  group('keyboard shortcuts', () {
    testWidgets('Cmd/Ctrl+1…9 go to the first nine destinations', (
      tester,
    ) async {
      await _pumpShell(tester);

      final digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.digit8,
        LogicalKeyboardKey.digit9,
      ];
      // Visit them out of order so a shortcut that "worked" by leaving the
      // location alone would not pass.
      for (final n in [3, 9, 1, 5, 2, 8, 4, 7, 6]) {
        await _chord(tester, digits[n - 1]);
        expect(
          find.text('at ${appNavDestinations[n - 1].path}'),
          findsOneWidget,
          reason: 'shortcut $n',
        );
      }
    });

    testWidgets('work straight away, with nothing clicked or focused', (
      tester,
    ) async {
      // The shell's own FocusScope is what gives a key press somewhere to
      // start from; this is the test that fails without it.
      await _pumpShell(tester);
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await _chord(tester, LogicalKeyboardKey.digit4);

      expect(find.text('at /trace'), findsOneWidget);
    });

    testWidgets('work while a rail slot has keyboard focus', (tester) async {
      await _pumpShell(tester);
      await _tabTimes(tester, 3);

      await _chord(tester, LogicalKeyboardKey.digit3);

      expect(find.text('at /laps'), findsOneWidget);
    });

    testWidgets('a bare digit does nothing', (tester) async {
      await _pumpShell(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pumpAndSettle();

      expect(find.text('at /sessions'), findsOneWidget);
    });

    testWidgets('Cmd/Ctrl+0 is not a shortcut', (tester) async {
      await _pumpShell(tester);

      await _chord(tester, LogicalKeyboardKey.digit0);

      expect(find.text('at /sessions'), findsOneWidget);
    });

    testWidgets('Cmd/Ctrl+O opens the file picker', (tester) async {
      final shell = await _pumpShell(tester);

      await _chord(tester, LogicalKeyboardKey.keyO);

      expect(shell.import.picks, 1);
    });

    testWidgets('Cmd/Ctrl+O does nothing while an import is running', (
      tester,
    ) async {
      final busy = _FakeImport(initial: const SessionImportBusy());
      await _pumpShell(tester, import: busy);

      await _chord(tester, LogicalKeyboardKey.keyO);

      expect(busy.picks, 0);
    });

    testWidgets(
      'a failed open from another screen takes the user to where it is shown',
      (tester) async {
        // Only the library renders an import failure; one that happened while
        // the user was on the trace would otherwise be invisible.
        final failing = _FakeImport(
          result: const SessionImportFailure(
            'That file could not be opened as a telemetry session.',
            detail: 'not a duckdb file',
          ),
        );
        await _pumpShell(tester, at: '/trace', import: failing);
        expect(find.text('at /trace'), findsOneWidget);

        await _chord(tester, LogicalKeyboardKey.keyO);

        expect(failing.picks, 1);
        expect(find.text('at /sessions'), findsOneWidget);
      },
    );

    testWidgets('a successful open stays where it is', (tester) async {
      final ok = _FakeImport(result: const SessionImportSuccess(sebringSource));
      await _pumpShell(tester, at: '/trace', import: ok);

      await _chord(tester, LogicalKeyboardKey.keyO);

      expect(ok.picks, 1);
      expect(find.text('at /trace'), findsOneWidget);
    });

    test('the table uses Cmd on Apple platforms and Ctrl everywhere else', () {
      for (final platform in TargetPlatform.values) {
        final activators = shellShortcuts(platform).keys.cast<SingleActivator>();
        final command = usesCommandKey(platform);
        expect(activators, hasLength(10), reason: '$platform');
        expect(activators.every((a) => a.meta == command), isTrue);
        expect(activators.every((a) => a.control == !command), isTrue);
      }
      expect(usesCommandKey(TargetPlatform.macOS), isTrue);
      expect(usesCommandKey(TargetPlatform.windows), isFalse);
      expect(usesCommandKey(TargetPlatform.linux), isFalse);
    });

    test('tooltips print the shortcut the way the platform writes it', () {
      expect(shortcutLabel('3', TargetPlatform.macOS), '⌘3');
      expect(shortcutLabel('3', TargetPlatform.windows), 'Ctrl+3');
    });
  });

  group('keyboard shortcuts on macOS', () {
    testWidgets(
      'use Cmd, and ignore Ctrl',
      (tester) async {
        expect(defaultTargetPlatform, TargetPlatform.macOS);
        await _pumpShell(tester);

        expect(_tip('Laps  (⌘3)'), findsOneWidget);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.text('at /sessions'), findsOneWidget);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();
        expect(find.text('at /laps'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });

  group('focus order', () {
    testWidgets('Tab walks the rail in order as one run, ending at the switcher', (
      tester,
    ) async {
      await _pumpShell(tester);

      // Focus starts in the page, so the first stop is its button.
      await _tabTimes(tester, 1);
      expect(_focusedLabel(), isNull);
      expect(
        FocusManager.instance.primaryFocus!.context!
            .findAncestorWidgetOfExactType<TextButton>(),
        isNotNull,
      );

      // Then the fourteen slots, in the order of the destinations, with no
      // page control between two of them...
      final labels = <String?>[];
      for (var i = 0; i < appNavDestinations.length; i++) {
        await _tabTimes(tester, 1);
        labels.add(_focusedLabel());
      }
      expect(labels, [
        for (final d in appNavDestinations)
          d.ready ? d.label : '${d.label}, coming soon',
      ]);

      // ...and the session switcher last.
      await _tabTimes(tester, 1);
      expect(_focusedLabel(), startsWith('Sessions:'));
    });

    testWidgets('a page with no controls does not cut the rail off', (
      tester,
    ) async {
      // The Overview is such a page. Focus starts in its route scope, where Tab
      // has nowhere to go, so the shell sends it to the rail's first stop: the
      // top-most slot, not whichever node attached first (that was the
      // switcher, and Tab then looped switcher → page → switcher for ever).
      await _pumpShell(tester, pageButton: false);

      await _tabTimes(tester, 1);
      expect(_focusedLabel(), 'Sessions');

      await _tabTimes(tester, 1);
      expect(_focusedLabel(), 'Overview');
    });

    testWidgets('Shift+Tab from such a page lands on the switcher, last stop', (
      tester,
    ) async {
      await _pumpShell(tester, pageButton: false);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(_focusedLabel(), startsWith('Sessions:'));
    });

    testWidgets('a slot that has keyboard focus can be activated with Enter', (
      tester,
    ) async {
      await _pumpShell(tester);
      await _focusRailSlot(tester, 'Laps');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('at /laps'), findsOneWidget);
    });
  });

  group('session switcher: the badge', () {
    testWidgets('with nothing open, says so and offers a file', (tester) async {
      await _pumpShell(tester);

      expect(
        _trigger('No session open — click to open a file'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows the type code of the current session', (tester) async {
      await _pumpShell(tester, open: const [spaSource]);

      // Spa is the Qualify sample.
      expect(
        find.descendant(
          of: _trigger('Spa-Francorchamps Endurance — Qualify'),
          matching: find.text('Q'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('names the circuit, session and count in the tooltip', (
      tester,
    ) async {
      await _pumpShell(tester, open: _threeOpen);

      expect(
        _trigger('Sebring School Circuit — Race  ·  3 open'),
        findsOneWidget,
      );
      // The count, on the badge itself.
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('has no count while there is only one', (tester) async {
      await _pumpShell(tester, open: const [sebringSource]);

      expect(_trigger('Sebring School Circuit — Race'), findsOneWidget);
    });
  });

  group('session switcher: the popover', () {
    testWidgets('opens on a tap and lists this run\'s sessions', (
      tester,
    ) async {
      await _pumpShell(tester, open: _threeOpen);
      expect(find.text('Open sessions'), findsNothing);

      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();

      expect(find.text('Open sessions'), findsOneWidget);
      expect(find.text('Sebring School Circuit'), findsOneWidget);
      expect(find.text('Spa-Francorchamps Endurance'), findsOneWidget);
      expect(find.text('José Carlos Pace'), findsOneWidget);
      // Type, class and driver of a session, from its own metadata: the class
      // as its chip, by name, not the file's "Hyper".
      expect(find.text('Qualify  ·  Diego Pestana'), findsOneWidget);
      expect(find.widgetWithText(ClassChip, 'HY'), findsOneWidget);
      expect(find.textContaining('Hyper'), findsNothing);
      expect(find.text('Open file…'), findsOneWidget);
      // Only the current one is marked.
      expect(find.text('Current'), findsOneWidget);
    });

    testWidgets('the rail\'s tooltips and the popover each have a node to '
        'hang from, so opening them cannot break the Windows accessibility '
        'tree', (tester) async {
      // See AppTooltip: a portal whose anchor shares a node with another's is
      // dropped, and opening it sends a node no parent lists.
      final handle = tester.ensureSemantics();
      await _pumpShell(tester, open: _threeOpen);
      expect(orphanablePortalAnchors(tester), isEmpty);

      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();
      expect(find.text('Open sessions'), findsOneWidget);
      expect(unlistedSemanticsNodes(tester), isEmpty);
      handle.dispose();
    });

    testWidgets('picking a session makes it current and closes the popover', (
      tester,
    ) async {
      final shell = await _pumpShell(tester, open: _threeOpen);
      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spa-Francorchamps Endurance'));
      await tester.pumpAndSettle();

      expect(shell.open.first, spaSource);
      expect(shell.container.read(currentSessionProvider), spaSource);
      // Nothing was opened twice or dropped on the way.
      expect(shell.open, unorderedEquals(_threeOpen));
      expect(find.text('Open sessions'), findsNothing);
      // The badge now says Qualify.
      expect(
        find.descendant(
          of: _trigger('Spa-Francorchamps Endurance — Qualify  ·  3 open'),
          matching: find.text('Q'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('picking the current session just closes the popover', (
      tester,
    ) async {
      final shell = await _pumpShell(tester, open: _threeOpen);
      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sebring School Circuit'));
      await tester.pumpAndSettle();

      expect(shell.open, _threeOpen);
      expect(find.text('Open sessions'), findsNothing);
    });

    testWidgets('closing a session removes it and leaves the popover up', (
      tester,
    ) async {
      final shell = await _pumpShell(tester, open: _threeOpen);
      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();

      // The second row is Spa; its × is the second close button.
      await tester.tap(find.byTooltip('Close this session').at(1));
      await tester.pumpAndSettle();

      expect(shell.open, [sebringSource, interlagosSource]);
      expect(find.text('Spa-Francorchamps Endurance'), findsNothing);
      expect(find.text('Open sessions'), findsOneWidget);
    });

    testWidgets('closing the current session promotes the next', (tester) async {
      final shell = await _pumpShell(tester, open: _threeOpen);
      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close this session').first);
      await tester.pumpAndSettle();

      expect(shell.container.read(currentSessionProvider), spaSource);
    });

    testWidgets('closing the last session states that none is open', (
      tester,
    ) async {
      final shell = await _pumpShell(tester, open: const [sebringSource]);
      await tester.tap(_trigger('Sebring School Circuit — Race'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close this session'));
      await tester.pumpAndSettle();

      expect(shell.open, isEmpty);
      expect(find.textContaining('No session is open.'), findsOneWidget);
      expect(find.text('Open file…'), findsOneWidget);
    });

    testWidgets('"Open file…" opens the picker and closes the popover', (
      tester,
    ) async {
      final shell = await _pumpShell(tester, open: _threeOpen);
      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open file…'));
      await tester.pumpAndSettle();

      expect(shell.import.picks, 1);
      expect(find.text('Open sessions'), findsNothing);
    });

    testWidgets('"Open file…" is inert while an import runs', (tester) async {
      final busy = _FakeImport(initial: const SessionImportBusy());
      await _pumpShell(tester, open: _threeOpen, import: busy);
      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();

      expect(find.text('Opening…'), findsOneWidget);
      await tester.tap(find.text('Opening…'));
      await tester.pumpAndSettle();

      expect(busy.picks, 0);
    });

    testWidgets('a tap elsewhere closes it', (tester) async {
      await _pumpShell(tester, open: _threeOpen);
      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();
      expect(find.text('Open sessions'), findsOneWidget);

      await tester.tapAt(const Offset(900, 400));
      await tester.pumpAndSettle();

      expect(find.text('Open sessions'), findsNothing);
    });

    testWidgets('a second tap on the badge closes it', (tester) async {
      await _pumpShell(tester, open: _threeOpen);
      final badge = find.byIcon(Icons.add);
      expect(badge, findsNothing);

      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();
      expect(find.text('Open sessions'), findsOneWidget);

      // The tooltip is suppressed while it is open, so find the badge by the
      // type code it carries.
      await tester.tap(find.text('R').first);
      await tester.pumpAndSettle();

      expect(find.text('Open sessions'), findsNothing);
    });

    testWidgets('a popover opened from an empty rail invites a file', (
      tester,
    ) async {
      await _pumpShell(tester);
      await tester.tap(_trigger('No session open — click to open a file'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No session is open.'), findsOneWidget);
      expect(find.text('Open file…'), findsOneWidget);
    });

    testWidgets('prints the shortcut for "Open file…"', (tester) async {
      await _pumpShell(tester);
      await tester.tap(_trigger('No session open — click to open a file'));
      await tester.pumpAndSettle();

      expect(find.text('Ctrl+O'), findsOneWidget);
    });
  });

  group('session switcher: keyboard', () {
    testWidgets('Enter opens it and focus lands on the first row', (
      tester,
    ) async {
      final shell = await _pumpShell(tester, open: _threeOpen);
      await _focusTrigger(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Open sessions'), findsOneWidget);

      final focused = FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<Hoverable>();
      expect(focused?.semanticLabel, 'Sebring School Circuit, current session');

      // Down to the second row, Enter picks it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(shell.open.first, spaSource);
      expect(find.text('Open sessions'), findsNothing);
    });

    testWidgets('Escape closes it and gives focus back to the badge', (
      tester,
    ) async {
      await _pumpShell(tester, open: _threeOpen);
      await _focusTrigger(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Open sessions'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Open sessions'), findsNothing);
      final focused = FocusManager.instance.primaryFocus!.context!
          .findAncestorWidgetOfExactType<Hoverable>();
      expect(focused?.semanticLabel, startsWith('Sessions:'));
    });

    testWidgets('Tab stays inside the popover', (tester) async {
      await _pumpShell(tester, open: _threeOpen);
      await _focusTrigger(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Three rows, each with a row stop and a close button, then Open file…:
      // 7 stops. Three times that many Tabs, and focus must still be in the
      // popover at every step — never back out in the rail or on the page.
      final seen = <String?>{};
      for (var i = 0; i < 21; i++) {
        seen.add(_focusedLabel());
        await _tabTimes(tester, 1);
      }
      seen.add(_focusedLabel());

      expect(seen, {
        'Sebring School Circuit, current session',
        'Spa-Francorchamps Endurance',
        'José Carlos Pace',
        'Open file',
      });
    });
  });

  group('session switcher: motion', () {
    testWidgets('normal motion: the popover arrives over time', (tester) async {
      await _pumpShell(tester, open: _threeOpen);

      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pump();
      expect(_popoverOpacity(tester), 0);

      await tester.pump(const Duration(milliseconds: 60));
      expect(_popoverOpacity(tester), inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(_popoverOpacity(tester), 1);
    });

    testWidgets('normal motion: it leaves over time, then is gone', (
      tester,
    ) async {
      await _pumpShell(tester, open: _threeOpen);
      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(900, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Open sessions'), findsOneWidget);
      expect(_popoverOpacity(tester), inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(find.text('Open sessions'), findsNothing);
    });

    testWidgets('reduced motion: it is there, whole, on the first frame', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pumpShell(tester, open: _threeOpen);

      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pump();

      expect(find.text('Open sessions'), findsOneWidget);
      expect(_popoverOpacity(tester), 1);
    });

    testWidgets('reduced motion: it is gone on the frame after it is dismissed', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pumpShell(tester, open: _threeOpen);
      await tester.tap(_trigger('Sebring School Circuit — Race  ·  3 open'));
      await tester.pump();

      await tester.tapAt(const Offset(900, 400));
      await tester.pump();
      await tester.pump();

      expect(find.text('Open sessions'), findsNothing);
    });

    testWidgets('reduced motion: nav slots change state without travelling', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pumpShell(tester);

      final containers = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(Hoverable),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(containers, isNotEmpty);
      expect(containers.every((c) => c.duration == Duration.zero), isTrue);
    });
  });
}
