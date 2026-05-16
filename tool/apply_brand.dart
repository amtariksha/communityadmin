// apply_brand.dart — white-label brand applicator / code generator.
//
// Usage:
//   dart run tool/apply_brand.dart <slug> [--no-icons]
//
// Reads `branding/<slug>/brand.json` and:
//   1. generates `lib/config/brand_config.dart`,
//   2. copies branding/<slug>/{logo,splash,app_icon}.png into
//      `assets/branding/`,
//   3. patches the native launcher name + package id (Android + iOS),
//   4. writes flutter_launcher_icons.yaml + flutter_native_splash.yaml
//      and runs them (skip step 4's generation with --no-icons).
//
// Run before `flutter build` for a per-society store release. The
// generated brand_config.dart is committed with the `default` brand
// so the repo builds out of the box.

import 'dart:convert';
import 'dart:io';

void _fail(String msg) {
  stderr.writeln('✗ $msg');
  exit(1);
}

/// Read a file, apply [replace], write it back. Reports a no-op clearly.
void _patch(String path, String label, String Function(String) replace) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('  ! skipped $label — $path not found');
    return;
  }
  final before = file.readAsStringSync();
  final after = replace(before);
  if (before == after) {
    stdout.writeln('  = $label already current');
    return;
  }
  file.writeAsStringSync(after);
  stdout.writeln('  ✓ $label patched');
}

