import 'package:flutter/material.dart';

import '../../../widgets/common/feature_placeholder_screen.dart';

class SessionLibraryScreen extends StatelessWidget {
  const SessionLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholderScreen(
      title: 'Session library',
      icon: Icons.folder_open_outlined,
    );
  }
}
