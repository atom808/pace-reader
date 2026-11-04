import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'features/track_outline/data/public_outlines.dart';

void main() {
  LicenseRegistry.addLicense(publicOutlineLicences);
  runApp(const ProviderScope(child: PaceReaderApp()));
}
