import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeManager extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  ThemeData get themeData {
    const primaryColor = Color(0xFF6C5CE7);
    const accentColor = Color(0xFF00B894);
    const errorColor = Color(0xFFD63031);

    if (_isDarkMode) {
      return ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.dark().textTheme,
        ),
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: accentColor,
          error: errorColor,
        ),
      );
    } else {
      return ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.light().textTheme,
        ),
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: primaryColor,
          secondary: accentColor,
          error: errorColor,
        ),
      );
    }
  }
}
