/// Picks the results index's storage and filesystem per platform, at compile
/// time, as the Session Library's `platform.dart` does.
library;

export 'platform_web.dart' if (dart.library.io) 'platform_io.dart';
