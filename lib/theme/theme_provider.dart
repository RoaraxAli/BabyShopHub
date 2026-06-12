import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _primaryKey = 'theme_primary_color';
  static const String _secondaryKey = 'theme_secondary_color';
  static const String _isDarkKey = 'theme_is_dark';

  // Default color values: Sleek pastel baby mint/coral
  Color _primaryColor = const Color(0xFFFF9EAA); // Soft Pink/Coral
  Color _secondaryColor = const Color(0xFFB0D9B1); // Soft Pastel Mint
  bool _isDarkMode = false;

  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  bool get isDarkMode => _isDarkMode;

  // Premium Preset Themes
  static final List<Map<String, dynamic>> presets = [
    {
      'name': 'Baby Blossom',
      'primary': const Color(0xFFFF9EAA),
      'secondary': const Color(0xFFB0D9B1),
    },
    {
      'name': 'Soft Blue Jay',
      'primary': const Color(0xFF96B6C5),
      'secondary': const Color(0xFFADC4CE),
    },
    {
      'name': 'Sweet Lavender',
      'primary': const Color(0xFFD0BFFF),
      'secondary': const Color(0xFFE8A0BF),
    },
    {
      'name': 'Sunshine Honey',
      'primary': const Color(0xFFFFD966),
      'secondary': const Color(0xFFF4B183),
    },
  ];

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final primaryHex = prefs.getInt(_primaryKey);
    final secondaryHex = prefs.getInt(_secondaryKey);
    _isDarkMode = prefs.getBool(_isDarkKey) ?? false;

    if (primaryHex != null) {
      _primaryColor = Color(primaryHex);
    }
    if (secondaryHex != null) {
      _secondaryColor = Color(secondaryHex);
    }
    notifyListeners();
  }

  Future<void> updateCustomTheme(Color primary, Color secondary) async {
    _primaryColor = primary;
    _secondaryColor = secondary;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_primaryKey, primary.value);
    await prefs.setInt(_secondaryKey, secondary.value);
  }

  Future<void> setPreset(int index) async {
    if (index >= 0 && index < presets.length) {
      final preset = presets[index];
      await updateCustomTheme(preset['primary'] as Color, preset['secondary'] as Color);
    }
  }

  Future<void> toggleDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDarkKey, value);
  }

  ThemeData get themeData {
    final colorScheme = ColorScheme(
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      primary: _primaryColor,
      onPrimary: Colors.white,
      secondary: _secondaryColor,
      onSecondary: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
      background: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFFDFBF7), // Cream white background
      onBackground: _isDarkMode ? const Color(0xFFE5E5E5) : const Color(0xFF3C3633),
      surface: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      onSurface: _isDarkMode ? const Color(0xFFE5E5E5) : const Color(0xFF3C3633),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      fontFamily: 'Outfit', // High quality premium typography
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onBackground),
        titleTextStyle: TextStyle(
          color: colorScheme.onBackground,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Outfit',
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _isDarkMode ? const Color(0xFF262626) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.onBackground.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.onBackground.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        labelStyle: TextStyle(color: colorScheme.onBackground.withOpacity(0.6), fontFamily: 'Outfit'),
        hintStyle: TextStyle(color: colorScheme.onBackground.withOpacity(0.4), fontFamily: 'Outfit'),
      ),
    );
  }
}
