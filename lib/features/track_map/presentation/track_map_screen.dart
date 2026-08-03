import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class TrackMapScreen extends StatelessWidget {
  const TrackMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Track map',
      icon: Icons.map_outlined,
    );
  }
}
