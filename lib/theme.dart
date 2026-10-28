import 'package:flutter/material.dart';

/// The Logbook look: warm paper, serif reading type, a QSL-card red.
abstract final class Logbook {
  static const paper = Color(0xFFF6F1E7);
  static const paperDeep = Color(0xFFEFE8DA);
  static const rule = Color(0xFFE1D8C5);
  static const ink = Color(0xFF2B2620);
  static const inkSoft = Color(0xFF6F6656);
  static const inkFaint = Color(0xFF8A7F6C);
  static const stampRed = Color(0xFFB0482C);

  static const serif = 'SourceSerif4';
  static const sans = 'Inter';
  static const mono = 'JetBrainsMono';

  /// Variable fonts need their weight set as an axis as well as a FontWeight.
  static TextStyle _style(String family, double size, int weight, Color color, {double? height}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: [FontVariation('wght', weight.toDouble())],
        color: color,
        height: height,
      );

  /// Message bodies in the readable view.
  static TextStyle get body => _style(serif, 16, 400, ink, height: 1.5);

  /// Message bodies as sent.
  static TextStyle get asSent => _style(mono, 12.5, 400, ink, height: 1.45);

  /// Callsign stamps.
  static TextStyle get stamp => _style(sans, 10, 700, stampRed);

  /// Small section labels (NEW, EARLIER).
  static TextStyle get sectionLabel =>
      _style(sans, 11, 600, stampRed).copyWith(letterSpacing: 1.5);

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: stampRed,
      primary: stampRed,
      surface: paper,
      onSurface: ink,
    );
    final text = TextTheme(
      displaySmall: _style(serif, 30, 700, ink),
      headlineSmall: _style(serif, 22, 700, ink, height: 1.25),
      titleLarge: _style(serif, 20, 600, ink),
      titleMedium: _style(serif, 16, 400, ink, height: 1.3),
      titleSmall: _style(sans, 13, 600, ink),
      bodyLarge: _style(serif, 16, 400, ink, height: 1.5),
      bodyMedium: _style(sans, 14, 400, ink),
      bodySmall: _style(sans, 12, 400, inkFaint),
      labelLarge: _style(sans, 14, 600, stampRed),
      labelMedium: _style(sans, 12, 500, inkSoft),
      labelSmall: _style(sans, 11, 500, inkFaint),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      textTheme: text,
      dividerTheme: const DividerThemeData(color: rule, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.headlineSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: _style(sans, 14, 400, inkSoft),
        floatingLabelStyle: _style(sans, 13, 500, stampRed),
        hintStyle: _style(sans, 14, 400, inkFaint),
        helperStyle: _style(sans, 12, 400, inkSoft),
        helperMaxLines: 3,
        errorMaxLines: 3,
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: rule)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: stampRed, width: 1.5)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paperDeep,
        indicatorColor: stampRed.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(_style(sans, 11, 500, inkFaint)),
      ),
    );
  }
}
