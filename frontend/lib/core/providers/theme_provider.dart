import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/profile/providers/profile_provider.dart';
import 'package:frontend/core/theme.dart';

class ThemeState {
  final ThemeMode themeMode;
  final Color accentColor;

  ThemeState({required this.themeMode, required this.accentColor});
}

final themeProvider = Provider<ThemeState>((ref) {
  final settingsAsync = ref.watch(profileSettingsProvider);

  return settingsAsync.maybeWhen(
    data: (settings) {
      final mode = settings.themeMode == 'dark'
          ? ThemeMode.dark
          : (settings.themeMode == 'light'
                ? ThemeMode.light
                : ThemeMode.system);

      final color = TripTracksTheme.getColorFromName(settings.accentColor);
      return ThemeState(themeMode: mode, accentColor: color);
    },
    orElse: () => ThemeState(
      themeMode: ThemeMode.system,
      accentColor: TripTracksTheme.primaryColor,
    ),
  );
});
