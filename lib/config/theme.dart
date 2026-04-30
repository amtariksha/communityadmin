import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:community_admin/config/tokens.dart';

/// ezegate brand theme — light only.
///
/// Tokens kept in lockstep with the resident app
/// (`communityuser/lib/config/theme.dart`) — same Figma file, same
/// brand. Constants below preserve the existing public names
/// (`primaryColor`, `secondaryColor`, `successColor`, `warningColor`,
/// `errorColor`, `surfaceColor`) so admin screens that reference them
/// directly keep working without edits — only the values change from
/// indigo to ezegate orange.
///
/// **Light only.** The Figma spec has no dark frames; the white-label
/// brand is designed for a single bright look. `themeMode` is forced
/// to [ThemeMode.light] in `main.dart`.
class AppTheme {
  // -------------------------------------------------------------------------
  // Brand palette (ezegate — warm orange/amber)
  // -------------------------------------------------------------------------

  /// Primary brand colour — Figma "ezegate" wordmark, Send-OTP button,
  /// Home header band, Total Due amount, bottom-nav active label.
  static const Color primaryColor = Color(0xFFFFA300);

  /// Slightly cooler primary used on the segmented switcher selected
  /// pill. Use for variants where a touch more saturation reads
  /// better against `surfaceColor`.
  static const Color primaryColorVariant = Color(0xFFF5A623);

  /// Soft cream/peach tint used as a background for promo / CTA
  /// surfaces (e.g. Total Due hero card on HomeScreen).
  static const Color primarySoftTint = Color(0xFFFFEDCC);

  /// Brand surface accent — multi-option segmented switcher container
  /// background.
  static const Color brandSurfaceAccent = Color(0xFFFAEBDD);

  /// Warm-brown muted text used on the unselected segmented-switcher
  /// label.
  static const Color brandMutedText = Color(0xFF7A5828);

  /// Secondary accent — kept for legacy callers (login gradient etc.).
  static const Color secondaryColor = Color(0xFFF5A623);

  // -------------------------------------------------------------------------
  // Status colours (Figma HomeScreen activity rows)
  // -------------------------------------------------------------------------

  /// Paid / success — Figma "Paid" pill.
  static const Color successColor = Color(0xFF52B46B);

  /// Warning amber — kept distinct from primary brand because they
  /// look similar but read differently in context (warning = caution,
  /// primary = brand).
  static const Color warningColor = Color(0xFFF59E0B);

  /// Due / error — Figma "Due" pill.
  static const Color errorColor = Color(0xFFF24949);

  /// Vivid green used as the WhatsApp-OTP checkbox fill on Login.
  /// Distinct from [successColor]; reserve for the OTP-channel toggle.
  static const Color checkAccent = Color(0xFF1ACC4D);

  // -------------------------------------------------------------------------
  // Surface / text neutrals
  // -------------------------------------------------------------------------

  /// Card / input fill — Figma F9F9F9.
  static const Color surfaceColor = Color(0xFFF9F9F9);

  /// Page background.
  static const Color backgroundColor = Color(0xFFFFFFFF);

  /// Primary text — Figma `#222`. Prefer over `Colors.black87` so
  /// future re-skins shift one token.
  static const Color textPrimary = Color(0xFF222222);

  /// Bottom-nav inactive label — Figma `#1A1A1A` (slightly darker).
  static const Color navInactiveText = Color(0xFF1A1A1A);

  /// Secondary / muted text — Figma `#6D6D6D`.
  static const Color textSecondary = Color(0xFF6D6D6D);

  /// Hint / disabled text + dividers — Figma `#D0D0D0`.
  static const Color textHint = Color(0xFFD0D0D0);

  // -------------------------------------------------------------------------
  // Typography
  // -------------------------------------------------------------------------

  /// Inter — primary font for body / headings.
  static TextStyle inter({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? textPrimary,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Plus Jakarta Sans — secondary font for the segmented switcher
  /// chip labels. Use sparingly; Inter is the default everywhere else.
  static TextStyle plusJakarta({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? textPrimary,
        height: height,
        letterSpacing: letterSpacing,
      );

  // -------------------------------------------------------------------------
  // Light theme (only theme — dark mode dropped to match resident
  // ezegate fork; Figma has no dark frames)
  // -------------------------------------------------------------------------

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: primaryColorVariant,
        surface: backgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.none,
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontSize: 18,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.none,
        color: backgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: textHint.withValues(alpha: 0.5)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: AppElevation.none,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md + 2, // 14
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          side: const BorderSide(color: primaryColor),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textHint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: textHint.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: textHint.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryColor,
        selectionColor: Color(0x3FFFA300),
        selectionHandleColor: primaryColor,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: backgroundColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: navInactiveText,
        showUnselectedLabels: true,
        elevation: AppElevation.none,
        selectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: backgroundColor,
        indicatorColor: primarySoftTint,
        elevation: AppElevation.none,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: primaryColor,
            );
          }
          return GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: navInactiveText,
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: AppElevation.raised,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return checkAccent;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: textHint, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs - 2), // 4
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: textHint,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        elevation: AppElevation.overlay,
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxxl),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: textPrimary,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.overlay,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxxl),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: textSecondary,
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
