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

/// The BoP of the results session [source] links to; null without one.

@ProviderFor(sessionBop)
final sessionBopProvider = SessionBopFamily._();

/// The BoP of the results session [source] links to; null without one.

final class SessionBopProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionBop?>,
          SessionBop?,
          FutureOr<SessionBop?>
        >
    with $FutureModifier<SessionBop?>, $FutureProvider<SessionBop?> {
  /// The BoP of the results session [source] links to; null without one.
  SessionBopProvider._({
    required SessionBopFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'sessionBopProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionBopHash();

  @override
  String toString() {
    return r'sessionBopProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SessionBop?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionBop?> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return sessionBop(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionBopProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionBopHash() => r'4af74701981aa579d0afe4ecf0df7b92eab80ea6';

/// The BoP of the results session [source] links to; null without one.

final class SessionBopFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SessionBop?>, TelemetrySource> {
  SessionBopFamily._()
    : super(
        retry: _neverRetry,
        name: r'sessionBopProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The BoP of the results session [source] links to; null without one.

  SessionBopProvider call(TelemetrySource source) =>
      SessionBopProvider._(argument: source, from: this);

  @override
  String toString() => r'sessionBopProvider';
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

/// Null when the recording links to no results file.

@ProviderFor(sessionFieldPace)
final sessionFieldPaceProvider = SessionFieldPaceFamily._();

/// Null when the recording links to no results file.

final class SessionFieldPaceProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionFieldPace?>,
          SessionFieldPace?,
          FutureOr<SessionFieldPace?>
        >
    with
        $FutureModifier<SessionFieldPace?>,
        $FutureProvider<SessionFieldPace?> {
  /// Null when the recording links to no results file.
  SessionFieldPaceProvider._({
    required SessionFieldPaceFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'sessionFieldPaceProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionFieldPaceHash();

  @override
  String toString() {
    return r'sessionFieldPaceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SessionFieldPace?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionFieldPace?> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return sessionFieldPace(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionFieldPaceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionFieldPaceHash() => r'e822ff0624e8642b3cca11eb07be08bdd5aaa797';

/// Null when the recording links to no results file.

final class SessionFieldPaceFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SessionFieldPace?>,
          TelemetrySource
        > {
  SessionFieldPaceFamily._()
    : super(
        retry: _neverRetry,
        name: r'sessionFieldPaceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Null when the recording links to no results file.

  SessionFieldPaceProvider call(TelemetrySource source) =>
      SessionFieldPaceProvider._(argument: source, from: this);

  @override
  String toString() => r'sessionFieldPaceProvider';
}
