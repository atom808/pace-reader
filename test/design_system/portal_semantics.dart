// What the Windows accessibility bridge rejects, checked in the test runner
// (see `AppTooltip`). Both need semantics on: `tester.ensureSemantics()`.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every [OverlayPortal] anchor — a tooltip's, a popover's — whose identifier
/// did not reach a semantics node, as creator chains.
///
/// Such a portal is fine while closed. Opened, it sends its overlay as a node
/// that no parent lists.
List<String> orphanablePortalAnchors(WidgetTester tester) {
  final found = <String>[];
  void visit(Element element) {
    final widget = element.widget;
    final id = widget is Semantics
        ? widget.properties.traversalParentIdentifier
        : null;
    if (id != null) {
      RenderObject? owner = element.renderObject;
      if (owner != null && owner.attached) {
        while (owner != null && owner.debugSemantics == null) {
          owner = owner.parent;
        }
        if (owner?.debugSemantics?.traversalParentIdentifier != id) {
          found.add(element.debugGetCreatorChain(8));
        }
      }
    }
    element.visitChildren(visit);
  }

  tester.binding.rootElement!.visitChildren(visit);
  return found;
}

/// Every node the framework would send that no node lists as a child, in the
/// traversal order the engine builds its tree from.
List<SemanticsNode> unlistedSemanticsNodes(WidgetTester tester) {
  final all = <SemanticsNode>[];
  final listed = <int>{};
  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root == null) continue;
    listed.add(root.id);
    bool visit(SemanticsNode node) {
      all.add(node);
      if (!node.mergeAllDescendantsIntoThisNode) {
        listed.addAll(
          node
              .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
              .map((child) => child.id),
        );
      }
      node.visitChildren(visit);
      return true;
    }

    visit(root);
  }
  return [
    for (final node in all)
      if (!node.isMergedIntoParent && !listed.contains(node.id)) node,
  ];
}
