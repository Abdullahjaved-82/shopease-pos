import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  useMaterial3: true,
  scaffoldBackgroundColor: Colors.grey[50],
  appBarTheme: const AppBarTheme(centerTitle: true),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
  ),
);

