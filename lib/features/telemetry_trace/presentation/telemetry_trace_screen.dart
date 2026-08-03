import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class TelemetryTraceScreen extends StatelessWidget {
  const TelemetryTraceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Telemetry trace',
      icon: Icons.show_chart,
    );
  }
}
