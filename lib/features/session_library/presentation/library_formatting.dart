/// Dates, sizes and counts as the Session Library shows them.
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `7 Jul 2026`, in UTC.
///
/// UTC rather than local time, because it is the recording's own clock:
/// `RecordingTime` ends in `Z`, and it is also the stamp in the filename
/// (§5), so the row matches what the user sees in their telemetry folder.
/// Converting would make the library disagree with the filename by the
/// user's offset — and a golden rendered in one time zone would fail in
/// another.
String formatRecordedDate(DateTime at) {
  final utc = at.toUtc();
  return '${utc.day} ${_months[utc.month - 1]} ${utc.year}';
}

/// `06:42 UTC` — see [formatRecordedDate].
String formatRecordedTime(DateTime at) {
  final utc = at.toUtc();
  return '${_two(utc.hour)}:${_two(utc.minute)} UTC';
}

/// "just now", "4 min ago", "3 h ago", "yesterday", "12 days ago", then a
/// date — for "scanned …" and "opened …", where the question is how stale,
/// not exactly when.
String formatRelative(DateTime at, DateTime now) {
  final elapsed = now.difference(at);
  if (elapsed.inSeconds < 45) return 'just now';
  if (elapsed.inMinutes < 60) {
    return '${elapsed.inMinutes.clamp(1, 59)} min ago';
  }
  if (elapsed.inHours < 24) return '${elapsed.inHours} h ago';
  if (elapsed.inDays == 1) return 'yesterday';
  if (elapsed.inDays < 30) return '${elapsed.inDays} days ago';
  return formatRecordedDate(at);
}

/// Decimal megabytes to one place — `25.4 MB` for the Race sample's
/// 25,358,336 bytes, the unit §5.5 quotes file sizes in.
String formatFileSize(int bytes) {
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000 * 1000) return '${(bytes / 1000).toStringAsFixed(0)} kB';
  return '${(bytes / 1e6).toStringAsFixed(1)} MB';
}

/// `1 lap` / `19 laps`.
String plural(int count, String one, [String? many]) =>
    '$count ${count == 1 ? one : (many ?? '${one}s')}';

String _two(int v) => v.toString().padLeft(2, '0');
