import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Dark Palette (Auth / Splash – unchanged) ────────────────────────────────
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

  // ── Light Fintech Palette (Dashboard & new screens) ────────────────────────
  /// Off-white scaffold background
  static const Color ltBackground    = Color(0xFFF2F4F8);
  /// Card / panel surfaces
  static const Color ltSurface       = Color(0xFFFFFFFF);
  /// Subtle card border
  static const Color ltBorder        = Color(0xFFE2E8F0);
  /// Stark black — AppBars, section headers
  static const Color ltHeaderBlack   = Color(0xFF0A0A0A);
  /// Secondary header / dark card bg
  static const Color ltHeaderDark    = Color(0xFF111827);
  /// Primary action — Deep Blue
  static const Color ltPrimary       = Color(0xFF1A56DB);
  static const Color ltPrimaryLight  = Color(0xFFEBF1FF);
  /// Success — Emerald Green (active policy, confirmed states)
  static const Color ltSuccess       = Color(0xFF059669);
  static const Color ltSuccessLight  = Color(0xFFD1FAE5);
  /// Warning / alert — Red/Orange
  static const Color ltDanger        = Color(0xFFDC2626);
  static const Color ltDangerLight   = Color(0xFFFEE2E2);
  static const Color ltWarning       = Color(0xFFD97706);
  static const Color ltWarningLight  = Color(0xFFFEF3C7);
  /// Purple for Platform Outage trigger
  static const Color ltPurple        = Color(0xFF7C3AED);
  static const Color ltPurpleLight   = Color(0xFFEDE9FE);
  /// Teal for Monsoon trigger
  static const Color ltTeal          = Color(0xFF0891B2);
  static const Color ltTealLight     = Color(0xFFCFFAFE);

  /// Light-theme text colours
  static const Color ltTextPrimary   = Color(0xFF0F172A);
  static const Color ltTextSecondary = Color(0xFF475569);
  static const Color ltTextMuted     = Color(0xFF94A3B8);

  // ── Dark-theme Typography ───────────────────────────────────────────────────
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

  // ── Light Fintech Typography (Inter, heavy weights for numbers) ─────────────
  static TextStyle get ltDisplayNumber => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: ltTextPrimary,
        height: 1.1,
      );

  static TextStyle get ltHeadingLarge => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: ltTextPrimary,
        height: 1.25,
      );

  static TextStyle get ltHeadingMedium => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ltTextPrimary,
        height: 1.3,
      );

  static TextStyle get ltHeadingSmall => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: ltTextPrimary,
        height: 1.4,
      );

  static TextStyle get ltBody => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: ltTextSecondary,
        height: 1.5,
      );

  static TextStyle get ltBodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: ltTextMuted,
        height: 1.4,
      );

  static TextStyle get ltLabel => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: ltTextMuted,
        letterSpacing: 0.6,
      );

  static TextStyle get ltNumberLarge => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: ltTextPrimary,
        height: 1.0,
      );

  static TextStyle get ltNumberMedium => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ltTextPrimary,
        height: 1.0,
      );

  // ── Dark Decorations ─────────────────────────────────────────────────────────
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

  // ── Light Fintech Decorations ───────────────────────────────────────────────
  static BoxDecoration ltCard({
    Color? borderColor,
    double borderRadius = 20,
    List<BoxShadow>? shadow,
  }) =>
      BoxDecoration(
        color: ltSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? ltBorder, width: 1),
        boxShadow: shadow ??
            const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
      );

  static BoxDecoration ltSuccessCard({double borderRadius = 20}) =>
      BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF047857)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3305966900),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration ltHeaderCard({double borderRadius = 0}) =>
      BoxDecoration(
        color: ltHeaderBlack,
        borderRadius: BorderRadius.circular(borderRadius),
      );

  // ── Dark ThemeData (Auth / Splash) ───────────────────────────────────────────
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

  // ── Light Fintech ThemeData (Dashboard & new screens) ───────────────────────
  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: ltBackground,
        colorScheme: ColorScheme.light(
          primary:    ltPrimary,
          secondary:  ltSuccess,
          surface:    ltSurface,
          error:      ltDanger,
          onPrimary:  Colors.white,
          onSurface:  ltTextPrimary,
          onSecondary: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
          bodyLarge:      ltBody,
          bodyMedium:     ltBody,
          bodySmall:      ltBodySmall,
          labelMedium:    ltLabel,
          headlineMedium: ltHeadingMedium,
          headlineSmall:  ltHeadingSmall,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: ltHeaderBlack,
          elevation:       0,
          centerTitle:     false,
          titleTextStyle:  ltHeadingSmall.copyWith(color: Colors.white),
          iconTheme: const IconThemeData(color: Colors.white),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor:        Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        cardTheme: CardThemeData(
          color:     ltSurface,
          elevation: 0,
          shape:     RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: ltBorder, width: 1),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor:    Color(0xFF0F1620),
          modalBackgroundColor: Color(0xFF0F1620),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: ltBorder,
          thickness: 1,
          space: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ltPrimary,
            foregroundColor: Colors.white,
            elevation:       0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: ltHeadingSmall.copyWith(fontSize: 15, color: Colors.white),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor:  ltHeaderDark,
          contentTextStyle: ltBody.copyWith(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
}