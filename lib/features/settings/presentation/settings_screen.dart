import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
import '../application/app_settings.dart';

/// Preferences: the interface size and the layout of the paired views.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Interface size', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Scales everything: text, charts and spacing together. '
                    'Ctrl + and Ctrl − change it from anywhere, Ctrl 0 '
                    'restores it. A larger size lays the window out as a '
                    'smaller one, so panes that need room fold away sooner.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<double>(
                        segments: [
                          for (final step in AppSettings.uiScaleSteps)
                            ButtonSegment(
                              value: step,
                              label: Text('${(step * 100).round()}%'),
                            ),
                        ],
                        selected: {
                          AppSettings.uiScaleSteps.firstWhere(
                            (s) => (s - settings.uiScale).abs() < 0.001,
                            orElse: () => settings.uiScale,
                          ),
                        },
                        emptySelectionAllowed: true,
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          shape: WidgetStatePropertyAll(
                            AppRadii.squircle(AppRadii.sm),
                          ),
                        ),
                        onSelectionChanged: (selection) {
                          if (selection.isNotEmpty) {
                            notifier.setUiScale(selection.first);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Performance mode',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: settings.performanceMode,
                        onChanged: notifier.setPerformanceMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Turns off the frosted glass behind panels and the map '
                    'drawing itself when a lap opens. Layout, data and '
                    'animations stay. Try it if playback on the map stutters '
                    'on this machine.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 32),
                  Text('Map and trace layout', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Drag the edge of the traces beside the map to give '
                    'either more room; double-click it to put it back. '
                    'It sets ${settings.sidePaneWidth.round()} px now, for '
                    'the traces on Trace and the map pane on Compare.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: settings.sidePaneWidth ==
                            AppSettings.defaultSidePaneWidth
                        ? null
                        : notifier.resetSidePaneWidth,
                    child: const Text('Reset pane width'),
                  ),
                  const SizedBox(height: 32),
                  Text('Trace charts', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Scroll moves the page. Ctrl + scroll zooms the trace '
                    'about the pointer, Shift + scroll pans it sideways, '
                    'drag pans, double-click fits the lap.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
