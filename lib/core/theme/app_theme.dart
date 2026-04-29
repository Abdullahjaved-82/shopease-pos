import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_system/features/settings/application/app_prefs_notifier.dart';

const pkGreen = Color(0xFF01411C);
const pkGreenLight = Color(0xFF015A27);
const pkGold = Color(0xFFF1C40F);
const pkGoldSoft = Color(0xFFFFF8DC);
const pkWhite = Color(0xFFFFFFFF);
const pkSurface = Color(0xFFF7F9F7);
const pkRed = Color(0xFFC0392B);
const pkMuted = Color(0xFF5A6A5A);

const _pkSidebarDark = Color(0xFF001A0A);
const _pkSurfaceDark = Color(0xFF0D1F12);
const _pkGoldDark = Color(0xFFB8860B);

ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  final colorScheme = const ColorScheme.light(
    primary: pkGreen,
    secondary: pkGold,
    error: pkRed,
    surface: pkWhite,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: pkSurface,
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: pkMuted,
      displayColor: pkGreen,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: pkGreen,
      foregroundColor: pkWhite,
      elevation: 0,
      centerTitle: false,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: pkGreen,
      selectedIconTheme: const IconThemeData(color: pkGold),
      unselectedIconTheme: const IconThemeData(color: Colors.white70),
      selectedLabelTextStyle: const TextStyle(color: pkGold, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
      indicatorColor: pkGold.withOpacity(0.2),
    ),
    cardTheme: CardThemeData(
      color: pkWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: pkGreen.withOpacity(0.15), width: 0.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: pkGreen,
        foregroundColor: pkWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: pkGreen,
        side: const BorderSide(color: pkGreen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pkWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: pkGreen.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: pkGreen),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: pkGoldSoft,
      disabledColor: pkGoldSoft.withOpacity(0.7),
      selectedColor: pkGold.withOpacity(0.2),
      secondarySelectedColor: pkGold.withOpacity(0.24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      labelStyle: const TextStyle(color: _pkGoldDark, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: _pkGoldDark, fontWeight: FontWeight.w600),
      brightness: Brightness.light,
    ),
    dividerColor: pkGreen.withOpacity(0.12),
    badgeTheme: const BadgeThemeData(
      backgroundColor: pkRed,
      textColor: pkWhite,
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final colorScheme = const ColorScheme.dark(
    primary: pkGold,
    secondary: pkGreen,
    error: pkRed,
    surface: _pkSurfaceDark,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: _pkSurfaceDark,
    textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFFE8F2EA),
      displayColor: pkGold,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _pkSidebarDark,
      foregroundColor: pkWhite,
      elevation: 0,
      centerTitle: false,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: _pkSidebarDark,
      selectedIconTheme: const IconThemeData(color: pkGold),
      unselectedIconTheme: const IconThemeData(color: Colors.white70),
      selectedLabelTextStyle: const TextStyle(color: pkGold, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
      indicatorColor: pkGold.withOpacity(0.2),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF122A1A),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: pkGold.withOpacity(0.18), width: 0.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: pkGold,
        foregroundColor: _pkSidebarDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: pkGold,
        side: const BorderSide(color: pkGold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF142C1D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: pkGold.withOpacity(0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: pkGold),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF213A2A),
      disabledColor: const Color(0xFF2B4A37),
      selectedColor: pkGold.withOpacity(0.2),
      secondarySelectedColor: pkGold.withOpacity(0.24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      labelStyle: const TextStyle(color: pkGold, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: pkGold, fontWeight: FontWeight.w600),
      brightness: Brightness.dark,
    ),
    dividerColor: pkGold.withOpacity(0.18),
    badgeTheme: const BadgeThemeData(
      backgroundColor: pkRed,
      textColor: pkWhite,
    ),
  );
}

final appThemeProvider = Provider<ThemeData>((ref) {
  final prefsAsync = ref.watch(appPrefsNotifierProvider);
  final mode = prefsAsync.value?.themeMode ?? ThemeMode.system;

  if (mode == ThemeMode.dark) {
    return buildDarkTheme();
  }

  if (mode == ThemeMode.light) {
    return buildLightTheme();
  }

  final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  return brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme();
});

bool containsUrdu(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);

class UrduAwareText extends StatelessWidget {
  const UrduAwareText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = containsUrdu(text)
        ? GoogleFonts.notoNastaliqUrdu(textStyle: style)
        : style;
    return Text(
      text,
      style: effectiveStyle,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}


