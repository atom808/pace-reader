// Tyre compounds: the setup's words, and the TyresCompound event's indices
// named through the game's order (SPEC.md §15.20). The cases are the
// library's own, from the 444-recording survey of 2026-10-14.
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/corner.dart';
import 'package:pace_reader/data/reference/tyre_compound.dart';

/// A key for a car whose four corners say the same.
CompoundKey _key(String name, {int? max, required int start}) =>
    CompoundKey.resolve(
      names: {for (final c in Corner.values) c: name},
      options: {
        if (max != null)
          for (final c in Corner.values) c: max,
      },
      start: {for (final c in Corner.values) c: start},
    );

void main() {
  group('the setup\'s words', () {
    test('a new set, a used one, and nothing', () {
      expect(CompoundMark.ofSetup('Medium')!.kind, CompoundKind.medium);
      expect(CompoundMark.ofSetup('Medium')!.treadLeft, isNull);
      final used = CompoundMark.ofSetup('70% Medium')!;
      expect(used.kind, CompoundKind.medium);
      expect(used.treadLeft, 70);
      expect(CompoundMark.ofSetup('100% Soft')!.treadLeft, 100);
      expect(CompoundMark.ofSetup(' wet ')!.kind, CompoundKind.wet);
      expect(CompoundMark.ofSetup(''), isNull);
      expect(CompoundMark.ofSetup(null), isNull);
    });

    test('a compound the game has not used before keeps its word', () {
      final inter = CompoundMark.ofSetup('Intermediate')!;
      expect(inter.kind, isNull);
      expect(inter.label, 'Intermediate');
      expect(inter.isNamed, isTrue);
    });
  });

  group('naming the event\'s indices', () {
    test(
      'Interlagos BMW: Medium at 0 of three, so its change to 2 is Wets',
      () {
        final key = _key('70% Medium', max: 6, start: 0);
        expect(key.count, 3);
        expect(key.mark(0).kind, CompoundKind.medium);
        expect(key.mark(0).naming, CompoundNaming.setup);
        expect(key.mark(1).kind, CompoundKind.hard);
        expect(key.mark(2).kind, CompoundKind.wet);
        expect(key.mark(2).naming, CompoundNaming.gameOrder);
        expect(key.mark(2).reason, contains('Medium at 0'));
        expect(key.mark(2).reason, contains('three compounds'));
      },
    );

    test('Daytona Toyota: Soft at 0 of four, so the wet races\' 3 is Wets', () {
      final key = _key('Soft', max: 8, start: 0);
      expect(
        [for (var i = 0; i < 4; i++) key.mark(i).kind],
        [
          CompoundKind.soft,
          CompoundKind.medium,
          CompoundKind.hard,
          CompoundKind.wet,
        ],
      );
    });

    test('Spa VLMDH: Medium at 1, so its change to 0 is Softs', () {
      final key = _key('Medium', max: 8, start: 1);
      expect(key.mark(0).kind, CompoundKind.soft);
      expect(key.mark(1).naming, CompoundNaming.setup);
    });

    test('a GT3 offers two: its second index stays a number', () {
      final key = _key('Medium', max: 4, start: 0);
      expect(key.mark(0).kind, CompoundKind.medium);
      final second = key.mark(1);
      expect(second.isNamed, isFalse);
      expect(second.naming, CompoundNaming.unnamed);
      expect(second.label, 'compound 1');
      expect(second.possible, [CompoundKind.hard, CompoundKind.wet]);
      expect(second.reason, contains('Hard or Wet'));
    });

    test('the Cadillac weekend: a count that does not fit the names is '
        'dropped, and only the setup\'s own index is named', () {
      // Four compounds, yet Medium at 0: no list in the game's order has
      // both, so the names win.
      final key = _key('Medium', max: 8, start: 0);
      expect(key.mark(0).kind, CompoundKind.medium);
      expect(key.mark(1).isNamed, isFalse);
      expect(key.mark(3).isNamed, isFalse);
    });

    test('Daytona in a storm: a Soft cannot be index 3, so the setup is older '
        'than the tyres and the count names them', () {
      final key = _key('Soft', max: 8, start: 3);
      expect(key.mark(3).kind, CompoundKind.wet);
      expect(key.mark(3).naming, CompoundNaming.gameOrder);
    });

    test('front and rear on different compounds both name their index', () {
      final key = CompoundKey.resolve(
        names: {
          Corner.frontLeft: 'Medium',
          Corner.frontRight: 'Medium',
          Corner.rearLeft: 'Hard',
          Corner.rearRight: 'Hard',
        },
        options: {for (final c in Corner.values) c: 6},
        start: {
          Corner.frontLeft: 0,
          Corner.frontRight: 0,
          Corner.rearLeft: 1,
          Corner.rearRight: 1,
        },
      );
      expect(key.mark(0).kind, CompoundKind.medium);
      expect(key.mark(1).kind, CompoundKind.hard);
      expect(key.mark(1).naming, CompoundNaming.setup);
    });

    test(
      'corners that contradict each other name nothing they disagree on',
      () {
        // An Interlagos practice: the setup puts FL on Medium and the rest on
        // Hard, the event all four on 0.
        final key = CompoundKey.resolve(
          names: {
            Corner.frontLeft: 'Medium',
            Corner.frontRight: 'Hard',
            Corner.rearLeft: 'Hard',
            Corner.rearRight: 'Hard',
          },
          options: {for (final c in Corner.values) c: 6},
          start: {for (final c in Corner.values) c: 0},
        );
        expect(key.mark(0).isNamed, isFalse);
      },
    );

    test('with no names, four compounds still name every index', () {
      final key = _key('', max: 8, start: 1);
      expect(key.mark(1).kind, CompoundKind.medium);
      expect(key.mark(1).naming, CompoundNaming.gameOrder);
      expect(key.mark(1).reason, contains('offers all four'));
      // Three do not.
      expect(_key('', max: 6, start: 0).mark(0).isNamed, isFalse);
    });

    test('nothing at all: only index 3 is fixed, by the order alone', () {
      expect(CompoundKey.none.mark(0).isNamed, isFalse);
      final key = CompoundKey.resolve(names: const {}, start: const {});
      expect(key.mark(3).kind, CompoundKind.wet);
      expect(key.mark(3).reason, contains('Only a list of all four'));
      expect(key.mark(1).isNamed, isFalse);
    });

    test('an index past any list is a number with a reason', () {
      final key = _key('Soft', max: 8, start: 0);
      expect(key.mark(6).isNamed, isFalse);
      expect(key.mark(6).reason, isNotEmpty);
    });

    test('an odd or out-of-range option count is no count', () {
      expect(_key('Medium', max: 5, start: 0).count, isNull);
      expect(_key('Medium', max: 12, start: 0).count, isNull);
      final mixed = CompoundKey.resolve(
        names: {for (final c in Corner.values) c: 'Medium'},
        options: {Corner.frontLeft: 6, Corner.rearLeft: 8},
        start: {for (final c in Corner.values) c: 0},
      );
      expect(mixed.count, isNull);
    });
  });

  group('four corners in few words', () {
    const soft = CompoundMark(kind: CompoundKind.soft);
    const medium = CompoundMark(kind: CompoundKind.medium);

    test('one, an axle each, or a corner each', () {
      expect(axleGroups([soft, soft, soft, soft]), [(null, soft)]);
      expect(axleGroups([soft, soft, medium, medium]), [
        ('F', soft),
        ('R', medium),
      ]);
      expect(axleGroups([medium, soft, soft, soft]).map((g) => g.$1), [
        'FL',
        'FR',
        'RL',
        'RR',
      ]);
      expect(axleGroups(const []), isEmpty);
    });

    test('in words', () {
      expect(describeCompounds([soft, soft, soft, soft]), 'Soft');
      expect(
        describeCompounds([soft, soft, medium, medium]),
        'F Soft, R Medium',
      );
      expect(
        describeCompounds(const [
          CompoundMark.unnamed(2),
          CompoundMark.unnamed(2),
          CompoundMark.unnamed(2),
          CompoundMark.unnamed(2),
        ]),
        'compound 2',
      );
    });
  });
}
