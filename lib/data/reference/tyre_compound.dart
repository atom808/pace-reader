/// Tyre compounds: the setup's words and the `TyresCompound` event's numbers,
/// read into the compound they name (SPEC.md §15.20).
///
/// Neither source is enough alone:
/// - **The setup** (`WM_COMPOUND-W_xx`) names the compound each corner left
///   the garage on: "Soft", "Medium", "Hard", "Wet", or a used set as
///   "70% Medium". It cannot see a tyre change.
/// - **The event** records an index per corner all session, so it sees every
///   change. But the index is a place in the session's list of compounds,
///   not a code: the Alpine's Medium is 1 at Le Mans, where Soft is 0, and 0
///   at Laguna Seca, which offered no Soft.
///
/// [CompoundKey] joins the two. Measured over the user's 444 recordings
/// (2026-10-14):
/// - **The game keeps one order**: Soft, Medium, Hard, Wet, leaving out what
///   the session does not offer. In 425 files the setup's compound sits at
///   exactly the index that order gives it, with or without Soft. The rest
///   are a Cadillac weekend with a list of its own and races where the garage
///   changed tyres after the setup was written.
/// - **The setup's option range counts them**: `maxValue` is twice the
///   number of compounds (8 with all four, 6 without Soft, 4 for the GT3s,
///   LMP2s and LMP3s, which offer two) wherever the names fit the order.
///
/// So a car that starts on Medium at index 0 with three compounds has Medium,
/// Hard, Wet, and the Interlagos BMW's change to index 2 was to Wets, which
/// another recording's setup confirms by name.
library;

import '../models/corner.dart';

/// The compounds LMU races, in the order the game lists a session's
/// compounds (its index order).
enum CompoundKind {
  soft('Soft', 'S'),
  medium('Medium', 'M'),
  hard('Hard', 'H'),
  wet('Wet', 'W');

  const CompoundKind(this.label, this.letter);

  final String label;

  /// The one letter on a badge.
  final String letter;

  /// [text]'s compound, ignoring case: null for a word the game has not
  /// used for one.
  static CompoundKind? named(String text) {
    final word = text.trim().toLowerCase();
    for (final kind in values) {
      if (kind.label.toLowerCase() == word) return kind;
    }
    return null;
  }
}

/// Where a [CompoundMark]'s name came from, which its badge says.
enum CompoundNaming {
  /// The setup's own word.
  setup,

  /// The event's index, named through the game's order (see [CompoundKey]).
  gameOrder,

  /// An index the file cannot name.
  unnamed,
}

/// One corner's compound, as a badge shows it.
class CompoundMark {
  const CompoundMark({
    this.kind,
    this.name,
    this.index,
    this.treadLeft,
    this.naming = CompoundNaming.setup,
    this.reason,
    this.possible = const [],
  });

  /// The setup's text for a corner: "Medium", "70% Medium". Null for an
  /// empty entry. A word the game has not used for a compound keeps the
  /// word, so a compound a game update adds still reads.
  static CompoundMark? ofSetup(String? text) {
    final match = RegExp(r'^\s*(?:(\d+(?:\.\d+)?)\s*%\s*)?(.*?)\s*$')
        .firstMatch(text ?? '');
    final word = match?[2] ?? '';
    if (word.isEmpty) return null;
    return CompoundMark(
      kind: CompoundKind.named(word),
      name: word,
      treadLeft: match![1] == null ? null : double.parse(match[1]!),
    );
  }

  /// An index the file cannot name; [possible] are the compounds the game's
  /// order leaves open for it.
  const CompoundMark.unnamed(
    int this.index, {
    this.reason,
    this.possible = const [],
  }) : kind = null,
       name = null,
       treadLeft = null,
       naming = CompoundNaming.unnamed;

  final CompoundKind? kind;

  /// The setup's word, when that is where the mark came from.
  final String? name;

  /// The event's index, when that is where the mark came from.
  final int? index;

  /// The tread a used set had left, %: 70 for "70% Medium". Only the setup
  /// says it, and only for the set the car started on.
  final double? treadLeft;

  final CompoundNaming naming;

  /// Why the index reads as this compound, or why it cannot be named.
  final String? reason;

  /// For an unnamed index: the compounds it could be.
  final List<CompoundKind> possible;

  bool get isNamed => kind != null || name != null;

  /// "Medium"; the setup's word for a compound the game has not used
  /// before; "compound 2" for an index nothing names.
  String get label => kind?.label ?? name ?? 'compound $index';

  @override
  bool operator ==(Object other) =>
      other is CompoundMark &&
      other.kind == kind &&
      other.name == name &&
      other.index == index &&
      other.treadLeft == treadLeft &&
      other.naming == naming;

  @override
  int get hashCode => Object.hash(kind, name, index, treadLeft, naming);

  @override
  String toString() => 'CompoundMark($label, ${naming.name})';
}

/// What a recording's `TyresCompound` indices name.
class CompoundKey {
  const CompoundKey._(this._marks, this.count);

  /// Names nothing: every index reads "compound n".
  static const none = CompoundKey._({}, null);

