/// The few preferences Pace Reader keeps between runs: how big the interface
/// is, and how wide the map/detail pane beside the traces is.
///
/// A small JSON file in the app-support directory rather than a database: two
/// numbers, read once at start-up. Under `flutter test` nothing is read or
/// written (the runner sets `FLUTTER_TEST`), for the same reason the session
/// index goes in memory there: a test must neither depend on nor overwrite the
/// developer's own preferences.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppSettings {
  const AppSettings({
    this.uiScale = defaultUiScale,
    this.sidePaneWidth = defaultSidePaneWidth,
  });

  /// The interface zoom steps, as browsers offer them: each press of Ctrl +/-
  /// moves one along.
  static const uiScaleSteps = [0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0];
  static const defaultUiScale = 1.0;
  static const defaultSidePaneWidth = 360.0;
  static const minSidePaneWidth = 240.0;

  /// 1.0 is the designed size; 1.25 draws everything a quarter larger and
  /// lays it out in a window a fifth narrower, so the breakpoints respond.
  final double uiScale;

  /// The width of the pane beside the traces, in logical pixels at scale 1.
  final double sidePaneWidth;

  AppSettings copyWith({double? uiScale, double? sidePaneWidth}) => AppSettings(
        uiScale: uiScale ?? this.uiScale,
        sidePaneWidth: sidePaneWidth ?? this.sidePaneWidth,
      );

  Map<String, Object?> toJson() =>
      {'uiScale': uiScale, 'sidePaneWidth': sidePaneWidth};

  static AppSettings fromJson(Map<String, Object?> json) {
    double? number(String key) => (json[key] as num?)?.toDouble();
    final scale = number('uiScale');
    final width = number('sidePaneWidth');
    return AppSettings(
      uiScale: scale == null
          ? defaultUiScale
          : scale.clamp(uiScaleSteps.first, uiScaleSteps.last),
      sidePaneWidth: width == null
          ? defaultSidePaneWidth
          : width.clamp(minSidePaneWidth, 1200.0),
    );
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  /// Whether the user changed anything before the file was read: their change
  /// then wins over what was on disk.
  var _touched = false;

  Future<File?> _file() async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return null;
    try {
      final dir = await getApplicationSupportDirectory();
      return File(p.join(dir.path, 'settings.json'));
    } on Object {
      return null;
    }
  }

  Future<void> _load() async {
    final file = await _file();
    if (file == null || !await file.exists()) return;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is Map<String, Object?> && !_touched) {
        state = AppSettings.fromJson(json);
      }
    } on Object {
      // A damaged file is the defaults, not an error to show.
    }
  }

  Future<void> _save() async {
    final file = await _file();
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(state.toJson()));
    } on Object {
      // Preferences are a convenience; failing to keep them is not worth
      // interrupting the user for.
    }
  }

  void setUiScale(double scale) {
    _touched = true;
    state = state.copyWith(uiScale: scale);
    _save();
  }

  /// One step larger (+1) or smaller (-1) along [AppSettings.uiScaleSteps].
  void stepUiScale(int direction) {
    const steps = AppSettings.uiScaleSteps;
    var nearest = 0;
    for (var i = 0; i < steps.length; i++) {
      if ((steps[i] - state.uiScale).abs() <
          (steps[nearest] - state.uiScale).abs()) {
        nearest = i;
      }
    }
    setUiScale(steps[(nearest + direction).clamp(0, steps.length - 1)]);
  }

  void resetUiScale() => setUiScale(AppSettings.defaultUiScale);

  /// Moves the pane's edge. [commit] is false while the pointer is still
  /// dragging, so the file is written once, when it lets go.
  void setSidePaneWidth(double width, {bool commit = true}) {
    _touched = true;
    state = state.copyWith(
      sidePaneWidth: width.clamp(AppSettings.minSidePaneWidth, 1200.0),
    );
    if (commit) _save();
  }

  void resetSidePaneWidth() =>
      setSidePaneWidth(AppSettings.defaultSidePaneWidth);
}
