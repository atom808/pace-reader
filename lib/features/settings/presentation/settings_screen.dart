import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Settings',
      icon: Icons.settings_outlined,
    );
  }
}
