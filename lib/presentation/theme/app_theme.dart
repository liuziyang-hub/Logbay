import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/atmosphere_theme.dart';
import '../../features/logs/data/models/log_level.dart';
import 'text_theme.dart';
import 'theme_typography.dart';

extension ThemeModeExt on ThemeMode {
  String get label => switch (this) {
    ThemeMode.system => '自动',
    ThemeMode.light => '浅色',
    ThemeMode.dark => '深色',
  };

  String get description => switch (this) {
    ThemeMode.system => '跟随操作系统外观。',
    ThemeMode.light => '始终使用浅色外观。',
    ThemeMode.dark => '始终使用深色外观。',
  };
}

@immutable
class EaglyTheme extends ThemeExtension<EaglyTheme> {
  const EaglyTheme({
    required this.logBodyStyle,
    required this.logCompactStyle,
    required this.logHeaderStyle,
    required this.statusBarStyle,
    required this.verboseColor,
    required this.debugColor,
    required this.infoColor,
    required this.warningColor,
    required this.errorColor,
    required this.logBadgeForeground,
    required this.searchMatchColor,
    required this.searchCurrentMatchColor,
    required this.searchCurrentRowColor,
    required this.searchHighlightForeground,
    required this.searchNoResultsFillColor,
    required this.searchNoResultsTextColor,
    required this.inlineNoticeBackground,
    required this.inlineNoticeForeground,
    required this.statusLiveColor,
    required this.statusPausedColor,
    required this.statusStoppedColor,
    required this.cardShadowColor,
  });

  final TextStyle logBodyStyle;
  final TextStyle logCompactStyle;
  final TextStyle logHeaderStyle;
  final TextStyle statusBarStyle;
  final Color verboseColor;
  final Color debugColor;
  final Color infoColor;
  final Color warningColor;
  final Color errorColor;
  final Color logBadgeForeground;
  final Color searchMatchColor;
  final Color searchCurrentMatchColor;
  final Color searchCurrentRowColor;
  final Color searchHighlightForeground;
  final Color searchNoResultsFillColor;
  final Color searchNoResultsTextColor;
  final Color inlineNoticeBackground;
  final Color inlineNoticeForeground;
  final Color statusLiveColor;
  final Color statusPausedColor;
  final Color statusStoppedColor;
  final Color cardShadowColor;

  Color logLevelColor(String level) {
    return switch (LogLevel.fromStored(level).code) {
      'fault' || 'error' => errorColor,
      'warning' => warningColor,
      'default' || 'info' => infoColor,
      'debug' => debugColor,
      _ => verboseColor,
    };
  }

  @override
  EaglyTheme copyWith({
    TextStyle? logBodyStyle,
    TextStyle? logCompactStyle,
    TextStyle? logHeaderStyle,
    TextStyle? statusBarStyle,
    Color? verboseColor,
    Color? debugColor,
    Color? infoColor,
    Color? warningColor,
    Color? errorColor,
    Color? logBadgeForeground,
    Color? searchMatchColor,
    Color? searchCurrentMatchColor,
    Color? searchCurrentRowColor,
    Color? searchHighlightForeground,
    Color? searchNoResultsFillColor,
    Color? searchNoResultsTextColor,
    Color? inlineNoticeBackground,
    Color? inlineNoticeForeground,
    Color? statusLiveColor,
    Color? statusPausedColor,
    Color? statusStoppedColor,
    Color? cardShadowColor,
  }) {
    return EaglyTheme(
      logBodyStyle: logBodyStyle ?? this.logBodyStyle,
      logCompactStyle: logCompactStyle ?? this.logCompactStyle,
      logHeaderStyle: logHeaderStyle ?? this.logHeaderStyle,
      statusBarStyle: statusBarStyle ?? this.statusBarStyle,
      verboseColor: verboseColor ?? this.verboseColor,
      debugColor: debugColor ?? this.debugColor,
      infoColor: infoColor ?? this.infoColor,
      warningColor: warningColor ?? this.warningColor,
      errorColor: errorColor ?? this.errorColor,
      logBadgeForeground: logBadgeForeground ?? this.logBadgeForeground,
      searchMatchColor: searchMatchColor ?? this.searchMatchColor,
      searchCurrentMatchColor:
          searchCurrentMatchColor ?? this.searchCurrentMatchColor,
      searchCurrentRowColor:
          searchCurrentRowColor ?? this.searchCurrentRowColor,
      searchHighlightForeground:
          searchHighlightForeground ?? this.searchHighlightForeground,
      searchNoResultsFillColor:
          searchNoResultsFillColor ?? this.searchNoResultsFillColor,
      searchNoResultsTextColor:
          searchNoResultsTextColor ?? this.searchNoResultsTextColor,
      inlineNoticeBackground:
          inlineNoticeBackground ?? this.inlineNoticeBackground,
      inlineNoticeForeground:
          inlineNoticeForeground ?? this.inlineNoticeForeground,
      statusLiveColor: statusLiveColor ?? this.statusLiveColor,
      statusPausedColor: statusPausedColor ?? this.statusPausedColor,
      statusStoppedColor: statusStoppedColor ?? this.statusStoppedColor,
      cardShadowColor: cardShadowColor ?? this.cardShadowColor,
    );
  }

