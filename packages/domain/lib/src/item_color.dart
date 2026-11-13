// P03 UX U2 (ADR-0046, owner decision U-D4): a list, a task or an event can
// carry one of a fixed palette of 12 colours, stored as its index. The
// colours themselves (light and dark tones) belong to the UI theme
// (ADR-0045); the data keeps only the index, so a theme change never
// rewrites data.

/// The size of the item palette.
const int itemColorCount = 12;

/// A reason when [index] is not a palette colour (null = no colour, valid).
String? itemColorError(int? index) =>
    index == null || (index >= 0 && index < itemColorCount) ? null : 'unknown colour';
