import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class CarBehaviorScreen extends StatelessWidget {
  const CarBehaviorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Car behavior',
      icon: Icons.directions_car_outlined,
    );
  }
}
