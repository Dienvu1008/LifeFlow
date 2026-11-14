import 'package:application/application.dart' show AppFont;
// P03 UX U1 (ADR-0045): the LifeFlow theme. Minimal chrome, neutral
// surfaces, colour only where it means something (U-D10), density by
// platform (U-D9), and the 12-colour palette for lists, tasks and events
// (U-D4). Every screen takes its colours from here, never from literals.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The neutral seed: a slate blue-grey (U-D10).
const lifeFlowSeed = Color(0xFF5B6B78);

/// Colours with a meaning, the same in every screen. Never used alone: an
/// icon or a text says the same thing (WCAG 1.4.1).
@immutable
class LifeFlowColors extends ThemeExtension<LifeFlowColors> {
  const LifeFlowColors({
    required this.important,
    required this.overdue,
    required this.done,
    required this.cancelled,
    required this.success,
    required this.missed,
    required this.noData,
    required this.focus,
    required this.conflict,
  });

  /// A task marked important (priority).
  final Color important;
  final Color overdue;
  final Color done;
  final Color cancelled;

  /// A habit's achieved or done period.
  final Color success;
  final Color missed;

  /// A period without data: neutral, not a failure (LF-INV-HEALTH-002).
  final Color noData;

  /// A focus session.
  final Color focus;

  /// Two items at the same time.
  final Color conflict;

  static const light = LifeFlowColors(
    important: Color(0xFFB45309),
    overdue: Color(0xFFB3261E),
    done: Color(0xFF2E7D32),
    cancelled: Color(0xFF6F7981),
    success: Color(0xFF2E7D32),
    missed: Color(0xFFC62828),
    noData: Color(0xFF6F7981),
    focus: Color(0xFF5E35B1),
    conflict: Color(0xFFD84315),
  );

  static const dark = LifeFlowColors(
    important: Color(0xFFFBBF24),
    overdue: Color(0xFFF2B8B5),
    done: Color(0xFF81C784),
    cancelled: Color(0xFF9AA4AC),
    success: Color(0xFF81C784),
    missed: Color(0xFFEF9A9A),
    noData: Color(0xFF9AA4AC),
    focus: Color(0xFFB39DDB),
    conflict: Color(0xFFFFAB91),
  );

  /// The colours of [context]'s theme (light ones when the theme has none).
  static LifeFlowColors of(BuildContext context) =>
      Theme.of(context).extension<LifeFlowColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  LifeFlowColors copyWith({
    Color? important,
    Color? overdue,
    Color? done,
    Color? cancelled,
    Color? success,
    Color? missed,
    Color? noData,
    Color? focus,
    Color? conflict,
  }) =>
      LifeFlowColors(
        important: important ?? this.important,
        overdue: overdue ?? this.overdue,
        done: done ?? this.done,
        cancelled: cancelled ?? this.cancelled,
        success: success ?? this.success,
        missed: missed ?? this.missed,
        noData: noData ?? this.noData,
        focus: focus ?? this.focus,
        conflict: conflict ?? this.conflict,
      );

  @override
  LifeFlowColors lerp(ThemeExtension<LifeFlowColors>? other, double t) {
    if (other is! LifeFlowColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return LifeFlowColors(
      important: l(important, other.important),
      overdue: l(overdue, other.overdue),
      done: l(done, other.done),
      cancelled: l(cancelled, other.cancelled),
      success: l(success, other.success),
      missed: l(missed, other.missed),
      noData: l(noData, other.noData),
      focus: l(focus, other.focus),
      conflict: l(conflict, other.conflict),
    );
  }
}

/// One colour of the item palette: a name (read out, shown in the picker)
/// and its tone on light and on dark surfaces.
class ItemColor {
  const ItemColor(this.name, this.light, this.dark);
  final String name;
  final Color light;
  final Color dark;

