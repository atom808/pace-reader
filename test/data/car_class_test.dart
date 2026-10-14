// CarClass: the file's `CarClass` code read into the class it names
// (docs/ICONOGRAPHY-PLAN-2026-10-14.md §4).
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/reference/car_class.dart';

void main() {
  group('the codes in the recordings', () {
    // Every value the user's 709 recordings hold (2026-10-14): Hyper 583,
    // GT3 98, LMP2_ELMS 26, LMP3 2.
    test('read as the class LMU names', () {
      expect(
        [
          for (final raw in ['Hyper', 'GT3', 'LMP2_ELMS', 'LMP3'])
            (CarClass.parse(raw).name, CarClass.parse(raw).shortCode),
        ],
        [('Hypercar', 'HY'), ('LMGT3', 'GT3'), ('LMP2', 'P2'), ('LMP3', 'P3')],
      );
    });

    test('ELMS LMP2 is LMP2, marked, and told apart in text', () {
      final elms = CarClass.parse('LMP2_ELMS');
      final wec = CarClass.parse('LMP2');
      expect(elms.kind, CarClassKind.lmp2);
      expect(elms.elms, isTrue);
      expect(wec.elms, isFalse);
      expect(elms.name, wec.name);
      expect(elms.label, 'LMP2 ELMS');
      expect(wec.label, 'LMP2');
      expect(elms, isNot(wec));
    });

    test('the raw string is kept as written', () {
      expect(CarClass.parse('LMP2_ELMS').raw, 'LMP2_ELMS');
    });
  });

  test('other spellings of a known class read the same', () {
    for (final (raw, kind) in [
      ('hyper', CarClassKind.hypercar),
      ('Hypercar', CarClassKind.hypercar),
      ('LMGT3', CarClassKind.lmgt3),
      ('lm gt3', CarClassKind.lmgt3),
      ('GTE', CarClassKind.lmgte),
      ('LMGTE', CarClassKind.lmgte),
      ('LMP2 ELMS', CarClassKind.lmp2),
    ]) {
      expect(CarClass.parse(raw).kind, kind, reason: raw);
    }
  });

  test('an unknown class keeps its own name rather than losing it', () {
    final cls = CarClass.parse('GT3 Pro');
    expect(cls.kind, CarClassKind.unknown);
    expect(cls.name, 'GT3 Pro');
    expect(cls.shortCode, 'GT3 Pro');
    expect(cls.label, 'GT3 Pro');
    expect(CarClass.parse('  ').name, 'Unknown class');
    expect(CarClass.parse('X'), isNot(CarClass.parse('Y')));
  });

  test('running order: fastest first, ELMS LMP2 ahead of the WEC one', () {
    final sorted = ['GT3', 'LMP3', 'Zed', 'Hyper', 'LMP2', 'GTE', 'LMP2_ELMS']
      ..sort(
        (a, b) => CarClass.parse(a).order.compareTo(CarClass.parse(b).order),
      );
    expect(sorted, ['Hyper', 'LMP2_ELMS', 'LMP2', 'LMP3', 'GTE', 'GT3', 'Zed']);
  });
}
