import 'dart:io';

import 'package:eagly/constants/atmosphere_theme.dart';
import 'package:eagly/presentation/theme/theme_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all visual themes keep their primary font and add CJK fallbacks', () {
    final expectedCjkFont = Platform.isWindows
        ? 'Microsoft YaHei UI'
        : Platform.isMacOS
        ? 'PingFang SC'
        : 'Noto Sans CJK SC';
    final primaryFonts = <AtmosphereTheme, String>{
      AtmosphereTheme.lake: 'DM Sans',
      AtmosphereTheme.forest: 'Nunito',
      AtmosphereTheme.universe: 'Outfit',
    };

    for (final atmosphere in AtmosphereTheme.values) {
      final primaryFont = primaryFonts[atmosphere]!;
      final textTheme = ThemeTypography.withPlatformCjkFallback(
        TextTheme(
          bodyMedium: TextStyle(fontFamily: primaryFont),
          titleMedium: TextStyle(fontFamily: primaryFont),
          labelLarge: TextStyle(fontFamily: primaryFont),
        ),
      );
      for (final style in [
        textTheme.bodyMedium,
        textTheme.titleMedium,
        textTheme.labelLarge,
      ]) {
        expect(style, isNotNull);
        expect(style!.fontFamily, primaryFont);
        expect(style.fontFamilyFallback, contains(expectedCjkFont));
        expect(style.locale, const Locale('zh', 'CN'));
      }
    }
  });
}
