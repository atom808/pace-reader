/// When a lap's driver aids acted: `TC` and `ABS` as pulses and as the
/// episodes those merge into (SPEC.md §8.13.1; driver-aids proposal §1.2).
library;

import 'dart:typed_data';

/// Pulses closer than this (s) are one episode.
///
/// `TC` and `ABS` switch in 10–20 ms pulses with 2.5–10 ms gaps, 117–908 TC
/// edges a lap, so a pulse is not something a driver did; an episode is
/// (§8.13.1). Driving Technique counts episodes with the same gap.
const aidPulseMergeSeconds = 0.25;

/// Pulses merged at [aidPulseMergeSeconds]: one intervention.
class AidEpisode {
  const AidEpisode(this.startSeconds, this.endSeconds, this.pulseCount);

  final double startSeconds;
  final double endSeconds;
  final int pulseCount;

  double get durationSeconds => endSeconds - startSeconds;

  @override
  bool operator ==(Object other) =>
      other is AidEpisode &&
      other.startSeconds == startSeconds &&
      other.endSeconds == endSeconds &&
      other.pulseCount == pulseCount;

  @override
  int get hashCode => Object.hash(startSeconds, endSeconds, pulseCount);

  @override
  String toString() => 'AidEpisode($startSeconds–$endSeconds, $pulseCount)';
}

/// One aid over one window: every pulse, and the episodes they merge into.
class AidPulses {
  const AidPulses._({
    required this.name,
    required this.startSeconds,
    required this.endSeconds,
    required this.starts,
    required this.ends,
    required this.episodes,
    required this.episodeCount,
  });

  /// The aid's pulses over `[start, end]`, from its edges: `(seconds, on)` in
  /// time order, an event's rows or a channel's value changes.
  ///
  /// [edges] should reach past the window on both sides by more than
  /// [mergeGap]; [readMargin] is the margin readers use. An episode then
  /// merges from the pulses either side of the line the way the whole
  /// session's would, and one that began before [start] is drawn but not
  /// counted.
  ///
  /// The rule is `aidEpisodesSql`'s, so the counts agree with Driving
  /// Technique's:
  /// - an on edge holds until the next edge, whatever it is; the last on edge
  ///   holds 10 ms, one tick;
  /// - a pulse starting more than [mergeGap] after every earlier one has
  ///   ended starts an episode;
  /// - an episode belongs to the window its first pulse starts in.
  factory AidPulses.fromEdges(
    String name,
    List<(double, bool)> edges, {
    required double start,
    required double end,
    double mergeGap = aidPulseMergeSeconds,
  }) {
    final pulseStarts = <double>[];
    final pulseEnds = <double>[];
    final episodes = <AidEpisode>[];
    var counted = 0;

    double? episodeStart;
    var reach = double.negativeInfinity;
    var pulses = 0;
    void close() {
      final from = episodeStart;
      if (from == null) return;
      // Kept when any of it shows in the window; counted only when it began
      // there.
      if (reach > start && from < end) {
        episodes.add(
          AidEpisode(
            from < start ? start : from,
            reach > end ? end : reach,
            pulses,
          ),
        );
      }
      if (from >= start && from < end) counted++;
    }

    for (var i = 0; i < edges.length; i++) {
      final (a, on) = edges[i];
      if (!on) continue;
      final b = i + 1 < edges.length ? edges[i + 1].$1 : a + 0.01;
      if (episodeStart == null || a - reach > mergeGap) {
        close();
        episodeStart = a;
        pulses = 0;
      }
      pulses++;
      if (b > reach) reach = b;
      if (b > start && a < end) {
        pulseStarts.add(a < start ? start : a);
        pulseEnds.add(b > end ? end : b);
      }
    }
    close();

    return AidPulses._(
      name: name,
      startSeconds: start,
      endSeconds: end,
      starts: Float64List.fromList(pulseStarts),
      ends: Float64List.fromList(pulseEnds),
      episodes: episodes,
      episodeCount: counted,
    );
  }

  /// How far past each side of a window readers fetch edges: more than the
  /// merge gap, so an episode across the line merges as it would in the
  /// whole session.
  static const readMargin = 1.0;

  /// `TC` or `ABS`.
  final String name;

  /// The window, in the recording's seconds.
  final double startSeconds;
  final double endSeconds;

  /// Each pulse's start and end, clipped to the window, in order.
  final Float64List starts;
  final Float64List ends;

  /// Every episode that shows in the window, clipped to it, in order.
  final List<AidEpisode> episodes;

  /// The episodes that began in the window: Driving Technique's per-lap
  /// count, which leaves an episode across the line to the lap it began in.
  final int episodeCount;

  int get pulseCount => starts.length;

  bool get isEmpty => starts.isEmpty;

  /// Seconds with the aid on, inside the window.
  double get activeSeconds {
    var total = 0.0;
    for (var i = 0; i < starts.length; i++) {
      total += ends[i] - starts[i];
    }
    return total;
  }

  /// The episode under [seconds], or null between them.
  AidEpisode? episodeAt(double seconds) {
    var lo = 0;
    var hi = episodes.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final e = episodes[mid];
      if (seconds < e.startSeconds) {
        hi = mid - 1;
      } else if (seconds > e.endSeconds) {
        lo = mid + 1;
      } else {
        return e;
      }
    }
    return null;
  }
}

/// One lap's driver aids. A null aid is one the file does not record; an
/// empty one was recorded and never acted, which on `ABS` is also how a car
/// without it reads (a Hypercar's single `false` row, §8.13.1).
class LapAids {
  const LapAids({this.tc, this.abs});

  static const none = LapAids();

  final AidPulses? tc;
  final AidPulses? abs;
}
