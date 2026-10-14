import 'package:material_ui/material_ui.dart';

/// The app's [Tooltip]: the same tooltip, in a semantics node of its own.
///
/// A [Tooltip] shows its message through an [OverlayPortal], and the portal
/// hangs the overlay's semantics node under its anchor's (the
/// `traversalParentIdentifier` mechanism). The anchor is only an annotation,
/// so it lands in whatever node encloses the tooltip, and a node keeps the
/// first such identifier it is given and drops the rest: a list row or a card
/// holding two tooltips loses the second's, and a tooltip under
/// `excludeSemantics` loses its own. Showing a tooltip whose anchor was lost
/// sends its overlay as a node that no parent lists. The Windows accessibility
/// bridge rejects that update — and, its tree now out of step with the
/// framework's, every update after it, for the rest of the session: the
/// `Failed to update ui::AXTree` errors whenever Narrator or any other UI
/// Automation client is attached. (Flutter 3.47; measured against the engine
/// itself, not inferred.)
///
/// A container per tooltip gives every anchor a node to itself — the shape
/// Material's own buttons already have, whose `tooltip:` sits inside their
/// `Semantics(container: true)`. It also keeps every message reachable to a
/// screen reader: merged into a shared node, a second tooltip's message was
/// dropped the same way its anchor was.
///
/// So use this, not [Tooltip], and keep it out of `excludeSemantics`: a row
/// that composes one label for a screen reader excludes its visible text piece
/// by piece instead (see `SettingRow`). The same goes for any other
/// [OverlayPortal] — wrap it in a container of its own.
class AppTooltip extends StatelessWidget {
  const AppTooltip({
    super.key,
    required this.message,
    this.waitDuration,
    this.excludeFromSemantics,
    required this.child,
  });

  final String message;

  /// [Tooltip.waitDuration].
  final Duration? waitDuration;

  /// [Tooltip.excludeFromSemantics]. The container is kept either way: the
  /// overlay needs the anchor's node whether or not the message is announced.
  final bool? excludeFromSemantics;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Tooltip(
        message: message,
        waitDuration: waitDuration,
        excludeFromSemantics: excludeFromSemantics,
        child: child,
      ),
    );
  }
}
