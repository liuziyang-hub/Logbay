import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/atmosphere_theme.dart';

/// Shared display / body type styles paired to each visual theme's palette.
abstract final class ThemeTypography {
  static TextStyle brand(
    AtmosphereTheme atmosphere, {
    required double fontSize,
    List<Shadow>? shadows,
  }) {
    return switch (atmosphere) {
      // Warm serif + ivory — echoes coral sunset kits
      AtmosphereTheme.lake => GoogleFonts.cormorantGaramond(
          color: atmosphere.titleColor,
          fontSize: fontSize + 2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          height: 1.12,
          shadows: shadows,
        ),
      // Soft optical serif — lighter than Merriweather on moss green
      AtmosphereTheme.forest => GoogleFonts.fraunces(
          color: atmosphere.titleColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          height: 1.15,
          shadows: shadows,
        ),
      // Tall classical display — cool with starlight silver
      AtmosphereTheme.universe => GoogleFonts.italiana(
          color: atmosphere.titleColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.8,
          height: 1.12,
          shadows: shadows,
        ),
    };
  }

  static TextStyle tagline(
    AtmosphereTheme atmosphere, {
    List<Shadow>? shadows,
  }) {
    return switch (atmosphere) {
      AtmosphereTheme.lake => GoogleFonts.dmSans(
          color: atmosphere.bodyColor,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          height: 1.55,
          letterSpacing: 0.2,
          shadows: shadows,
        ),
      AtmosphereTheme.forest => GoogleFonts.nunito(
          color: atmosphere.bodyColor,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          height: 1.55,
          letterSpacing: 0.15,
          shadows: shadows,
        ),
      AtmosphereTheme.universe => GoogleFonts.notoSerifSc(
          color: atmosphere.bodyColor,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.65,
          letterSpacing: 1.2,
          shadows: shadows,
        ),
    };
  }

  static TextStyle badge(AtmosphereTheme atmosphere) {
    return switch (atmosphere) {
      AtmosphereTheme.lake => GoogleFonts.dmSans(
          color: atmosphere.mutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.25,
        ),
      AtmosphereTheme.forest => GoogleFonts.nunito(
          color: atmosphere.mutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      AtmosphereTheme.universe => GoogleFonts.outfit(
          color: atmosphere.mutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.35,
        ),
    };
  }

  static TextStyle cardTitle(AtmosphereTheme atmosphere) {
    return switch (atmosphere) {
      AtmosphereTheme.lake => GoogleFonts.cormorantGaramond(
          color: atmosphere.cardTitleColor,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0.15,
        ),
      AtmosphereTheme.forest => GoogleFonts.fraunces(
          color: atmosphere.cardTitleColor,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      AtmosphereTheme.universe => GoogleFonts.cormorantGaramond(
          color: atmosphere.cardTitleColor,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0.2,
        ),
    };
  }

  static TextStyle cardBody(AtmosphereTheme atmosphere) {
    return switch (atmosphere) {
      AtmosphereTheme.lake => GoogleFonts.dmSans(
          color: atmosphere.cardBodyColor,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
      AtmosphereTheme.forest => GoogleFonts.nunito(
          color: atmosphere.cardBodyColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
      AtmosphereTheme.universe => GoogleFonts.outfit(
          color: atmosphere.cardBodyColor,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.45,
          letterSpacing: 0.1,
        ),
    };
  }

  static TextStyle chipLabel(AtmosphereTheme atmosphere) {
    return switch (atmosphere) {
      AtmosphereTheme.lake => GoogleFonts.dmSans(
          color: atmosphere.chipForeground,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      AtmosphereTheme.forest => GoogleFonts.nunito(
          color: atmosphere.chipForeground,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      AtmosphereTheme.universe => GoogleFonts.outfit(
          color: atmosphere.chipForeground,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
    };
  }

  static TextTheme materialTextTheme(
    AtmosphereTheme atmosphere,
    TextTheme base,
  ) {
    return switch (atmosphere) {
      AtmosphereTheme.lake => GoogleFonts.dmSansTextTheme(base),
      AtmosphereTheme.forest => GoogleFonts.nunitoTextTheme(base),
      AtmosphereTheme.universe => GoogleFonts.outfitTextTheme(base),
    };
  }
}
