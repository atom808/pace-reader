/// Picks the library's storage and filesystem per platform, at compile time.
///
/// A conditional export rather than a runtime `kIsWeb` branch, because the
/// desktop half imports `dart:io` and drift's native connection, neither of
/// which compiles for the browser at all.
library;

export 'platform_web.dart' if (dart.library.io) 'platform_io.dart';
