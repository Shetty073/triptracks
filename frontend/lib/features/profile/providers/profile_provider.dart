import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/auth_provider.dart';

class UserProfileSettings {
  final String distanceUnit;
  final String currency;
  final String themeMode;
  final String accentColor;
  final double avgDailyFoodExpense;
  final double avgNightlyStayExpense;
  final List<dynamic> vehicles;

  UserProfileSettings({
    required this.distanceUnit,
    required this.currency,
    required this.themeMode,
    required this.accentColor,
    required this.avgDailyFoodExpense,
    required this.avgNightlyStayExpense,
    required this.vehicles,
  });

  factory UserProfileSettings.fromJson(Map<String, dynamic> json) {
    return UserProfileSettings(
      distanceUnit: json['distance_unit'] ?? 'km',
      currency: json['currency'] ?? 'USD',
      themeMode: json['theme_mode'] ?? 'system',
      accentColor: json['accent_color'] ?? 'deepPurple',
      avgDailyFoodExpense: (json['avg_daily_food_expense'] ?? 0.0).toDouble(),
      avgNightlyStayExpense: (json['avg_nightly_stay_expense'] ?? 0.0)
          .toDouble(),
      vehicles: json['vehicles'] ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'distance_unit': distanceUnit,
    'currency': currency,
    'theme_mode': themeMode,
    'accent_color': accentColor,
    'avg_daily_food_expense': avgDailyFoodExpense,
    'avg_nightly_stay_expense': avgNightlyStayExpense,
    'vehicles': vehicles,
  };
}

final profileSettingsProvider = FutureProvider<UserProfileSettings>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  // Ensure user is loaded first
  final _ = ref.watch(authStateProvider);

  final response = await dio.get('/api/users/me');
  final settingsJson = response.data['profile_settings'] ?? {};
  return UserProfileSettings.fromJson(settingsJson);
});

class ProfileNotifier {
  final Dio dio;
  final Ref ref;

  ProfileNotifier(this.dio, this.ref);

  Future<void> updateSettings(UserProfileSettings settings) async {
    await dio.put('/api/users/me/settings', data: settings.toJson());
    ref.invalidate(profileSettingsProvider);
  }

  Future<void> updateProfile(String username) async {
    await dio.put('/api/users/me/profile', data: {'username': username});
    ref.invalidate(
      authStateProvider,
    ); // To refresh the current user profile including username
  }

  Future<void> addVehicle(Map<String, dynamic> vehicle) async {
    await dio.post('/api/users/me/vehicles', data: vehicle);
    ref.invalidate(profileSettingsProvider);
  }

  Future<void> removeVehicle(String vehicleId) async {
    await dio.delete('/api/users/me/vehicles/$vehicleId');
    ref.invalidate(profileSettingsProvider);
  }
}

final profileNotifierProvider = Provider((ref) {
  return ProfileNotifier(ref.watch(dioProvider), ref);
});
