/// `metadata.CarClass`, read into the class it names (SPEC.md §5.1, §4).
///
/// The file writes a short code — `Hyper`, `GT3`, `LMP2_ELMS`, `LMP3` across
/// the user's 709 recordings — and every screen used to print it verbatim.
/// This is the one place that code becomes a name. The raw string stays the
/// key everywhere something is grouped or compared (the personal-best key,
/// the library's class filter): a display name is never a key.
///
/// A class this build does not know keeps its raw string as its name, so a
/// class added by a game update costs a colour, never legibility.
library;

/// The classes LMU races, in running order: fastest first.
enum CarClassKind { hypercar, lmp2, lmp3, lmgte, lmgt3, unknown }

class CarClass {
  const CarClass._(this.raw, this.kind, {this.elms = false});

  /// Reads the file's `CarClass` value. Case, spaces and underscores are
  /// ignored, and the long names (`LMGT3`, `Hypercar`) read the same as the
  /// codes, so nothing depends on which spelling a build writes.
  factory CarClass.parse(String raw) {
    final code = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return switch (code) {
      'HYPER' ||
      'HYPERCAR' ||
      'HY' ||
      'LMH' ||
      'LMDH' => CarClass._(raw, CarClassKind.hypercar),
      'LMP2ELMS' || 'P2ELMS' => CarClass._(raw, CarClassKind.lmp2, elms: true),
      'LMP2' || 'P2' => CarClass._(raw, CarClassKind.lmp2),
      'LMP3' || 'P3' => CarClass._(raw, CarClassKind.lmp3),
      'GTE' || 'LMGTE' => CarClass._(raw, CarClassKind.lmgte),
      'GT3' || 'LMGT3' => CarClass._(raw, CarClassKind.lmgt3),
      _ => CarClass._(raw, CarClassKind.unknown),
    };
  }

  /// Exactly as the file wrote it.
  final String raw;

  final CarClassKind kind;

  /// The European Le Mans Series' LMP2, which runs without the WEC's
  /// restrictor. The game marks it with an orange corner on the LMP2 badge
  /// rather than giving it a class of its own, and so does Pace Reader.
  final bool elms;

  /// "Hypercar", "LMGT3", … — the raw string when the class is unknown.
  String get name => switch (kind) {
    CarClassKind.hypercar => 'Hypercar',
    CarClassKind.lmp2 => 'LMP2',
    CarClassKind.lmp3 => 'LMP3',
    CarClassKind.lmgte => 'LMGTE',
    CarClassKind.lmgt3 => 'LMGT3',
    CarClassKind.unknown => raw.trim().isEmpty ? 'Unknown class' : raw.trim(),
  };

  /// Two or three letters, for a badge in a row of text: `HY`, `P2`, `GT3`.
  String get shortCode => switch (kind) {
    CarClassKind.hypercar => 'HY',
    CarClassKind.lmp2 => 'P2',
    CarClassKind.lmp3 => 'P3',
    CarClassKind.lmgte => 'GTE',
    CarClassKind.lmgt3 => 'GT3',
    CarClassKind.unknown => name,
  };

  /// The name where only text can carry it — a tooltip, a filter chip, a
  /// sentence. Unlike [name], it tells the ELMS LMP2 from the WEC one, since
  /// in text there is no orange corner to do it.
  String get label => elms ? '$name ELMS' : name;

  /// Sort position: running order, ELMS LMP2 (unrestricted, so quicker)
  /// ahead of the WEC's, unknown classes last.
  int get order => kind.index * 2 + (elms ? 0 : 1);

  @override
  bool operator ==(Object other) =>
      other is CarClass &&
      other.kind == kind &&
      other.elms == elms &&
      (kind != CarClassKind.unknown || other.raw == raw);

  @override
  int get hashCode =>
      Object.hash(kind, elms, kind == CarClassKind.unknown ? raw : null);

  @override
  String toString() => 'CarClass($raw → $label)';
}
