import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class SessionOverviewScreen extends StatelessWidget {
  const SessionOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Session overview',
      icon: Icons.dashboard_outlined,
    );
  }
}
