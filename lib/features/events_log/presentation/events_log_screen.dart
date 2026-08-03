import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class EventsLogScreen extends StatelessWidget {
  const EventsLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Events log',
      icon: Icons.list_alt_outlined,
    );
  }
}
