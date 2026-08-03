import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class DriverComparisonScreen extends StatelessWidget {
  const DriverComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Driver comparison',
      icon: Icons.compare_arrows_outlined,
    );
  }
}
