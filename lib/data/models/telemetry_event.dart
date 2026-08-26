/// One recorded change from an event table (SPEC.md §5.1, §8.12).
library;

/// A single row of one event table, with the table it came from.
///
/// [values] holds the row's native Dart types rather than coercing to double,
/// which is the opposite of [StepSeries]'s choice and for the opposite reason.
/// A step plot needs numbers to draw; §8.12's log is a window onto what the
/// game actually wrote, and `false` is not `0.0` to someone reading it to find
/// out whether ABS engaged. `dart_duckdb` already hands back `bool` for
/// BOOLEAN, `int` for the six integer widths in use, and `double` for FLOAT —
/// measured on all three samples — so preserving them costs nothing.
class TelemetryEvent {
  const TelemetryEvent({
    required this.name,
    required this.unit,
    required this.timeSeconds,
    required this.values,
  });

  /// The event table's name — `Gear`, `ABS`, `SurfaceTypes`.
  final String name;

  /// From `eventsList`, and often empty: most of these are unitless states.
  final String unit;

  /// Elapsed seconds on the session clock (§5.2), as written in the file.
  final double timeSeconds;

  /// One value, or four for the three per-corner event tables measured in
  /// every sample (`SurfaceTypes`, `TyresCompound`, `WheelsDetached`). Kept as
  /// one row rather than exploded into four, because a per-corner reading is
  /// one thing that happened, and four rows sharing a timestamp would triple
  /// the log's length while making it harder to read.
  final List<Object?> values;

  bool get isPerCorner => values.length == 4;
}

/// The result of a log read, including whether it is the whole answer.
///
/// [clipped] exists because §9.5's "no silent caps" rule applies to tables as
/// much as to charts: a view showing the first 10,000 of 200,000 changes
/// without saying so has told the reader something false about the session.
/// It names the events rather than raising a flag, because *which* signal got
/// clipped is the actionable half — "SurfaceTypes was clipped" and "Gear was
/// clipped" mean very different things about what you are looking at.
class EventLog {
  const EventLog({required this.events, this.clipped = const []});

  static const empty = EventLog(events: []);

  /// Sorted by time, then by name so a tie is stable rather than dependent on
  /// the order the tables happened to be read in.
  final List<TelemetryEvent> events;

  /// Events whose read hit the per-event row cap, so more changes exist than
  /// are held here.
  final List<String> clipped;

  bool get truncated => clipped.isNotEmpty;

  bool get isEmpty => events.isEmpty;

  /// The distinct event names present, in catalog order.
  List<String> get names {
    final seen = <String>{};
    return [
      for (final e in events)
        if (seen.add(e.name)) e.name,
    ];
  }
}
