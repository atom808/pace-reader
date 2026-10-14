/// Searching, filtering and ranking the Session Library (SPEC.md §8.1).
///
/// Plain functions over [LibraryEntry] lists, so a `flutter test` covers
/// every rule here without a database — and so desktop's drift index and
/// web's in-memory one cannot disagree about them (see
/// `session_index_store.dart`).
library;

import '../../../data/models/models.dart';
import '../../../data/reference/car_class.dart';
import '../data/library_entry.dart';

/// What the library list is currently narrowed to.
///
/// Within a group the chips are alternatives (Practice *or* Race); across
/// groups they narrow (Race *and* GT3). An empty group means "any" rather
/// than "none", so a fresh query shows everything.
class LibraryQuery {
  const LibraryQuery({
    this.search = '',
    this.sessionTypes = const {},
    this.carClasses = const {},
    this.tracks = const {},
  });

  final String search;
  final Set<SessionType> sessionTypes;
  final Set<String> carClasses;
  final Set<TrackLayoutKey> tracks;

  bool get isEmpty =>
      search.trim().isEmpty &&
      sessionTypes.isEmpty &&
      carClasses.isEmpty &&
      tracks.isEmpty;

  /// How many chips are on — what the "Clear" affordance counts.
  int get activeFilterCount =>
      sessionTypes.length + carClasses.length + tracks.length;

  LibraryQuery copyWith({
    String? search,
    Set<SessionType>? sessionTypes,
    Set<String>? carClasses,
    Set<TrackLayoutKey>? tracks,
  }) => LibraryQuery(
    search: search ?? this.search,
    sessionTypes: sessionTypes ?? this.sessionTypes,
    carClasses: carClasses ?? this.carClasses,
    tracks: tracks ?? this.tracks,
  );

  bool matches(LibraryEntry entry) {
    if (sessionTypes.isNotEmpty && !sessionTypes.contains(entry.sessionType)) {
      return false;
    }
    if (carClasses.isNotEmpty && !carClasses.contains(entry.carClass)) {
      return false;
    }
    if (tracks.isNotEmpty && !tracks.contains(entry.trackKey)) return false;
    return matchesSearch(entry, search);
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryQuery &&
      other.search == search &&
      _sameSet(other.sessionTypes, sessionTypes) &&
      _sameSet(other.carClasses, carClasses) &&
      _sameSet(other.tracks, tracks);

  @override
  int get hashCode => Object.hash(
    search,
    Object.hashAllUnordered(sessionTypes),
    Object.hashAllUnordered(carClasses),
    Object.hashAllUnordered(tracks),
  );

  static bool _sameSet<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Whether every word of [search] appears in the entry's track, layout, car
/// or driver — §8.1's "search by track/car", plus the driver, since a shared
/// rig's library is several people's.
///
/// Word-wise rather than one substring, so "sebring gt3"-style queries that
/// span two fields work; and accent-folded, because the first sample on hand
/// is *Autódromo José Carlos Pace* and nobody types the accents to find it.
/// The class is searched by both its code and its name: the file's "Hyper"
/// is what the chip used to say, "Hypercar" is what it says now, and either
/// is what people type.
bool matchesSearch(LibraryEntry entry, String search) {
  final words = foldForSearch(search)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;
  final haystack = foldForSearch(
    [
      entry.trackName,
      entry.trackLayout,
      entry.carName,
      entry.carClass,
      CarClass.parse(entry.carClass).label,
      entry.driverName,
    ].join(' '),
  );
  return words.every(haystack.contains);
}

/// Lowercase with Latin diacritics removed (`Autódromo José` → `autodromo
/// jose`).
///
/// A lookup over the Latin-1 and Latin Extended-A letters rather than full
/// Unicode normalisation: track, car and driver names in LMU are Latin
/// script, and a table is a dozen lines where NFD would be a dependency.
String foldForSearch(String input) {
  final lower = input.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_fold[ch] ?? ch);
  }
  return out.toString();
}

const _foldGroups = {
  'a': 'àáâãäåāăą',
  'c': 'çćĉċč',
  'd': 'ďđ',
  'e': 'èéêëēĕėęě',
  'g': 'ĝğġģ',
  'i': 'ìíîïĩīĭįı',
  'l': 'ĺļľŀł',
  'n': 'ñńņňŉ',
  'o': 'òóôõöøōŏő',
  'r': 'ŕŗř',
  's': 'śŝşšß',
  't': 'ţťŧ',
  'u': 'ùúûüũūŭůűų',
  'y': 'ýÿŷ',
  'z': 'źżž',
};

final Map<String, String> _fold = {
  for (final MapEntry(key: plain, value: accented) in _foldGroups.entries)
    for (final rune in accented.runes) String.fromCharCode(rune): plain,
};

/// The library narrowed by [query], keeping the incoming order (newest
/// first, from the store).
List<LibraryEntry> applyLibraryQuery(
  List<LibraryEntry> entries,
  LibraryQuery query,
) => query.isEmpty ? entries : entries.where(query.matches).toList();

