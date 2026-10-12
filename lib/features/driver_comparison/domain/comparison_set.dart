/// The pair of laps Compare is looking at (comparison proposal §4, §9).
library;

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/lap_ref.dart';

/// Which lap is being explained, and which lap it is explained against.
///
/// Exactly one Target (decision D4): comparing against something else means
/// changing the Target, not adding a slot. A value class with deep equality,
/// because it is the chart provider's family key — two sets naming the same
/// laps must be one chart, whichever spelling of a path they arrived with.
class ComparisonSet {
  const ComparisonSet(this.base, [this.target]);

  /// The lap being explained: the delta's zero, drawn solid.
  final LapRef base;

  /// The lap Base is compared against, drawn dotted; null until one is
  /// chosen.
  final LapRef? target;

  /// The same Base against [target] — or against nothing, for null. A Target
  /// that is Base itself is no comparison and is dropped (§4: "No lap
  /// against itself").
  ComparisonSet withTarget(LapRef? target) =>
      ComparisonSet(base, target == base ? null : target);

  /// Base and Target exchanged; every sign flips. Only a set with a Target
  /// can swap.
  ComparisonSet swapped() => ComparisonSet(target!, base);

  /// Whether [source] holds either lap.
  bool uses(TelemetrySource source) =>
      base.source == source || target?.source == source;

  @override
  bool operator ==(Object other) =>
      other is ComparisonSet && other.base == base && other.target == target;

  @override
  int get hashCode => Object.hash(base, target);

  @override
  String toString() => 'ComparisonSet($base vs $target)';
}

/// Which side of a comparison a lap is on.
enum ComparisonRole {
  base('Base'),
  target('Target');

  const ComparisonRole(this.label);

  final String label;
}
