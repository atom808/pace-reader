/// The published outlines bundled with the app (map stage proposal §3.4,
/// D6): three circuits from the TUM racetrack database, for the layouts the
/// library knew least when they were chosen. `NOTICE.md` beside them says
/// where they come from and under what licence.
library;

import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart' show rootBundle;

const _folder = 'assets/track_outlines/tum';

/// Which survey covers a track, by a word of the game's track name.
const _surveys = {
  'Bahrain': 'Sakhir',
  'Barcelona': 'Catalunya',
  'Monza': 'Monza',
};

/// The bundled outline for [trackName], or null for a track without one.
/// Each covers the circuit's main layout; a fit says whether it is the
/// layout being driven.
String? publicOutlineAsset(String trackName) {
  for (final MapEntry(:key, :value) in _surveys.entries) {
    if (trackName.contains(key)) return '$_folder/$value.csv';
  }
  return null;
}

Future<String> loadPublicOutline(String asset) => rootBundle.loadString(asset);

/// The outlines' licence, for the app's licence page.
Stream<LicenseEntryWithLineBreaks> publicOutlineLicences() async* {
  yield LicenseEntryWithLineBreaks(const [
    'TUM racetrack database (track outlines)',
  ], await rootBundle.loadString('$_folder/LICENSE'));
}
