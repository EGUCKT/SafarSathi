// SafarSathi — App Theme
// iOS-style glassmorphism, smooth curves, dark/light adaptive
// Follows device theme automatically

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SafarSathiTheme {
  // Brand colors — Switched to Premium Pinkish Tone
  static const Color brandPink     = Color(0xFFFF2D55); // Vibrant iOS Pink
  static const Color brandSaffron  = brandPink; // Alias to fix build errors while keeping pink tone
  static const Color brandDeep     = Color(0xFF1A1A2E); // deep navy — trust
  static const Color brandSafe     = Color(0xFF2ECC71); // safe green
  static const Color brandWarning  = Color(0xFFFF85A1); // Soft Pink/Amber fallback
  static const Color brandDanger   = Color(0xFFFF3B30); // danger red
  static const Color brandAccent   = Color(0xFF5E5CE6); // indigo accent

  // Glass surface colors
  static const Color glassLight    = Color(0xCCFFFFFF); // 80% white
  static const Color glassDark     = Color(0xCC1A1A2E); // 80% deep navy

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary:    brandPink,
        secondary:  brandDeep,
        surface:    const Color(0xFFF8F8F8),
        error:      brandDanger,
      ),
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        displayLarge: GoogleFonts.dmSans(
          fontSize: 32, fontWeight: FontWeight.w300, letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18, fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w400, height: 1.5,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w400, height: 1.5,
        ),
        labelSmall: GoogleFonts.dmSans(
          fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: brandDeep),
      ),
      scaffoldBackgroundColor: const Color(0xFFF2F2F7), // iOS system background
      cardTheme: CardThemeData(
        color: glassLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      extensions: [SafarSathiColors.light()],
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary:    brandPink,
        secondary:  const Color(0xFFE8E8F0),
        surface:    const Color(0xFF1C1C1E),
        error:      brandDanger,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.dmSans(
          fontSize: 32, fontWeight: FontWeight.w300,
          letterSpacing: -0.5, color: Colors.white,
        ),
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 22, fontWeight: FontWeight.w500,
          letterSpacing: -0.3, color: Colors.white,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w400,
          height: 1.5, color: const Color(0xFFEAEAEA),
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w400,
          height: 1.5, color: const Color(0xFFAAAAAA),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      scaffoldBackgroundColor: const Color(0xFF000000), // iOS true black dark
      cardTheme: CardThemeData(
        color: glassDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      extensions: [SafarSathiColors.dark()],
    );
  }
}

// Custom color extension for easy access anywhere
class SafarSathiColors extends ThemeExtension<SafarSathiColors> {
  final Color glass;
  final Color glassBorder;
  final Color cardBg;
  final Color safeColor;
  final Color warningColor;
  final Color dangerColor;
  final Color textMuted;
  final Color mapSafe;
  final Color mapModerate;
  final Color mapDanger;

  const SafarSathiColors({
    required this.glass,
    required this.glassBorder,
    required this.cardBg,
    required this.safeColor,
    required this.warningColor,
    required this.dangerColor,
    required this.textMuted,
    required this.mapSafe,
    required this.mapModerate,
    required this.mapDanger,
  });

  factory SafarSathiColors.light() => const SafarSathiColors(
    glass:         Color(0xCCFFFFFF),
    glassBorder:   Color(0x30FFFFFF),
    cardBg:        Color(0xFFFFFFFF),
    safeColor:     Color(0xFF2ECC71),
    warningColor:  Color(0xFFFF85A1),
    dangerColor:   Color(0xFFFF3B30),
    textMuted:     Color(0xFF8E8E93),
    mapSafe:       Color(0xFF2ECC71),
    mapModerate:   Color(0xFFFF85A1),
    mapDanger:     Color(0xFFFF3B30),
  );

  factory SafarSathiColors.dark() => const SafarSathiColors(
    glass:         Color(0xCC1C1C1E),
    glassBorder:   Color(0x20FFFFFF),
    cardBg:        Color(0xFF2C2C2E),
    safeColor:     Color(0xFF30D158),
    warningColor:  Color(0xFFFF85A1),
    dangerColor:   Color(0xFFFF3B30),
    textMuted:     Color(0xFF636366),
    mapSafe:       Color(0xFF30D158),
    mapModerate:   Color(0xFFFF85A1),
    mapDanger:     Color(0xFFFF3B30),
  );

  @override
  SafarSathiColors copyWith({
    Color? glass, Color? glassBorder, Color? cardBg,
    Color? safeColor, Color? warningColor, Color? dangerColor,
    Color? textMuted, Color? mapSafe, Color? mapModerate, Color? mapDanger,
  }) => SafarSathiColors(
    glass:         glass         ?? this.glass,
    glassBorder:   glassBorder   ?? this.glassBorder,
    cardBg:        cardBg        ?? this.cardBg,
    safeColor:     safeColor     ?? this.safeColor,
    warningColor:  warningColor  ?? this.warningColor,
    dangerColor:   dangerColor   ?? this.dangerColor,
    textMuted:     textMuted     ?? this.textMuted,
    mapSafe:       mapSafe       ?? this.mapSafe,
    mapModerate:   mapModerate   ?? this.mapModerate,
    mapDanger:     mapDanger     ?? this.mapDanger,
  );

  @override
  SafarSathiColors lerp(SafarSathiColors? other, double t) {
    if (other == null) return this;
    return SafarSathiColors(
      glass:         Color.lerp(glass, other.glass, t)!,
      glassBorder:   Color.lerp(glassBorder, other.glassBorder, t)!,
      cardBg:        Color.lerp(cardBg, other.cardBg, t)!,
      safeColor:     Color.lerp(safeColor, other.safeColor, t)!,
      warningColor:  Color.lerp(warningColor, other.warningColor, t)!,
      dangerColor:   Color.lerp(dangerColor, other.dangerColor, t)!,
      textMuted:     Color.lerp(textMuted, other.textMuted, t)!,
      mapSafe:       Color.lerp(mapSafe, other.mapSafe, t)!,
      mapModerate:   Color.lerp(mapModerate, other.mapModerate, t)!,
      mapDanger:     Color.lerp(mapDanger, other.mapDanger, t)!,
    );
  }
}

// Reusable glass card widget
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<SafarSathiColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.15 : 0.9), // Shine
                  colors.glass.withValues(alpha: isDark ? 0.4 : 0.85), // Base
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                  blurRadius: 10,
                  spreadRadius: -2,
                )
              ],
            ),
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Safety score color helper
Color safetyScoreColor(double score, BuildContext context) {
  final colors = Theme.of(context).extension<SafarSathiColors>()!;
  if (score >= 0.75) return colors.safeColor;
  if (score >= 0.55) return colors.safeColor.withAlpha(179);
  if (score >= 0.40) return colors.warningColor;
  if (score >= 0.25) return colors.warningColor.withAlpha(204);
  return colors.dangerColor;
}

String safetyScoreLabel(double score) {
  if (score >= 0.75) return 'Very Safe';
  if (score >= 0.55) return 'Safe';
  if (score >= 0.40) return 'Moderate';
  if (score >= 0.25) return 'Caution';
  return 'Avoid';
}
