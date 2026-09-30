/// The shell's keyboard layer (SPEC.md §10: "keyboard navigation on
/// desktop/web") and the one "open a file" action every entry point shares.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/session_library/application/session_import.dart';

/// Cmd/Ctrl+O — the same action as the library's "Open file" button and the
/// switcher's "Open file…" row.
class OpenFileIntent extends Intent {
  const OpenFileIntent();
}

/// Cmd/Ctrl+1…9 — jump to the nth nav destination, counted from 1 on the
/// keyboard and from 0 here.
class GoToDestinationIntent extends Intent {
  const GoToDestinationIntent(this.index);

  final int index;
}

/// How many destinations get a number. Nine, because that is how many digit
/// keys there are: the ten after that stay reachable by mouse and Tab, which
/// is a smaller loss than a shortcut table that needs a second modifier.
const shellDigitShortcutCount = 9;

const _digitKeys = [
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

/// True where the command key is the platform's shortcut modifier.
bool usesCommandKey(TargetPlatform platform) =>
    platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;

/// The shell's shortcut table for [platform]: Cmd on Apple platforms, Ctrl
/// everywhere else — the modifier each platform already uses for "open" and
/// for "go to tab", so nothing here has to be learned.
///
/// Built from a [TargetPlatform] argument rather than read from
/// [defaultTargetPlatform] inside, so a test can state both tables without
/// overriding a global.
Map<ShortcutActivator, Intent> shellShortcuts(TargetPlatform platform) {
  final command = usesCommandKey(platform);
  SingleActivator chord(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: command, control: !command);

  return {
    chord(LogicalKeyboardKey.keyO): const OpenFileIntent(),
    for (var i = 0; i < shellDigitShortcutCount; i++)
      chord(_digitKeys[i]): GoToDestinationIntent(i),
  };
}

/// A shortcut as it should be printed in a tooltip: `⌘3` on Apple platforms,
/// `Ctrl+3` elsewhere. [key] is the character on the key.
String shortcutLabel(String key, TargetPlatform platform) =>
    usesCommandKey(platform) ? '⌘$key' : 'Ctrl+$key';

/// Opens the platform file picker and reports where the outcome will be seen.
///
/// The library screen shows an import failure (its `_ImportError` banner) and
/// nothing else does, so a failure that happened while the user was looking at
/// the trace would be recorded in `sessionImportProvider` and invisible. It is
/// taken to the library rather than given a second, weaker error surface here:
/// one place says what went wrong, with the details behind a disclosure.
/// Success needs no such trip — the opened session becomes current, and the
/// rail badge changes to say so.
///
/// Does nothing while an import is already running, the same rule the
/// library's button follows by disabling itself.
Future<void> openFileFromShell(BuildContext context, WidgetRef ref) async {
  if (ref.read(sessionImportProvider) is SessionImportBusy) return;
  await ref.read(sessionImportProvider.notifier).pickFile();
  if (!context.mounted) return;

  final outcome = ref.read(sessionImportProvider);
  if (outcome is! SessionImportFailure) return;
  final location = GoRouterState.of(context).uri.path;
  if (!location.startsWith('/sessions')) context.go('/sessions');
}
