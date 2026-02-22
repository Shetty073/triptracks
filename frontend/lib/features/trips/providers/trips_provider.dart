import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/trip.dart';

class CategorizedTrips {
  final List<Trip> plannedByMe;
  final List<Trip> completedByMe;
  final List<Trip> participantActive;
  final List<Trip> participantCompleted;

  CategorizedTrips({
    required this.plannedByMe,
    required this.completedByMe,
    required this.participantActive,
    required this.participantCompleted,
  });

  factory CategorizedTrips.fromJson(Map<String, dynamic> json) {
    return CategorizedTrips(
      plannedByMe: (json['planned_by_me'] as List)
          .map((t) => Trip.fromJson(t))
          .toList(),
      completedByMe: (json['completed_by_me'] as List)
          .map((t) => Trip.fromJson(t))
          .toList(),
      participantActive: (json['participant_active'] as List)
          .map((t) => Trip.fromJson(t))
          .toList(),
      participantCompleted: (json['participant_completed'] as List)
          .map((t) => Trip.fromJson(t))
          .toList(),
    );
  }
}

final myTripsProvider = FutureProvider<CategorizedTrips>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/api/trips/user/categories');
  return CategorizedTrips.fromJson(response.data);
});