  Color on(Brightness b) => b == Brightness.dark ? dark : light;
}

/// U-D4: the 12 colours a list, task or event can have, stored by index
/// (0–11). Each tone keeps 3:1 against the surface it is shown on
/// (WCAG 1.4.11), tested in theme_test.dart.
const itemPalette = <ItemColor>[
  ItemColor('Red', Color(0xFFD32F2F), Color(0xFFEF9A9A)),
  ItemColor('Orange', Color(0xFFE65100), Color(0xFFFFB74D)),
  ItemColor('Amber', Color(0xFFB77400), Color(0xFFFFD54F)),
  ItemColor('Olive', Color(0xFF827717), Color(0xFFDCE775)),
  ItemColor('Green', Color(0xFF2E7D32), Color(0xFFA5D6A7)),
  ItemColor('Teal', Color(0xFF00796B), Color(0xFF80CBC4)),
  ItemColor('Cyan', Color(0xFF00838F), Color(0xFF80DEEA)),
  ItemColor('Blue', Color(0xFF1565C0), Color(0xFF90CAF9)),
  ItemColor('Indigo', Color(0xFF3949AB), Color(0xFF9FA8DA)),
  ItemColor('Purple', Color(0xFF7B1FA2), Color(0xFFCE93D8)),
  ItemColor('Pink', Color(0xFFC2185B), Color(0xFFF48FB1)),
  ItemColor('Brown', Color(0xFF6D4C41), Color(0xFFBCAAA4)),
];

/// The tone of palette colour [index] in [context]'s theme, or null for no
/// colour (or an index outside the palette).
Color? itemColorOf(BuildContext context, int? index) {
  if (index == null || index < 0 || index >= itemPalette.length) return null;
  return itemPalette[index].on(Theme.of(context).brightness);
}

/// Whether [platform] is used with a pointer (mouse, trackpad): denser
/// controls are fine there (U-D9). Phones keep 48 dp touch targets.
bool isPointerPlatform(TargetPlatform platform) => switch (platform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
    };

/// The bundled family of [font] (null = the system's), for ThemeData.
/// Dogfooding O3 (ADR-0051).
String? fontFamilyOf(AppFont font) => switch (font) {
      AppFont.system => null,
      AppFont.inter => 'packages/ui/Inter',
      AppFont.notoSans => 'packages/ui/NotoSans',
      AppFont.beVietnamPro => 'packages/ui/BeVietnamPro',
    };

/// The theme for [brightness] on [platform] (U1, ADR-0045), in [font].
ThemeData lifeFlowTheme(Brightness brightness, {TargetPlatform? platform, AppFont font = AppFont.system}) {
  final p = platform ?? defaultTargetPlatform;
  final pointer = isPointerPlatform(p);
  final scheme = ColorScheme.fromSeed(
    seedColor: lifeFlowSeed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    platform: p,
    fontFamily: fontFamilyOf(font),
    visualDensity: pointer ? VisualDensity.compact : VisualDensity.standard,
    materialTapTargetSize: pointer ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
    extensions: [brightness == Brightness.dark ? LifeFlowColors.dark : LifeFlowColors.light],
  );
  // Component styles below need sizes too: ThemeData.textTheme only gets them
  // when Theme.of localizes it, so they are merged in here (dogfooding O3).
  final text = Typography.material2021(platform: p).englishLike.merge(base.textTheme);
  return base.copyWith(
    // Less chrome: flat, untinted bars that do not change when scrolled under.
    appBarTheme: AppBarTheme(
      toolbarHeight: pointer ? 48 : 56,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      titleSpacing: pointer ? 12 : 16,
      titleTextStyle: text.titleMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600),
    ),
    // Dense rows: one-line tiles near the minimum height.
    listTileTheme: ListTileThemeData(
      dense: pointer,
      minVerticalPadding: pointer ? 2 : 4,
      horizontalTitleGap: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: pointer ? 12 : 16),
      minLeadingWidth: 24,
      // Dogfooding O3: one explicit size for row titles (tasks, events and
      // subtasks alike); a list's title is the same size, bolder.
      titleTextStyle: (pointer ? text.bodyMedium : text.bodyLarge)?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      surfaceTintColor: Colors.transparent,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      minWidth: pointer ? 64 : 72,
      minExtendedWidth: 200,
      indicatorColor: scheme.secondaryContainer,
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      tileHeight: pointer ? 44 : 52,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(visualDensity: pointer ? VisualDensity.compact : const VisualDensity(vertical: -1)),
    ),
    inputDecorationTheme: const InputDecorationTheme(isDense: true),
    popupMenuTheme: PopupMenuThemeData(surfaceTintColor: Colors.transparent, color: scheme.surfaceContainer),
    dialogTheme: DialogThemeData(surfaceTintColor: Colors.transparent, backgroundColor: scheme.surfaceContainerHigh),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
    ),
  );
}
