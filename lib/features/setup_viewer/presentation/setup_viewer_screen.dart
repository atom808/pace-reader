import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class SetupViewerScreen extends StatelessWidget {
  const SetupViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Setup viewer',
      icon: Icons.build_outlined,
    );
  }
}
