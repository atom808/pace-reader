import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown by any feature screen reached with no session open.
///
/// Every screen from §8.2 onward needs a session, and the nav rail lets the
/// user reach all of them at any time — so "nothing is open yet" is a normal
/// state to land in, not an error, and it should offer the way out rather than
/// just reporting the absence.
class NoSessionScreen extends StatelessWidget {
  const NoSessionScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No session open', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Open a telemetry file to see $title.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/sessions'),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Go to sessions'),
            ),
          ],
        ),
      ),
    );
  }
}
