// Host side of `flutter drive` for integration_test/scrub_perf_test.dart
// (SPEC.md §15.3): writes whatever the app reported to build/<key>_perf.json.

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        Directory('build').createSync(recursive: true);
        for (final entry in data.entries) {
          File('build/${entry.key}_perf.json').writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(entry.value),
          );
        }
      },
    );