Future<void> main(List<String> args) async {
  final flags = args.where((a) => a.startsWith('--')).toSet();
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final noIcons = flags.contains('--no-icons');
  final slug = positional.isEmpty ? 'default' : positional.first;

  final jsonFile = File('branding/$slug/brand.json');
  if (!jsonFile.existsSync()) {
    _fail('branding/$slug/brand.json not found.');
  }

  final Map<String, dynamic> brand =
      jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;

  for (final k in const [
    'slug',
    'appName',
    'applicationId',
    'iosBundleId',
    'apiBaseUrl',
    'colors',
  ]) {
    if (!brand.containsKey(k)) _fail('brand.json missing key: $k');
  }

  final appName = brand['appName'] as String;
  final applicationId = brand['applicationId'] as String;
  final iosBundleId = brand['iosBundleId'] as String;
  final apiBaseUrl = brand['apiBaseUrl'] as String;
  final colors = brand['colors'] as Map<String, dynamic>;

  String hex(String key) {
    final v = colors[key];
    if (v is! String || !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v)) {
      _fail('colors.$key must be a 6-digit hex string (got: $v)');
    }
    return (v as String).toUpperCase();
  }

  final primary = hex('primary');
  final primaryVariant = hex('primaryVariant');
  final primarySoftTint = hex('primarySoftTint');
  final brandSurfaceAccent = hex('brandSurfaceAccent');
  final brandMutedText = hex('brandMutedText');
  final secondary = hex('secondary');

  stdout.writeln('▶ Applying brand "$slug" ($appName)');

  // 1. Generate lib/config/brand_config.dart -------------------------------
  final escapedName = appName.replaceAll("'", r"\'");
  File('lib/config/brand_config.dart').writeAsStringSync('''// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Produced by `tool/apply_brand.dart` from `branding/<slug>/brand.json`.
// Regenerate with:  dart run tool/apply_brand.dart <slug>
//
// Active brand: $slug
import 'package:flutter/material.dart';

/// Build-time white-label brand configuration.
///
/// Holds the values baked into the binary: theme palette, launcher /
/// wordmark name, target backend, and the bundled logo asset. Runtime
/// per-society branding (a society's own logo / name fetched from the
/// backend) is layered on top of this — see `BrandLogo`.
class BrandConfig {
  BrandConfig._();

  /// Brand folder under `branding/` this build was generated from.
  static const String slug = '$slug';

  /// Launcher label + in-app wordmark fallback.
  static const String appName = '$escapedName';

  /// Backend instance this build targets.
  static const String apiBaseUrl = '$apiBaseUrl';

  /// Bundled logo — shown on splash / login and as the runtime fallback
  /// when a society has no `logo_url`.
  static const String logoAsset = 'assets/branding/logo.png';

  // --- Brand palette (build-time). Status / neutral colours live in
  //     theme.dart and are not brand-variable. ---
  static const Color primaryColor = Color(0xFF$primary);
  static const Color primaryColorVariant = Color(0xFF$primaryVariant);
  static const Color primarySoftTint = Color(0xFF$primarySoftTint);
  static const Color brandSurfaceAccent = Color(0xFF$brandSurfaceAccent);
  static const Color brandMutedText = Color(0xFF$brandMutedText);
  static const Color secondaryColor = Color(0xFF$secondary);
}
''');
  stdout.writeln('  ✓ lib/config/brand_config.dart generated');

  // 2. Copy brand assets ---------------------------------------------------
  Directory('assets/branding').createSync(recursive: true);
  for (final name in const ['logo.png', 'splash.png', 'app_icon.png']) {
    final src = File('branding/$slug/$name');
    if (!src.existsSync()) {
      _fail('branding/$slug/$name missing — required asset.');
    }
    src.copySync('assets/branding/$name');
  }
  stdout.writeln('  ✓ assets/branding/ updated');

  // 3. Patch native launcher name + package id -----------------------------
  _patch(
    'android/app/src/main/AndroidManifest.xml',
    'Android launcher label',
    (s) => s.replaceFirst(
      RegExp(r'android:label="[^"]*"'),
      'android:label="$appName"',
    ),
  );
  _patch(
    'android/app/build.gradle.kts',
    'Android applicationId',
    (s) => s.replaceFirst(
      RegExp(r'applicationId = "[^"]*"'),
      'applicationId = "$applicationId"',
    ),
  );
  _patch(
    'ios/Runner/Info.plist',
    'iOS CFBundleDisplayName',
    (s) => s.replaceFirstMapped(
      RegExp(
        r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
      ),
      (m) => '${m[1]}$appName${m[2]}',
    ),
  );
  _patch(
    'ios/Runner.xcodeproj/project.pbxproj',
    'iOS bundle identifier',
    // The RunnerTests target derives its id as "<app id>.RunnerTests" —
    // preserve that suffix so the test target stays distinct.
    (s) => s.replaceAllMapped(
      RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]*);'),
      (m) {
        final current = m[1]!;
        final suffix = current.endsWith('.RunnerTests') ? '.RunnerTests' : '';
        return 'PRODUCT_BUNDLE_IDENTIFIER = $iosBundleId$suffix;';
      },
    ),
  );

  // 4. Launcher icons + native splash --------------------------------------
  File('flutter_launcher_icons.yaml').writeAsStringSync('''# GENERATED by tool/apply_brand.dart — brand: $slug
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/branding/app_icon.png"
  remove_alpha_ios: true
''');
  File('flutter_native_splash.yaml').writeAsStringSync('''# GENERATED by tool/apply_brand.dart — brand: $slug
flutter_native_splash:
  color: "#FFFFFF"
  image: assets/branding/splash.png
  android_12:
    image: assets/branding/splash.png
    color: "#FFFFFF"
''');
  stdout.writeln('  ✓ icon / splash configs written');

  if (noIcons) {
    stdout.writeln('  — skipping icon / splash generation (--no-icons)');
  } else {
    stdout.writeln('  ▶ generating launcher icons + splash …');
    for (final cmd in const [
      ['flutter', 'pub', 'get'],
      ['dart', 'run', 'flutter_launcher_icons'],
      ['dart', 'run', 'flutter_native_splash:create'],
    ]) {
      final r = Process.runSync(cmd.first, cmd.sublist(1));
      if (r.exitCode != 0) {
        stderr.writeln('  ! "${cmd.join(' ')}" failed:\n${r.stderr}');
        stderr.writeln(
          '  ! re-run with the tools installed, or pass --no-icons.',
        );
        exit(1);
      }
    }
    stdout.writeln('  ✓ launcher icons + splash generated');
  }

  stdout.writeln('✓ Brand "$slug" applied. Next: flutter build <target>.');
}
