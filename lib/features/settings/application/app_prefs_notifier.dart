import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'app_prefs_notifier.g.dart';

const _kThemeMode = 'app_theme_mode';
const _kLocale = 'app_locale';
const _kFontScale = 'app_font_scale';

class AppPrefs {
  const AppPrefs({required this.themeMode, required this.localeCode, required this.fontScale});
  final ThemeMode themeMode;
  final String? localeCode;
  final double fontScale;
}

@riverpod
class AppPrefsNotifier extends _$AppPrefsNotifier {
  late SharedPreferences _prefs;

  @override
  Future<AppPrefs> build() async {
    _prefs = await SharedPreferences.getInstance();
    return AppPrefs(
      themeMode: ThemeMode.values[_prefs.getInt(_kThemeMode) ?? ThemeMode.system.index],
      localeCode: _prefs.getString(_kLocale),
      fontScale: _prefs.getDouble(_kFontScale) ?? 1.0,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(AppPrefs(themeMode: mode, localeCode: state.value?.localeCode, fontScale: state.value?.fontScale ?? 1));
    await _prefs.setInt(_kThemeMode, mode.index);
  }

  Future<void> setLocale(String? code) async {
    state = AsyncData(AppPrefs(themeMode: state.value?.themeMode ?? ThemeMode.system, localeCode: code, fontScale: state.value?.fontScale ?? 1));
    if (code == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, code);
    }
  }

  Future<void> setFontScale(double scale) async {
    state = AsyncData(AppPrefs(themeMode: state.value?.themeMode ?? ThemeMode.system, localeCode: state.value?.localeCode, fontScale: scale));
    await _prefs.setDouble(_kFontScale, scale);
  }
}

