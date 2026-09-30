// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lap_incidents.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Incidents for every lap of [source] (§8.3).
///
/// Session-wide and small — three tables, one to three rows each in all three
/// samples — so it is one read shared by the table, the chart and the summary
/// rather than a query per lap.

@ProviderFor(sessionIncidents)
final sessionIncidentsProvider = SessionIncidentsFamily._();

/// Incidents for every lap of [source] (§8.3).
///
/// Session-wide and small — three tables, one to three rows each in all three
/// samples — so it is one read shared by the table, the chart and the summary
/// rather than a query per lap.

final class SessionIncidentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionIncidents>,
          SessionIncidents,
          FutureOr<SessionIncidents>
        >
    with $FutureModifier<SessionIncidents>, $FutureProvider<SessionIncidents> {
  /// Incidents for every lap of [source] (§8.3).
  ///
  /// Session-wide and small — three tables, one to three rows each in all three
  /// samples — so it is one read shared by the table, the chart and the summary
  /// rather than a query per lap.
  SessionIncidentsProvider._({
    required SessionIncidentsFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'sessionIncidentsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionIncidentsHash();

  @override
  String toString() {
    return r'sessionIncidentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SessionIncidents> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionIncidents> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return sessionIncidents(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionIncidentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionIncidentsHash() => r'70660fdfa3a330845a5b81bb953affcfe807afd7';

/// Incidents for every lap of [source] (§8.3).
///
/// Session-wide and small — three tables, one to three rows each in all three
/// samples — so it is one read shared by the table, the chart and the summary
/// rather than a query per lap.

final class SessionIncidentsFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<SessionIncidents>, TelemetrySource> {
  SessionIncidentsFamily._()
    : super(
        retry: _neverRetry,
        name: r'sessionIncidentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Incidents for every lap of [source] (§8.3).
  ///
  /// Session-wide and small — three tables, one to three rows each in all three
  /// samples — so it is one read shared by the table, the chart and the summary
  /// rather than a query per lap.

  SessionIncidentsProvider call(TelemetrySource source) =>
      SessionIncidentsProvider._(argument: source, from: this);

  @override
  String toString() => r'sessionIncidentsProvider';
}