  @override
  EaglyTheme lerp(ThemeExtension<EaglyTheme>? other, double t) {
    if (other is! EaglyTheme) {
      return this;
    }

    return EaglyTheme(
      logBodyStyle: TextStyle.lerp(logBodyStyle, other.logBodyStyle, t)!,
      logCompactStyle: TextStyle.lerp(
        logCompactStyle,
        other.logCompactStyle,
        t,
      )!,
      logHeaderStyle: TextStyle.lerp(logHeaderStyle, other.logHeaderStyle, t)!,
      statusBarStyle: TextStyle.lerp(statusBarStyle, other.statusBarStyle, t)!,
      verboseColor: Color.lerp(verboseColor, other.verboseColor, t)!,
      debugColor: Color.lerp(debugColor, other.debugColor, t)!,
      infoColor: Color.lerp(infoColor, other.infoColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      errorColor: Color.lerp(errorColor, other.errorColor, t)!,
      logBadgeForeground: Color.lerp(
        logBadgeForeground,
        other.logBadgeForeground,
        t,
      )!,
      searchMatchColor: Color.lerp(
        searchMatchColor,
        other.searchMatchColor,
        t,
      )!,
      searchCurrentMatchColor: Color.lerp(
        searchCurrentMatchColor,
        other.searchCurrentMatchColor,
        t,
      )!,
      searchCurrentRowColor: Color.lerp(
        searchCurrentRowColor,
        other.searchCurrentRowColor,
        t,
      )!,
      searchHighlightForeground: Color.lerp(
        searchHighlightForeground,
        other.searchHighlightForeground,
        t,
      )!,
      searchNoResultsFillColor: Color.lerp(
        searchNoResultsFillColor,
        other.searchNoResultsFillColor,
        t,
      )!,
      searchNoResultsTextColor: Color.lerp(
        searchNoResultsTextColor,
        other.searchNoResultsTextColor,
        t,
      )!,
      inlineNoticeBackground: Color.lerp(
        inlineNoticeBackground,
        other.inlineNoticeBackground,
        t,
      )!,
      inlineNoticeForeground: Color.lerp(
        inlineNoticeForeground,
        other.inlineNoticeForeground,
        t,
      )!,
      statusLiveColor: Color.lerp(statusLiveColor, other.statusLiveColor, t)!,
      statusPausedColor: Color.lerp(
        statusPausedColor,
        other.statusPausedColor,
        t,
      )!,
      statusStoppedColor: Color.lerp(
        statusStoppedColor,
        other.statusStoppedColor,
        t,
      )!,
      cardShadowColor: Color.lerp(cardShadowColor, other.cardShadowColor, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  EaglyTheme get eaglyTheme => Theme.of(this).extension<EaglyTheme>()!;
}

class AppTheme {
  /// Lake A5 · Abyss + Habanero defaults (video-matched dark bases).
  static const Color canvas = Color(0xFF08131D);
  static const Color canvasLight = Color(0xFFF0EEEC);
  static const Color accentOrange = Color(0xFF2D7AA0);
  static const Color accentOrangeDeep = Color(0xFF1C4C66);
  static const Color accentOrangeSoft = Color(0xFFF98513);
  static const Color brandTeal = Color(0xFF9FD2E3);
  static const Color brandPurple = Color(0xFF9FD2E3);
  static const Color glassFill = Color(0xF30F2A3B);
  static const Color glassBorder = Color(0x552D7AA0);

  static const Color seedColor = accentOrange;

  static final ThemeData lightTheme = _buildTheme(
    _lightColorScheme,
    _themeTokens(_lightColorScheme),
  );

  static final ThemeData darkTheme = _buildTheme(
    _darkColorScheme,
    _themeTokens(_darkColorScheme),
  );

  /// Dark Material theme owned by one of the three visual themes.
  static ThemeData darkThemeFor(AtmosphereTheme atmosphere) {
    final scheme = switch (atmosphere) {
      AtmosphereTheme.lake => _darkColorScheme,
      AtmosphereTheme.forest => _forestDarkColorScheme,
      AtmosphereTheme.universe => _universeDarkColorScheme,
    };
    return _buildTheme(
      scheme,
      _themeTokens(scheme, atmosphere: atmosphere),
      atmosphere: atmosphere,
    );
  }

  /// Forest B6 · Misty Forest — cool moss layers.
  static final ColorScheme _forestDarkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: const Color(0xFF52796F),
    onPrimary: const Color(0xFFE9EFEC),
    primaryContainer: const Color(0xFF3B4A45),
    onPrimaryContainer: const Color(0xFFE9EFEC),
    secondary: const Color(0xFF84A98C),
    onSecondary: const Color(0xFF1A2820),
    secondaryContainer: const Color(0xFF3A4E42),
    onSecondaryContainer: const Color(0xFFD8E8DE),
    tertiary: const Color(0xFFC4A574),
    onTertiary: const Color(0xFF1A1408),
    error: const Color(0xFFFCA5A5),
    onError: const Color(0xFF151519),
    surface: const Color(0xFF3B4A45),
    onSurface: const Color(0xFFE9EFEC),
    surfaceContainerLowest: const Color(0xFF2A3230),
    surfaceContainerLow: const Color(0xFF303836),
    surfaceContainer: const Color(0xFF3B4A45),
    surfaceContainerHigh: const Color(0xFF465650),
    surfaceContainerHighest: const Color(0xFF52645C),
    onSurfaceVariant: const Color(0xFFC0D0C8),
    outline: const Color(0xFF6A8078),
    outlineVariant: const Color(0x5552796F),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: const Color(0xFFE9EFEC),
    onInverseSurface: const Color(0xFF2A3230),
    inversePrimary: const Color(0xFF3B4A45),
  );

  /// Universe U1 · Stellar Midnight — periwinkle + deep indigo + starlight cream.
  static final ColorScheme _universeDarkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: const Color(0xFFA9B6FF),
    onPrimary: const Color(0xFF0B1026),
    primaryContainer: const Color(0xFF2F3C7E),
    onPrimaryContainer: const Color(0xFFE8ECFF),
    secondary: const Color(0xFF2F3C7E),
    onSecondary: const Color(0xFFE8ECFF),
    secondaryContainer: const Color(0xFF1A2A4F),
    onSecondaryContainer: const Color(0xFFD0D8FF),
    tertiary: const Color(0xFFF2E8C9),
    onTertiary: const Color(0xFF2A2410),
    error: const Color(0xFFFCA5A5),
    onError: const Color(0xFF151519),
    surface: const Color(0xFF1A2A4F),
    onSurface: const Color(0xFFE8ECFF),
    surfaceContainerLowest: const Color(0xFF0B1026),
    surfaceContainerLow: const Color(0xFF101830),
    surfaceContainer: const Color(0xFF1A2A4F),
    surfaceContainerHigh: const Color(0xFF243460),
    surfaceContainerHighest: const Color(0xFF2F3C7E),
    onSurfaceVariant: const Color(0xFFC0C8E8),
    outline: const Color(0xFF5A6688),
    outlineVariant: const Color(0x55A9B6FF),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: const Color(0xFFE8ECFF),
    onInverseSurface: const Color(0xFF0B1026),
    inversePrimary: const Color(0xFF2F3C7E),
  );

  static final ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: accentOrangeDeep,
    onPrimary: const Color(0xFF151519),
    primaryContainer: const Color(0xFFFFE4D4),
    onPrimaryContainer: const Color(0xFF5C2E14),
    secondary: brandPurple,
    onSecondary: const Color(0xFFFFFFFF),
    secondaryContainer: const Color(0xFFE8DFF5),
    onSecondaryContainer: const Color(0xFF3A2A55),
    tertiary: accentOrangeSoft,
    onTertiary: const Color(0xFF151519),
    error: const Color(0xFFB3261E),
    onError: const Color(0xFFFFFFFF),
    surface: const Color(0xFFF7F5F3),
    onSurface: const Color(0xFF181818),
    surfaceContainerLowest: canvasLight,
    surfaceContainerLow: const Color(0xFFF3F0ED),
    surfaceContainer: const Color(0xFFEDE8E3),
    surfaceContainerHigh: const Color(0xFFE6E0DA),
    surfaceContainerHighest: const Color(0xFFDDD6CF),
    onSurfaceVariant: const Color(0xFF5C5C60),
    outline: const Color(0xFFB0B0B4),
    outlineVariant: const Color(0xFFD8D4CF),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: const Color(0xFF1D1D20),
    onInverseSurface: const Color(0xFFF1F1F1),
    inversePrimary: accentOrangeSoft,
  );

  /// Lake A5 · Abyss + Habanero — deep blue CTA + ice secondary + orange spark.
  static final ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: accentOrange,
    onPrimary: const Color(0xFFE8F4F8),
    primaryContainer: accentOrangeDeep,
    onPrimaryContainer: const Color(0xFFE8F4F8),
    secondary: brandTeal,
    onSecondary: const Color(0xFF08131D),
    secondaryContainer: const Color(0xFF1C4C66),
    onSecondaryContainer: const Color(0xFFD4EBF2),
    tertiary: accentOrangeSoft,
    onTertiary: const Color(0xFF1A0C00),
    error: const Color(0xFFFCA5A5),
    onError: const Color(0xFF151519),
    surface: const Color(0xFF0F2A3B),
    onSurface: const Color(0xFFE8F4F8),
    surfaceContainerLowest: const Color(0xFF08131D),
    surfaceContainerLow: const Color(0xFF0B1C28),
    surfaceContainer: const Color(0xFF0F2A3B),
    surfaceContainerHigh: const Color(0xFF163848),
    surfaceContainerHighest: const Color(0xFF1E4658),
    onSurfaceVariant: const Color(0xFFA8C8D8),
    outline: const Color(0xFF4A6A7A),
    outlineVariant: const Color(0x552D7AA0),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: const Color(0xFFE8F4F8),
    onInverseSurface: const Color(0xFF08131D),
    inversePrimary: accentOrangeDeep,
  );

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    EaglyTheme tokens, {
    AtmosphereTheme atmosphere = AtmosphereTheme.lake,
  }) {
    final isUniverse = atmosphere == AtmosphereTheme.universe;
    final isForest = atmosphere == AtmosphereTheme.forest;
    final isLake = atmosphere == AtmosphereTheme.lake;
    final baseTheme = ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
      textTheme: appTextTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
    );

    // Font pairings matched to each palette (warm / moss / starlight).
    final TextTheme rawTextTheme = ThemeTypography.materialTextTheme(
      atmosphere,
      baseTheme.textTheme,
    );
    final textTheme = rawTextTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    final cursorStyle = WidgetStatePropertyAll(SystemMouseCursors.click);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    );
    final buttonRadius = BorderRadius.circular(isUniverse ? 999 : (isForest ? 14 : 12));
    final useStarlightPill = isUniverse;
    final useMistPill = isLake;

    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        menuPadding: EdgeInsets.symmetric(vertical: 4),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
          visualDensity: VisualDensity.compact,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHighest,
        ),
        headingTextStyle: tokens.logHeaderStyle,
        dataTextStyle: tokens.logCompactStyle,
        dividerThickness: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.4),
        selectionHandleColor: colorScheme.primary,
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        visualDensity: VisualDensity(vertical: -4, horizontal: -4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: colorScheme.brightness == Brightness.dark ? 0.3 : 0.72,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 1.3),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 1.3),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          mouseCursor: cursorStyle,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.12);
            }
            if (useStarlightPill) return const Color(0xFFE8ECF5);
            if (useMistPill) return colorScheme.primary;
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStatePropertyAll(
            useStarlightPill
                ? const Color(0xFF05060A)
                : colorScheme.onPrimary,
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: isUniverse ? 0.4 : 0.2,
            ),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: isUniverse || isLake ? 20 : 16,
              vertical: isUniverse || isLake ? 12 : 10,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: buttonRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: cursorStyle,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          mouseCursor: cursorStyle,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: buttonRadius),
          ),
        ),
      ),
      iconTheme: IconThemeData(size: 20, color: colorScheme.onSurfaceVariant),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          mouseCursor: cursorStyle,
          iconSize: WidgetStatePropertyAll(18),
          minimumSize: WidgetStatePropertyAll(const Size(24, 24)),
          maximumSize: WidgetStatePropertyAll(const Size(32, 32)),
          padding: WidgetStatePropertyAll(const EdgeInsets.all(6)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(padding: EdgeInsets.zero),
      extensions: [tokens],
    );
  }

  static EaglyTheme _themeTokens(
    ColorScheme colorScheme, {
    AtmosphereTheme atmosphere = AtmosphereTheme.lake,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final mono = GoogleFonts.jetBrainsMono();

    return EaglyTheme(
      logBodyStyle: mono.copyWith(fontSize: 12, height: 1.2),
      logCompactStyle: mono.copyWith(fontSize: 11, height: 1.2),
      logHeaderStyle: mono.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
      statusBarStyle: TextStyle(
        fontSize: 12,
        height: 1,
        color: colorScheme.onSurfaceVariant,
      ),
      verboseColor: isDark ? colorScheme.onSurfaceVariant : colorScheme.outline,
      debugColor: switch (atmosphere) {
        AtmosphereTheme.universe => const Color(0xFFF2E8C9),
        AtmosphereTheme.forest => const Color(0xFFB0C4BB),
        AtmosphereTheme.lake => accentOrangeSoft,
      },
      infoColor: switch (atmosphere) {
        AtmosphereTheme.universe => const Color(0xFFA9B6FF),
        AtmosphereTheme.forest => const Color(0xFF84A98C),
        AtmosphereTheme.lake => brandTeal,
      },
      warningColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      errorColor: isDark ? const Color(0xFFFCA5A5) : colorScheme.error,
      logBadgeForeground: isDark
          ? const Color(0xFF1E1F21)
          : const Color(0xFFDCE2F3),
      searchMatchColor: isDark
          ? const Color(0xFFFDE68A)
          : const Color(0xFFFDE68A),
      searchCurrentMatchColor: isDark
          ? const Color(0xFFFBBF24)
          : const Color(0xFFF59E0B),
      searchCurrentRowColor: colorScheme.secondaryContainer.withValues(
        alpha: isDark ? 0.26 : 0.42,
      ),
      searchHighlightForeground: const Color(0xFF111827),
      searchNoResultsFillColor: colorScheme.errorContainer,
      searchNoResultsTextColor: colorScheme.onErrorContainer,
      inlineNoticeBackground: colorScheme.secondaryContainer,
      inlineNoticeForeground: colorScheme.onSecondaryContainer,
      statusLiveColor: switch (atmosphere) {
        AtmosphereTheme.universe => const Color(0xFFA9B6FF),
        AtmosphereTheme.forest => const Color(0xFF84A98C),
        AtmosphereTheme.lake => brandTeal,
      },
      statusPausedColor: isDark
          ? const Color(0xFFFBBF24)
          : const Color(0xFFB45309),
      statusStoppedColor: isDark ? const Color(0xFFF87171) : colorScheme.error,
      cardShadowColor: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
    );
  }
}
