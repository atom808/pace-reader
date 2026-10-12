/// Which recording a session is, wherever its file sits (comparison proposal
/// §9, "Identity").
///
/// A path names a file, not a recording: a copy, a file moved to another
/// folder, or a trimmed test fixture holds the same recording under a
/// different path. Anything that counts recordings — a personal best's "fastest
/// of N", refusing to compare a lap with itself — has to see through that.
///
/// The file carries no identifier for it. `SteamID` is `"0"` in every
/// recording the library has seen, so identity is built from what LMU writes
/// per recording: the `RecordingTime` stamp (the same one in the filename),
/// plus who drove which car, which separates two recordings started in the
/// same second on different machines.
class RecordingIdentity {
  const RecordingIdentity({
    required this.recordingTime,
    required this.driverName,
    required this.carName,
  });

  /// `metadata.RecordingTime` verbatim, e.g. `2026-07-07T06_42_17Z`.
  final String recordingTime;
  final String driverName;
  final String carName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordingIdentity &&
          other.recordingTime == recordingTime &&
          other.driverName == driverName &&
          other.carName == carName);

  @override
  int get hashCode =>
      Object.hash(RecordingIdentity, recordingTime, driverName, carName);

  @override
  String toString() =>
      'RecordingIdentity($recordingTime, $driverName, $carName)';
}
