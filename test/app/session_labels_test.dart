import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/app/session_labels.dart';

import '../fixtures/sample_sessions.dart';

void main() {
  group('shortTrackName', () {
    test('drops the boilerplate of the three real track names', () {
      // Names as the three sample files write them.
      expect(shortTrackName('Autódromo José Carlos Pace'), 'José Carlos Pace');
      expect(
        shortTrackName('Circuit de Spa-Francorchamps'),
        'Spa-Francorchamps',
      );
      expect(shortTrackName('Sebring International Raceway'), 'Sebring');
    });

    test('is not case- or accent-sensitive about the words it drops', () {
      expect(shortTrackName('AUTODROMO Nazionale Monza'), 'Monza');
      expect(shortTrackName('Autódromo Internacional do Algarve'), 'Algarve');
    });

    test('leaves a name it has nothing to say about alone', () {
      expect(shortTrackName('Circuit of the Americas'), 'Circuit of the Americas');
      expect(shortTrackName('Silverstone Circuit'), 'Silverstone Circuit');
    });

    test('never returns something shorter than a name', () {
      // Stripping "Speedway" from "Speedway" would leave nothing.
      expect(shortTrackName('Speedway'), 'Speedway');
      expect(shortTrackName('  '), '');
    });
  });

  group('shortLayoutName', () {
    test('is null when the layout is the track name (Interlagos)', () {
      expect(
        shortLayoutName(
          interlagosMetadata.trackName,
          interlagosMetadata.trackLayout,
        ),
        isNull,
      );
    });

    test('keeps only what follows the full track name (Spa)', () {
      expect(
        shortLayoutName(spaMetadata.trackName, spaMetadata.trackLayout),
        'Endurance',
      );
    });

    test('keeps only what follows the short track name (Sebring)', () {
      // "Sebring School Circuit" does not start with "Sebring International
      // Raceway", but does start with "Sebring".
      expect(
        shortLayoutName(sebringMetadata.trackName, sebringMetadata.trackLayout),
        'School Circuit',
      );
    });

    test('keeps a layout that shares nothing with the track whole', () {
      expect(shortLayoutName('Le Mans', 'Bugatti'), 'Bugatti');
    });

    test('is null for an empty layout', () {
      expect(shortLayoutName('Le Mans', ''), isNull);
    });
  });

  group('shortCircuitTitle', () {
    test('names each real session in a few words', () {
      expect(shortCircuitTitle(interlagosMetadata), 'José Carlos Pace');
      expect(shortCircuitTitle(spaMetadata), 'Spa-Francorchamps Endurance');
      // The layout survives: the Race sample is the half-length School
      // Circuit, so "Sebring" alone would name the wrong course (§8.1).
      expect(shortCircuitTitle(sebringMetadata), 'Sebring School Circuit');
    });
  });
}
