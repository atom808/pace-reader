/// How the stage colours its line (map stage proposal §3.3, D7).
///
/// Two colourings behind [LineColouring]: [PedalColouring], the default —
/// the line says what the driver's feet were doing — and [RampColouring],
/// one channel's magnitude on its own hue (§8.5's original map). Both
/// precompute a colour per segment and quantise it, so the line painter can
/// batch the lap into a dozen paths instead of a thousand strokes.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../decimation.dart';
import '../track_path.dart';
import '../value_ramp.dart';
import 'stage_contracts.dart';

/// The fraction of travel below which a pedal counts as released: a resting
/// foot reads a few percent on most cars.
const pedalThreshold = 0.05;

/// One channel's magnitude along the line, in [ValueRamp]'s single hue,
/// quantised to [buckets] steps.
class RampColouring implements LineColouring {
  RampColouring(
    this.path,
    this.ramp, {
    required this.fallback,
    int buckets = 12,
  }) : label = path.valueUnit.isEmpty
           ? path.valueLabel
           : '${path.valueLabel} (${path.valueUnit})',
       _colours = _colour(path, ramp, fallback, buckets);

  final TrackPath path;
  final ValueRamp ramp;

  /// The line's colour when [path] carries no values.
  final Color fallback;

  @override
  final String label;

  final List<Color> _colours;

  @override
  Color colourAt(int segment) => _colours[segment];

  @override
  bool operator ==(Object other) =>
      other is RampColouring &&
      identical(other.path, path) &&
      other.ramp == ramp &&
      other.fallback == fallback &&
      other._colours.length == _colours.length;

  @override
  int get hashCode => Object.hash(identityHashCode(path), ramp, fallback);

  static List<Color> _colour(
    TrackPath path,
    ValueRamp ramp,
    Color fallback,
    int buckets,
  ) {
    final n = math.max(path.length - 1, 0);
    if (!path.hasColouring) return List.filled(n, fallback);
    final steps = [
      for (var b = 0; b < buckets; b++) ramp.at(b / (buckets - 1)),
    ];
    final range = path.valueRange;
    return [
      for (var i = 0; i < n; i++)
        steps[_bucket(
          range.span == 0
              ? 0.5
              : ((path.values[i] + path.values[i + 1]) / 2 - range.min) /
                    range.span,
          buckets,
        )],
    ];
  }

  static int _bucket(double t, int buckets) =>
      ((t.isNaN ? 0 : t.clamp(0.0, 1.0)) * (buckets - 1)).round();
}

/// Throttle and brake travel at each of a path's points, as fractions.
class PedalSamples {
  PedalSamples({required this.throttle, required this.brake})
    : assert(throttle.length == brake.length);

  /// Reads [throttle] and [brake] at each point of [path]. Either may be
  /// missing, and reads as released throughout.
  factory PedalSamples.sample(
    TrackPath path, {
    TracePlot? throttle,
    TracePlot? brake,
  }) => PedalSamples(
    throttle: _sample(path, throttle),
    brake: _sample(path, brake),
  );

  final Float64List throttle;
  final Float64List brake;

  int get length => throttle.length;

  static Float64List _sample(TrackPath path, TracePlot? plot) {
    final out = Float64List(path.length);
    if (plot == null || plot.isEmpty) return out;
    // Percent in LMU's files; a fraction in some. Anything that reaches
    // past 1.5 is a percentage.
    final scale = plot.valueRange.max > 1.5 ? 0.01 : 1.0;
    for (var i = 0; i < path.length; i++) {
      out[i] = ((plot.valueAt(path.xs[i]) ?? 0) * scale).clamp(0.0, 1.0);
    }
    return out;
  }
}

/// The three states a stretch of the lap can be in.
class PedalColours {
  const PedalColours({
    required this.throttle,
    required this.brake,
    required this.coast,
  });

  final Color throttle;
  final Color brake;
  final Color coast;

  @override
  bool operator ==(Object other) =>
      other is PedalColours &&
      other.throttle == throttle &&
      other.brake == brake &&
      other.coast == coast;

  @override
  int get hashCode => Object.hash(throttle, brake, coast);
}

/// What the driver's feet were doing along the line (D7): brake, throttle or
/// neither, deeper the further the pedal went.
///
/// Brake wins where both are pressed — a trail of throttle under braking is
/// a stability aid, and the brake is what the stretch is for. Depth is in
/// four steps, so half throttle and full throttle read apart without
/// turning the line into a gradient no one can read a number from.
class PedalColouring implements LineColouring {
  PedalColouring(this.samples, this.colours)
    : _colours = _colour(samples, colours);

  final PedalSamples samples;
  final PedalColours colours;

  @override
  String get label => 'Inputs';

  final List<Color> _colours;

  @override
  Color colourAt(int segment) => _colours[segment];

  @override
  bool operator ==(Object other) =>
      other is PedalColouring &&
      identical(other.samples, samples) &&
      other.colours == colours;

  @override
  int get hashCode => Object.hash(identityHashCode(samples), colours);

  /// The opacity for a pedal at [amount]: four steps from 0.4 to 1.
  static double depth(double amount) {
    final step = (amount.clamp(0.0, 1.0) * 4).ceil().clamp(1, 4);
    return 0.4 + 0.6 * (step - 1) / 3;
  }

  static List<Color> _colour(PedalSamples samples, PedalColours colours) {
    final n = math.max(samples.length - 1, 0);
    return [
      for (var i = 0; i < n; i++)
        _at(
          (samples.throttle[i] + samples.throttle[i + 1]) / 2,
          (samples.brake[i] + samples.brake[i + 1]) / 2,
          colours,
        ),
    ];
  }

  static Color _at(double throttle, double brake, PedalColours colours) {
    if (brake >= pedalThreshold) {
      return colours.brake.withValues(alpha: depth(brake));
    }
    if (throttle >= pedalThreshold) {
      return colours.throttle.withValues(alpha: depth(throttle));
    }
    return colours.coast;
  }
}

/// One colour along the whole line: a map whose line is only the road, with
/// the meaning in the layers over it (Suspension's sites, Technique's
/// segment bands).
class SolidColouring implements LineColouring {
  const SolidColouring(this.colour, {this.label = ''});

  final Color colour;

  @override
  final String label;

  @override
  Color colourAt(int segment) => colour;

  @override
  bool operator ==(Object other) =>
      other is SolidColouring && other.colour == colour && other.label == label;

  @override
  int get hashCode => Object.hash(colour, label);
}
