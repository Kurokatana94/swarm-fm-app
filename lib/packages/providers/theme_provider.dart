import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swarm_fm_app/themes/themes.dart';

// Theme State
class ThemeState {
  final String themeName;
  final Map<dynamic, dynamic> theme;

  ThemeState({
    required this.themeName,
    required this.theme,
  });

  ThemeState copyWith({
    String? themeName,
    Map<dynamic, dynamic>? theme,
  }) {
    return ThemeState(
      themeName: themeName ?? this.themeName,
      theme: theme ?? this.theme,
    );
  }
}

// Theme Provider
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(ThemeState(themeName: 'neuro', theme: themes['neuro']!)) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('activeTheme') ?? 'neuro';
    
    if (themes.containsKey(themeName)) {
      state = ThemeState(
        themeName: themeName,
        theme: themes[themeName]!,
      );
    }
  }

  Future<void> changeTheme(String themeName) async {
    if (themes.containsKey(themeName)) {
      state = ThemeState(
        themeName: themeName,
        theme: themes[themeName]!,
      );
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activeTheme', themeName);
    }
  }

  String get currentThemeName => state.themeName;
  bool get isNeuroTheme => state.themeName == 'neuro';
  bool get isEvilTheme => state.themeName == 'evil';
  bool get isVedalTheme => state.themeName == 'vedal';
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
