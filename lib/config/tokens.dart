import 'package:flutter/material.dart';

/// Design tokens for the **ezegate Admin** build — kept in lockstep
/// with the resident app's tokens (`communityuser/lib/config/tokens.dart`).
///
/// Single source of truth for spacing, radius, elevation, and shadow
/// values referenced by screens. Never hardcode magic numbers in screen
/// code — pull from here so the design language stays consistent and
/// future re-skin work edits one file.
///
/// Colour and typography tokens live on [AppTheme] in `theme.dart` —
/// they're already keyed off the Flutter [ThemeData], so screens that
/// want a primary colour read from `Theme.of(context).colorScheme.primary`
/// (preferred) or `AppTheme.primaryColor` (legacy direct access).
class AppSpacing {
  /// 4 px — finest grain, only for tight icon padding.
  static const double xs = 4;

  /// 8 px — default chip / inline gap.
  static const double sm = 8;

  /// 12 px — list-row internal padding.
  static const double md = 12;

  /// 16 px — card internal padding, default vertical rhythm.
  static const double lg = 16;

  /// 20 px — screen-edge gutter. Default page padding.
  static const double xl = 20;

  /// 24 px — looser sections.
  static const double xxl = 24;

  /// 32 px — section break.
  static const double xxxl = 32;

  AppSpacing._();
}

/// Border radii. Match Figma frame radii observed across LoginScreen,
/// HomeScreen, and bottom-sheet patterns.
class AppRadius {
  /// 6 px — small chip / inline tag.
  static const double xs = 6;

  /// 10 px — phone input + primary CTA.
  static const double sm = 10;

  /// 12 px — activity rows, switcher pill.
  static const double md = 12;

  /// 14 px — Quick Action tiles.
  static const double lg = 14;

  /// 16 px — segmented switcher container, large card.
  static const double xl = 16;

  /// 18 px — circular icon background (e.g. notification bell).
  static const double xxl = 18;

  /// 20 px — hero card + bottom-sheet top corners.
  static const double xxxl = 20;

  /// Pill — status badges, fully-rounded buttons.
  static const double pill = 999;

  AppRadius._();
}

/// Elevation tokens. Most cards in Figma are flat on off-white fills.
class AppElevation {
  static const double none = 0;
  static const double soft = 1;
  static const double raised = 2;
  static const double overlay = 4;

  /// Soft shadow used on the segmented switcher selected pill in Figma.
  /// `box-shadow: 0px 1px 1px rgba(0,0,0,0.05)`.
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x0D000000), // rgba(0,0,0,0.05)
      offset: Offset(0, 1),
      blurRadius: 1,
    ),
  ];

  AppElevation._();
}

/// Animation durations. Keep transitions short.
class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// Splash screen total visible duration before routing.
  static const Duration splash = Duration(milliseconds: 1500);

  AppDuration._();
}
