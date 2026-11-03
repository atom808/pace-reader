/// Which of the game's circuit logos a recording's `TrackName` takes.
///
/// A logo names the *circuit*, not the course: Sebring and Sebring School
/// wear the same one. So only the circuit decides it; the one exception is
/// the game's own, where Silverstone has an ELMS logo that goes with an ELMS
/// layout.
///
/// Matching is by keyword rather than by exact string, because a name here
/// has been seen in more than one spelling ("Autódromo José Carlos Pace",
/// "Interlagos") and a missed match falls back to text, never to a wrong logo.
library;

/// The file name (without extension) of the game's logo in
/// `start\images\tracks\logos`, or null when the circuit is not one the game
/// has a logo for.
String? circuitLogoFor(String trackName, [String trackLayout = '']) {
  final name = trackName.toLowerCase();
  bool has(String keyword) => name.contains(keyword);

  if (has('sarthe') || has('le mans')) return 'lemanswec';
  if (has('francorchamps') || name.trim() == 'spa') return 'spawec';
  if (has('interlagos') || has('carlos pace')) return 'interlagoswec';
  if (has('imola') || has('enzo e dino')) return 'imolawec';
  if (has('monza')) return 'monzawec';
  if (has('sebring')) return 'sebringwec';
  if (has('americas')) return 'cotawec';
  if (has('daytona')) return 'daytona';
  if (has('bahrain')) return 'bahrainwec';
  if (has('fuji')) return 'fujiwec';
  if (has('barcelona') || has('catalunya')) return 'barcelonaelms';
  if (has('ricard')) return 'paulricardelms';
  if (has('algarve') || has('portim')) return 'portimaowec';
  if (has('lusail') || has('qatar')) return 'qatarwec';
  if (has('road atlanta')) return 'roadatlanta';
  if (has('laguna')) return 'lagunaseca';
  if (has('long beach')) return 'longbeach';
  if (has('silverstone')) {
    return trackLayout.toLowerCase().contains('elms')
        ? 'silverstoneelms'
        : 'silverstone';
  }
  return null;
}