  /// Reads the indices from the setup and the event's first row.
  ///
  /// - [names]: each corner's `WM_COMPOUND-W_xx` text.
  /// - [options]: each corner's `maxValue` there, which counts the
  ///   session's compounds.
  /// - [start]: each corner's `TyresCompound` index at recording start.
  ///
  /// The setup's compound names its starting index, as SPEC §8.13.6 has it,
  /// unless the game's order rules that out (a Soft is never index 3: the
  /// setup is older than the tyres). Every other index is named where the
  /// order, those names and the count leave only one compound for it. When
  /// the count and the names disagree, the names win and the count is
  /// dropped: that is the Cadillac weekend whose list starts on Medium.
  factory CompoundKey.resolve({
    required Map<Corner, String> names,
    Map<Corner, int> options = const {},
    required Map<Corner, int> start,
  }) {
    final anchors = <int, CompoundKind>{};
    final clashes = <int>{};
    for (final MapEntry(key: corner, value: index) in start.entries) {
      final kind = CompoundMark.ofSetup(names[corner])?.kind;
      if (kind == null || index < 0 || index > kind.index) continue;
      if (anchors[index] case final other? when other != kind) {
        clashes.add(index);
      }
      anchors[index] = kind;
    }
    for (final index in clashes) {
      anchors.remove(index);
    }

    final counts = {
      for (final max in options.values)
        if (max.isEven && max >= 2 && max <= 2 * CompoundKind.values.length)
          max ~/ 2,
    };
    final count = counts.length == 1 ? counts.single : null;

    bool fits(List<CompoundKind> list) => anchors.entries.every(
      (a) => a.key < list.length && list[a.key] == a.value,
    );
    var lists = _lists(count).where(fits).toList();
    var counted = count;
    if (lists.isEmpty && count != null) {
      lists = _lists(null).where(fits).toList();
      counted = null;
    }

    final basis = _basis(anchors, counted);
    final marks = <int, CompoundMark>{};
    for (var i = 0; i < CompoundKind.values.length; i++) {
      final open = [
        for (final kind in CompoundKind.values)
          if (lists.any((l) => l.length > i && l[i] == kind)) kind,
      ];
      if (open.length == 1) {
        final kind = open.single;
        final fromSetup = anchors[i] == kind;
        marks[i] = CompoundMark(
          kind: kind,
          index: i,
          naming: fromSetup ? CompoundNaming.setup : CompoundNaming.gameOrder,
          reason: fromSetup
              ? 'The setup names it: the compound the car started this '
                    'recording on.'
              : anchors.isEmpty && counted == null
              ? '$_order Only a list of all four reaches $i, so it is the '
                    '${kind.label}.'
              : '$_order $basis, so $i is the ${kind.label}.',
        );
      } else {
        marks[i] = CompoundMark.unnamed(
          i,
          possible: open,
          reason: open.isEmpty
              ? 'No list in the game\'s order fits it.'
              : '$_order $basis: that leaves it ${_either(open)}.',
        );
      }
    }
    return CompoundKey._(marks, count);
  }

  final Map<int, CompoundMark> _marks;

  /// How many compounds the session offered, from the setup's option range;
  /// null where it does not say, or says differently per corner.
  final int? count;

  /// [index]'s compound, or an unnamed mark for it.
  CompoundMark mark(int index) =>
      _marks[index] ??
      CompoundMark.unnamed(
        index,
        reason: index >= CompoundKind.values.length
            ? 'The game lists at most four compounds, so the file\'s own '
                  'numbering is all there is.'
            : 'Nothing in the file names it.',
      );

  static const _order =
      'The file numbers compounds by their place in the session\'s list, '
      'which the game keeps in the order Soft, Medium, Hard, Wet.';

  /// What pinned the list: "The setup starts the car on Medium at 0 and
  /// offers three compounds".
  static String _basis(Map<int, CompoundKind> anchors, int? count) {
    final started = [
      for (final MapEntry(key: i, value: kind) in anchors.entries)
        '${kind.label} at $i',
    ];
    final offers = count == null
        ? null
        : count == CompoundKind.values.length
        ? 'offers all four'
        : 'offers ${_words[count]} compound${count == 1 ? '' : 's'}';
    return switch ((started.isEmpty, offers)) {
      (false, final o?) =>
        'The setup starts the car on ${started.join(' and ')} and $o',
      (false, null) => 'The setup starts the car on ${started.join(' and ')}',
      (true, final o?) => 'The setup $o',
      (true, null) => 'Nothing else in the file narrows the list down',
    };
  }

  static const _words = ['no', 'one', 'two', 'three', 'four'];

  static String _either(List<CompoundKind> open) => switch (open.length) {
    1 => open.single.label,
    2 => '${open.first.label} or ${open.last.label}',
    _ =>
      '${open.take(open.length - 1).map((k) => k.label).join(', ')} or '
          '${open.last.label}',
  };

  /// Every list the game could offer, in its order: the non-empty ordered
  /// subsets of [CompoundKind.values], of [size] where it is known.
  static Iterable<List<CompoundKind>> _lists(int? size) sync* {
    const all = CompoundKind.values;
    for (var bits = 1; bits < 1 << all.length; bits++) {
      final list = [
        for (var i = 0; i < all.length; i++)
          if (bits & (1 << i) != 0) all[i],
      ];
      if (size == null || list.length == size) yield list;
    }
  }
}

/// [marks] (FL, FR, RL, RR) in as few groups as say them, each with the
/// axle or corner it covers: `[(null, Medium)]` when all four match,
/// `[('F', Soft), ('R', Medium)]` when each axle does, else one per corner.
List<(String?, CompoundMark)> axleGroups(List<CompoundMark> marks) {
  if (marks.isEmpty) return const [];
  if (marks.every((m) => m == marks.first)) return [(null, marks.first)];
  if (marks.length == Corner.values.length &&
      marks[0] == marks[1] &&
      marks[2] == marks[3]) {
    return [('F', marks[0]), ('R', marks[2])];
  }
  return [
    for (final (i, mark) in marks.indexed)
      (i < Corner.values.length ? Corner.values[i].short : null, mark),
  ];
}

/// [marks] in words: "Medium", "F Soft, R Medium".
String describeCompounds(List<CompoundMark> marks) => [
  for (final (axle, mark) in axleGroups(marks))
    axle == null ? mark.label : '$axle ${mark.label}',
].join(', ');
