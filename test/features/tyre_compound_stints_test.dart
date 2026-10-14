// The compounds a recording ran, from the setup and the TyresCompound event
// (SPEC.md §15.20): what the Tires & brakes card and the Setup Viewer show.
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/reference/tyre_compound.dart';
import 'package:pace_reader/features/setup_viewer/application/car_setup.dart';
import 'package:pace_reader/features/setup_viewer/application/key_figures.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_report.dart';
import 'package:pace_reader/features/tires_brakes/application/tyre_setup.dart';

/// A setup whose wheels say [wheel] with [max] options (the rears [rear],
/// any corner in [corners] its own), and whose axle compounds say [axle].
String _setup({
  required String wheel,
  required int max,
  String axle = 'Soft',
  String rear = '',
  Map<Corner, String> corners = const {},
}) {
  String entry(String key, String value, int maxValue) =>
      '"$key":{"available":true,"isFreeSetting":true,"key":"$key",'
      '"stringValue":"$value","lastSavedStringValue":"$value",'
      '"value":1,"minValue":0,"maxValue":$maxValue,"numChangesValue":0}';
  return '{${[for (final c in Corner.values) entry('WM_COMPOUND-W_${c.short}', corners[c] ?? (!c.isFront && rear.isNotEmpty ? rear : wheel), max), entry('VM_FRONT_TIRE_COMPOUND', axle, 1), entry('VM_REAR_TIRE_COMPOUND', axle, 1)].join(',')}}';
}

StepSeries _series(List<(double, double)> rows) =>
    StepSeries.fromRows(rows, eventName: 'TyresCompound');

List<Lap> _laps(int n) => [
  for (var i = 0; i < n; i++)
    Lap(
      index: i,
      startSeconds: i * 100.0,
      endSeconds: (i + 1) * 100.0,
      sectors: const SectorTimes(),
    ),
];

void main() {
  group('the setup', () {
    test('reads each wheel\'s compound and how many the session offers', () {
      final setup = TyreSetup.fromJson(_setup(wheel: '70% Medium', max: 6));
      expect(setup.compoundOptions[Corner.frontLeft], 6);
      final mark = setup.compoundMarks[Corner.rearRight]!;
      expect(mark.kind, CompoundKind.medium);
      expect(mark.treadLeft, 70);
      final key = setup.compoundKey({for (final c in Corner.values) c: 0});
      expect(key.mark(2).kind, CompoundKind.wet);
    });
  });

  group('the stints', () {
    test('a change to Wets at Interlagos is named, with its lap', () {
      final setup = TyreSetup.fromJson(_setup(wheel: '70% Medium', max: 6));
      final stints = compoundStints(setup, {
        for (final c in Corner.values) c: _series([(0, 0), (350, 2)]),
      }, _laps(6));
      expect(stints, hasLength(2));
      expect(stints.first.lap, isNull);
      expect(stints.first.marks.first.kind, CompoundKind.medium);
      expect(stints.last.lap!.displayNumber, 4);
      expect(
        stints.last.marks.every((m) => m.kind == CompoundKind.wet),
        isTrue,
      );
    });

    test('a change on one axle is a stint of its own; a repeat is not', () {
      // The event writes all four corners in one row, so a change the
      // corners share lands at one time.
      final setup = TyreSetup.fromJson(_setup(wheel: 'Soft', max: 8));
      final stints = compoundStints(setup, {
        Corner.frontLeft: _series([(0, 0), (350, 1), (420, 1)]),
        Corner.frontRight: _series([(0, 0), (350, 1), (420, 1)]),
        Corner.rearLeft: _series([(0, 0), (420, 0)]),
        Corner.rearRight: _series([(0, 0), (420, 0)]),
      }, _laps(6));
      expect(stints, hasLength(2));
      expect(stints.last.marks.map((m) => m.kind), [
        CompoundKind.medium,
        CompoundKind.medium,
        CompoundKind.soft,
        CompoundKind.soft,
      ]);
    });

    test('no stints without the event on all four corners', () {
      final setup = TyreSetup.fromJson(_setup(wheel: 'Soft', max: 8));
      expect(
        compoundStints(setup, {
          Corner.frontLeft: _series([(0, 0)]),
        }, _laps(2)),
        isEmpty,
      );
    });
  });

  group('the Setup Viewer\'s tile', () {
    test('names the compound fitted, not the axle\'s first-on-offer', () {
      // 203 of 440 recordings: the axle says Soft, the wheels Medium.
      final setup = CarSetup.parse(_setup(wheel: 'Medium', max: 8));
      final tile = keyFigures(setup)
          .firstWhere((f) => f.label == 'Tyre compound');
      expect(tile.value, 'Medium');
      expect(tile.caption, 'front and rear');
      expect(tile.compounds.single.kind, CompoundKind.medium);
    });

    test('front and rear apart: all four wheels, for the dots', () {
      final setup = CarSetup.parse(
        _setup(wheel: 'Medium', rear: 'Hard', max: 6, axle: 'Medium'),
      );
      final tile = keyFigures(setup)
          .firstWhere((f) => f.label == 'Tyre compound');
      expect(tile.value, 'Medium / Hard');
      expect(tile.caption, 'front / rear');
      expect(tile.compounds.map((m) => m.kind), [
        CompoundKind.medium,
        CompoundKind.medium,
        CompoundKind.hard,
        CompoundKind.hard,
      ]);
    });

    test('left and right apart, as the game\'s presets split them', () {
      final setup = CarSetup.parse(
        _setup(
          wheel: 'Medium',
          max: 8,
          corners: const {Corner.frontRight: 'Soft', Corner.rearRight: 'Soft'},
        ),
      );
      final tile = keyFigures(setup)
          .firstWhere((f) => f.label == 'Tyre compound');
      expect(tile.value, 'Medium / Soft');
      expect(tile.caption, 'left / right');
      expect(tile.compounds, hasLength(4));
    });

    test('one wheel apart: mixed, spelled out wheel by wheel', () {
      final setup = CarSetup.parse(
        _setup(
          wheel: 'Medium',
          max: 8,
          corners: const {Corner.frontLeft: 'Soft'},
        ),
      );
      final tile = keyFigures(setup)
          .firstWhere((f) => f.label == 'Tyre compound');
      expect(tile.value, 'Mixed');
      expect(tile.caption, 'FL Soft, FR Medium, RL Medium, RR Medium');
      expect(tile.compounds, hasLength(4));
    });

    test('a used set: the name in the figure, the tread in the caption', () {
      // The Interlagos BMW: 70% Medium on the front, 55% on the rear.
      final setup = CarSetup.parse(
        _setup(wheel: '70% Medium', rear: '55% Medium', max: 6),
      );
      final tile = keyFigures(setup)
          .firstWhere((f) => f.label == 'Tyre compound');
      expect(tile.value, 'Medium');
      expect(tile.caption, 'front and rear · used, 70 / 55 % tread');
      expect(tile.compounds, hasLength(1));
    });

    test('the axle compounds say what they are', () {
      final setup = CarSetup.parse(_setup(wheel: 'Medium', max: 8));
      expect(
        setup.byKey('VM_FRONT_TIRE_COMPOUND')!.caption,
        startsWith('Not the compound fitted'),
      );
      expect(setup.byKey('WM_COMPOUND-W_FL')!.caption, isNull);
    });
  });
}
