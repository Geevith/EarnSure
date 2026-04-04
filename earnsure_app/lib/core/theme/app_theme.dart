import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Colour Palette ──────────────────────────────────────────────────────────
  static const Color backgroundDark  = Color(0xFF080C10);
  static const Color surfaceDark     = Color(0xFF0F1620);
  static const Color surfaceCard     = Color(0xFF141E2B);
  static const Color surfaceElevated = Color(0xFF1A2535);

  static const Color neonEmerald     = Color(0xFF00E87A);
  static const Color neonEmeraldDim  = Color(0xFF00C464);
  static const Color neonEmeraldGlow = Color(0x3300E87A);

  static const Color neonAmber       = Color(0xFFFFB020);
  static const Color neonRed         = Color(0xFFFF4B55);
  static const Color neonBlue        = Color(0xFF4D9FFF);

  static const Color textPrimary     = Color(0xFFF0F4F8);
  static const Color textSecondary   = Color(0xFFB0BEC5);
  static const Color textMuted       = Color(0xFF546E7A);

  static const Color borderSubtle    = Color(0xFF1E2D3D);
  static const Color borderBright    = Color(0xFF2A3F55);

  // ── Typography ──────────────────────────────────────────────────────────────
  static TextStyle get headingLarge => GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.2,
      );

  static TextStyle get headingMedium => GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        height: 1.3,
      );

  static TextStyle get headingSmall => GoogleFonts.spaceGrotesk(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textMuted,
        height: 1.4,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textMuted,
        letterSpacing: 0.8,
      );

  static TextStyle get monoSmall => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: neonEmerald,
        height: 1.6,
      );

  static TextStyle get monoBold => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: neonEmerald,
      );

  // ── Decorations ─────────────────────────────────────────────────────────────
  static BoxDecoration glassCard({
    Color borderColor = borderSubtle,
    double borderWidth = 1.0,
    double borderRadius = 20,
  }) =>
      BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration glowCard({
    Color glowColor = neonEmeraldGlow,
    double borderRadius = 20,
  }) =>
      BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: neonEmerald.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 32,
            spreadRadius: -4,
          ),
          const BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      );

  static List<BoxShadow> neonGlow(Color color, {double intensity = 1.0}) => [
        BoxShadow(
          color: color.withOpacity(0.35 * intensity),
          blurRadius: 20 * intensity,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: color.withOpacity(0.15 * intensity),
          blurRadius: 40 * intensity,
          spreadRadius: -8,
        ),
      ];

  // ── Theme Data ───────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundDark,
        colorScheme: const ColorScheme.dark(
          primary:   neonEmerald,
          secondary: neonBlue,
          surface:   surfaceDark,
          error:     neonRed,
          onPrimary:  backgroundDark,
          onSurface:  textPrimary,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          bodyMedium:    bodyMedium,
          bodySmall:     bodySmall,
          labelMedium:   labelMedium,
          headlineMedium: headingMedium,
          headlineSmall:  headingSmall,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: backgroundDark,
          elevation:       0,
          centerTitle:     false,
          titleTextStyle:  headingSmall,
          iconTheme: const IconThemeData(color: textPrimary),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
          ),
        ),
        cardTheme: CardThemeData(
          color:       surfaceCard,
          elevation:   0,
          shape:       RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: borderSubtle, width: 1),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor:    surfaceDark,
          modalBackgroundColor: surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled:      true,
          fillColor:   surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderSubtle, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: neonEmerald, width: 1.5),
          ),
          labelStyle: bodySmall,
          hintStyle:  bodySmall,
        ),
        dividerTheme: const DividerThemeData(
          color: borderSubtle,
          thickness: 1,
          space: 0,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor:  surfaceElevated,
          contentTextStyle: bodyMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
}