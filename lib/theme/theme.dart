import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../service/setting/setting_provider.dart';
import 'color.dart';

class AppTheme {
  AppTheme._();

  // Responsive scaling
  static double _scale(BuildContext context) {
    final width = MediaQuery.of(context).size.shortestSide;
    if (width < 360) return 0.85;
    if (width < 400) return 1.0;
    if (width < 600) return 1.1;
    if (width < 900) return 1.25;
    return 1.4;
  }


  static const double _baseBody = 16.0;
  static const double _baseTitle = 16.0;
  static const double _baseHeadline = 24.0;

  // Replace your entire _ts method with THIS:
  static TextStyle _ts({
    required BuildContext context,
    required double baseSize,
    FontWeight weight = FontWeight.normal,
    Color? color,
  }) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final scale = _scale(context);

    final fontFunction = switch (settings.fontFamily) {
      'Nunito' => GoogleFonts.nunito,
      'Lato' => GoogleFonts.lato,
      'Playfair Display' => GoogleFonts.playfairDisplay,
      'Merriweather' => GoogleFonts.merriweather,
      'Comfortaa' => GoogleFonts.comfortaa,
      _ => GoogleFonts.roboto,
    };

    return fontFunction(
      textStyle: TextStyle(
        // ← THIS LINE WAS MISSING!
        fontSize: baseSize * scale,
        fontWeight: settings.fontBold ? FontWeight.bold : weight,
        fontStyle: settings.fontItalic ? FontStyle.italic : FontStyle.normal,
        color: color,
        height: 1.5,
        letterSpacing: 0.15,
      ),
    );
  }

  static ThemeData light(BuildContext context) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    colorScheme: const ColorScheme.light(
      surface: bgLight,
      onSurface: lightIconBackgroundColor,
      primary: fontLight,
      onPrimary: subFontLight,
      primaryContainer: containerLight,
      onPrimaryContainer: forGroundLight,
      outline: outlineLight,
      outlineVariant: forGroundOutlineLight,
    ),
    scaffoldBackgroundColor: bgLight,
    textTheme: TextTheme(
      displayLarge: _ts(
        context: context,
        baseSize: 36,
        weight: FontWeight.bold,
        color: fontLight,
      ),
      displayMedium: _ts(
        context: context,
        baseSize:  _baseTitle - 6,
        color: subFontLight,
      ),
      displaySmall: _ts(
        context: context,
        baseSize: _baseHeadline-4,
        weight: FontWeight.w700,
        color: fontLight,
      ),
      headlineMedium: _ts(
        context: context,
        baseSize: _baseHeadline + 2,
        weight: FontWeight.w600,
        color: fontLight,
      ),
      headlineSmall: _ts(
        context: context,
        baseSize: _baseHeadline-2,//24
        weight: FontWeight.w600,
        color: fontLight,
      ),
      titleLarge: _ts(
        context: context,
        baseSize: _baseTitle + 2,
        weight: FontWeight.w600,
        color: fontLight,
      ),
      titleMedium: _ts(
        context: context,
        baseSize: _baseTitle,
        weight: FontWeight.w600,
        color: fontLight,
      ),
      titleSmall: _ts(
        context: context,
        baseSize: _baseTitle - 4,// 16.0
        color: fontLight,
      ),
      bodyLarge: _ts(context: context, baseSize: _baseBody, color: fontLight),
      bodyMedium: _ts(
        context: context,
        baseSize: _baseBody - 3,// 16.0
        color: subFontLight,
      ),
      bodySmall: _ts(
        context: context,
        baseSize: _baseBody - 4,
        color: subFontLight,
      ),
      labelLarge: _ts(
        context: context,
        baseSize: _baseBody - 2,
        weight: FontWeight.w500,
        color: fontLight,
      ),
      labelMedium: _ts(
        context: context,
        baseSize: _baseBody - 6,
        color: fontLight,
      ),
      labelSmall: _ts(
        context: context,
        baseSize: _baseBody - 8,
        color: fontLight,
      ),
    ),
  );

  static ThemeData dark(BuildContext context) => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    colorScheme: const ColorScheme.dark(
      surface: bgDark,
      onSurface: darkIconBackgroundColor,
      primary: fontDark,
      onPrimary: subFontDark,
      primaryContainer: containerDark,
      onPrimaryContainer: forGroundDark,
      outline: outlineDark,
      outlineVariant: forGroundOutlineDark,
    ),
    scaffoldBackgroundColor: bgDark,
    textTheme: TextTheme(
      displayLarge: _ts(
        context: context,
        baseSize: 36,
        weight: FontWeight.bold,
        color: fontDark,
      ),
      displayMedium: _ts(
        context: context,
        baseSize: _baseTitle - 6,
        color: subFontDark,
      ),
      displaySmall: _ts(
        context: context,
        baseSize: _baseHeadline-4,
        weight: FontWeight.w600,
        color: fontDark,
      ),
      headlineMedium: _ts(
        context: context,
        baseSize: _baseHeadline + 2,
        weight: FontWeight.w600,
        color: fontDark,
      ),
      headlineSmall: _ts(
        context: context,
        baseSize: _baseHeadline-2,//24
        weight: FontWeight.w600,
        color: fontDark,
      ),
      titleLarge: _ts(
        context: context,
        baseSize: _baseTitle + 2,
        weight: FontWeight.w600,
        color: fontDark,
      ),
      titleMedium: _ts(
        context: context,
        baseSize: _baseTitle,
        weight: FontWeight.w600,
        color: fontDark,
      ),
      titleSmall: _ts(
        context: context,
        baseSize: _baseTitle - 4,// 16.0
        color: fontDark,
      ),
      bodyLarge: _ts(context: context, baseSize: _baseBody, color: fontDark),
      bodyMedium: _ts(
        context: context,
        baseSize: _baseBody - 3,// 16.0
        color: subFontDark,
      ),
      bodySmall: _ts(
        context: context,
        baseSize: _baseBody - 4,
        color: subFontDark,
      ),
      labelLarge: _ts(
        context: context,
        baseSize: _baseBody - 2,
        weight: FontWeight.w500,
        color: fontDark,
      ),
      labelMedium: _ts(
        context: context,
        baseSize: _baseBody - 6,
        color: fontDark,
      ),
      labelSmall: _ts(
        context: context,
        baseSize: _baseBody - 8,
        color: fontDark,
      ),
    ),  );
}
