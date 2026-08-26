// The macOS entitlements are behaviour, not configuration (SPEC.md §9.2, §13).
//
// This guards a bug that shipped once and produced no visible symptom: with
// App Sandbox off and no `files.user-selected` key, `file_picker_darwin`'s
// `SecTaskCopyValueForEntitlement` gate rejects every open panel — measured at
// ~6 ms, before any window appears — so "Open file" looks like a dead button.
// The plugin never asks whether the process is sandboxed, so turning the
// sandbox off does not opt out of the check.
//
// Asserted against the checked-in plists rather than a running app because the
// failure is a missing key in source, and this way it is caught by a plain
// `flutter test` on any platform instead of only by a human clicking a button
// on a Mac.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Maps `<key>name</key><true/>` pairs out of an entitlements plist.
///
/// A real plist parser would be the right tool for arbitrary input; these two
/// files are flat string→bool dictionaries we write ourselves, so matching the
/// element that follows each key is enough and keeps the test dependency-free.
Map<String, bool> _entitlements(String xml) {
  final stripped = xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final pattern = RegExp(r'<key>([^<]+)</key>\s*<(true|false)\s*/>');
  return {
    for (final m in pattern.allMatches(stripped))
      m.group(1)!: m.group(2) == 'true',
  };
}

void main() {
  for (final name in ['DebugProfile', 'Release']) {
    group('macos/Runner/$name.entitlements', () {
      final file = File('macos/Runner/$name.entitlements');
      late Map<String, bool> entitlements;

      setUpAll(() {
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
        entitlements = _entitlements(file.readAsStringSync());
      });

      test('grants user-selected file access', () {
        expect(
          entitlements['com.apple.security.files.user-selected.read-only'] ??
              entitlements['com.apple.security.files.user-selected.read-write'],
          isTrue,
          reason: 'without one of these, file_picker_darwin refuses to open '
              'the panel at all (ENTITLEMENT_NOT_FOUND) and the import button '
              'silently does nothing',
        );
      });

      test('keeps App Sandbox off', () {
        // §13: distribution is outside the Mac App Store, and the whole app is
        // reading user-chosen files from anywhere on disk. Flipping this on
        // would need security-scoped bookmarks the app has no other use for.
        expect(entitlements['com.apple.security.app-sandbox'], isFalse);
      });
    });
  }
}