/// The fastest session per [PersonalBestKey].
class PersonalBest {
  const PersonalBest({
    required this.path,
    required this.lapSeconds,
    required this.lapIndex,
    required this.sessionCount,
  });

  /// The session that holds it.
  final String path;
  final double lapSeconds;
  final int lapIndex;

  /// How many recordings in this scope have a timed lap — the badge's
  /// tooltip says "fastest of N", because a best out of one session is true
  /// but thin, and the reader should know which it is.
  final int sessionCount;
}

/// Personal bests over the **whole** library, whatever the filter.
///
/// A best is a fact about everything the driver has recorded, not about
/// what the list happens to show: narrowing to Race sessions must not crown
/// a slower race lap as "PB" when a faster practice lap sits one chip away.
///
/// Sessions without a timed lap cannot hold one and do not count toward
/// [PersonalBest.sessionCount]. Missing files still do — the index kept
/// their lap times, and a best the driver set is not unset by moving a file.
/// On an exact tie the earlier recording keeps it: it set the time first.
///
/// Copies of one recording — the same [RecordingIdentity] under two paths —
/// count once in [PersonalBest.sessionCount]: a best set once and copied to
/// another folder is not "fastest of 2".
Map<PersonalBestKey, PersonalBest> personalBestsOf(
  Iterable<LibraryEntry> entries,
) {
  final best = <PersonalBestKey, LibraryEntry>{};
  final recordings = <PersonalBestKey, Set<RecordingIdentity>>{};
  for (final entry in entries) {
    final seconds = entry.bestLapSeconds;
    if (seconds == null || entry.bestLapIndex == null) continue;
    final key = entry.personalBestKey;
    (recordings[key] ??= {}).add(entry.recordingIdentity);
    final holder = best[key];
    if (holder == null ||
        seconds < holder.bestLapSeconds! ||
        (seconds == holder.bestLapSeconds! && _recordedBefore(entry, holder))) {
      best[key] = entry;
    }
  }
  return {
    for (final MapEntry(:key, value: holder) in best.entries)
      key: PersonalBest(
        path: holder.path,
        lapSeconds: holder.bestLapSeconds!,
        lapIndex: holder.bestLapIndex!,
        sessionCount: recordings[key]!.length,
      ),
  };
}

bool _recordedBefore(LibraryEntry a, LibraryEntry b) {
  final ra = a.recordedAt, rb = b.recordedAt;
  if (ra != null && rb != null && ra != rb) return ra.isBefore(rb);
  return a.path.compareTo(b.path) < 0;
}

/// One chip: a value, its label, and how many sessions carry it.
class LibraryFacet<T> {
  const LibraryFacet({
    required this.value,
    required this.label,
    required this.count,
  });

  final T value;
  final String label;
  final int count;
}

/// The chips the filter bar offers — only values that occur in the library,
/// so no chip ever leads to an empty list on its own.
class LibraryFacets {
  const LibraryFacets({
    required this.sessionTypes,
    required this.carClasses,
    required this.tracks,
  });

  factory LibraryFacets.from(List<LibraryEntry> entries) {
    final types = <SessionType, int>{};
    final classes = <String, int>{};
    final tracks = <TrackLayoutKey, int>{};
    final labels = <TrackLayoutKey, String>{};
    for (final e in entries) {
      types[e.sessionType] = (types[e.sessionType] ?? 0) + 1;
      classes[e.carClass] = (classes[e.carClass] ?? 0) + 1;
      tracks[e.trackKey] = (tracks[e.trackKey] ?? 0) + 1;
      labels[e.trackKey] = e.circuitLabel;
    }
    return LibraryFacets(
      // Session order, not alphabetical: Practice, Qualify, Race is how a
      // weekend runs.
      sessionTypes: [
        for (final type in SessionType.values)
          if (types[type] case final count?)
            LibraryFacet(value: type, label: type.rawValue, count: count),
      ],
      carClasses: [
        // Running order, fastest first, as a timing screen lists classes.
        // Labelled by name, as every screen's class chip now is: a filter
        // that said "Hyper" beside a chip that says HYPERCAR would read as two
        // different classes. The value stays the raw code, which is the key.
        for (final c in classes.keys.toList()..sort(_byRunningOrder))
          LibraryFacet(
            value: c,
            label: CarClass.parse(c).label,
            count: classes[c]!,
          ),
      ],
      tracks: [
        for (final key
            in tracks.keys.toList()
              ..sort((a, b) => labels[a]!.compareTo(labels[b]!)))
          LibraryFacet(value: key, label: labels[key]!, count: tracks[key]!),
      ],
    );
  }

  final List<LibraryFacet<SessionType>> sessionTypes;
  final List<LibraryFacet<String>> carClasses;
  final List<LibraryFacet<TrackLayoutKey>> tracks;
}

/// Raw class codes by [CarClass.order], then alphabetically, so two classes
/// this build does not know still sort the same way every time.
int _byRunningOrder(String a, String b) {
  final byOrder = CarClass.parse(a).order.compareTo(CarClass.parse(b).order);
  return byOrder != 0 ? byOrder : a.compareTo(b);
}
