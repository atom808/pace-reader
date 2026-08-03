import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class RacePaceScreen extends StatelessWidget {
  const RacePaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Race pace & gaps',
      icon: Icons.speed_outlined,
    );
  }
}
