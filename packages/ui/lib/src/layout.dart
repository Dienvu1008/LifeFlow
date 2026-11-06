/// Layout classes driven by window WIDTH, not device type
/// (ui-ux-architecture.md §1–2, NFR-UX-01).
enum LayoutClass {
  /// Phone-sized window: single pane, bottom navigation.
  compact,

  /// Small tablet / narrow desktop window: navigation rail + main pane.
  medium,

  /// Tablet landscape / desktop: extended navigation + main workspace.
  expanded,
}

/// Provisional breakpoints (OQ-UI-1: confirm with benchmarks later). They
/// follow the Material 3 window size classes.
const double mediumBreakpoint = 600;
const double expandedBreakpoint = 840;

LayoutClass layoutClassFor(double width) {
  if (width >= expandedBreakpoint) return LayoutClass.expanded;
  if (width >= mediumBreakpoint) return LayoutClass.medium;
  return LayoutClass.compact;
}
