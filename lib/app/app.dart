import 'package:flutter/material.dart';

import '../widgets/design_system/design_system.dart';
import 'router.dart';

class PaceReaderApp extends StatelessWidget {
  const PaceReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pace Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
