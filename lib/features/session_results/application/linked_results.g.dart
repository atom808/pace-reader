// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linked_results.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The results session [source] was recorded in, read whole from the index,
/// or null when no file links (or no results folder was ever added).

@ProviderFor(linkedResults)
final linkedResultsProvider = LinkedResultsFamily._();

/// The results session [source] was recorded in, read whole from the index,
/// or null when no file links (or no results folder was ever added).

final class LinkedResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<LinkedResults?>,
          LinkedResults?,
          FutureOr<LinkedResults?>
        >
    with $FutureModifier<LinkedResults?>, $FutureProvider<LinkedResults?> {
  /// The results session [source] was recorded in, read whole from the index,
  /// or null when no file links (or no results folder was ever added).
  LinkedResultsProvider._({
    required LinkedResultsFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'linkedResultsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$linkedResultsHash();

  @override
  String toString() {
    return r'linkedResultsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<LinkedResults?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LinkedResults?> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return linkedResults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LinkedResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$linkedResultsHash() => r'490a38bbfa618eb869f262164833ac1ce6d658db';

/// The results session [source] was recorded in, read whole from the index,
/// or null when no file links (or no results folder was ever added).

final class LinkedResultsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<LinkedResults?>, TelemetrySource> {
  LinkedResultsFamily._()
    : super(
        retry: _neverRetry,
        name: r'linkedResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The results session [source] was recorded in, read whole from the index,
  /// or null when no file links (or no results folder was ever added).

  LinkedResultsProvider call(TelemetrySource source) =>
      LinkedResultsProvider._(argument: source, from: this);

  @override
  String toString() => r'linkedResultsProvider';
}

/// Null when the recording links to no results file.

@ProviderFor(sessionRaceControl)
final sessionRaceControlProvider = SessionRaceControlFamily._();

/// Null when the recording links to no results file.

final class SessionRaceControlProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionRaceControl?>,
          SessionRaceControl?,
          FutureOr<SessionRaceControl?>
        >
    with
        $FutureModifier<SessionRaceControl?>,
        $FutureProvider<SessionRaceControl?> {
  /// Null when the recording links to no results file.
  SessionRaceControlProvider._({
    required SessionRaceControlFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'sessionRaceControlProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionRaceControlHash();

  @override
  String toString() {
    return r'sessionRaceControlProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SessionRaceControl?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionRaceControl?> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return sessionRaceControl(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionRaceControlProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionRaceControlHash() =>
    r'99d0870da49345c5e35f288ea55e60e0700089c7';

/// Null when the recording links to no results file.

final class SessionRaceControlFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SessionRaceControl?>,
          TelemetrySource
        > {
  SessionRaceControlFamily._()
    : super(
        retry: _neverRetry,
        name: r'sessionRaceControlProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Null when the recording links to no results file.

  SessionRaceControlProvider call(TelemetrySource source) =>
      SessionRaceControlProvider._(argument: source, from: this);

  @override
  String toString() => r'sessionRaceControlProvider';
}
