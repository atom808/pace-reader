import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class LapAnalysisScreen extends StatelessWidget {
  const LapAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Lap analysis',
      icon: Icons.timer_outlined,
    );
  }
}
