import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api_client.dart';

// ─── Location Suggestion ─────────────────────────────────────────────────────

class LocationSuggestion {
  final String name;
  final double lat;
  final double lng;

  LocationSuggestion({required this.name, required this.lat, required this.lng});

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) =>
      LocationSuggestion(
        name: json['name'],
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lng': lng};
}

// ─── Crew Member with Vehicles (for trip planning) ───────────────────────────

class CrewMemberForTrip {
  final String id;
  final String username;
  final String email;
  final String? fullName;
  final List<VehicleOption> vehicles;

  CrewMemberForTrip({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    required this.vehicles,
  });

  String get displayName => fullName?.isNotEmpty == true ? fullName! : username;

  factory CrewMemberForTrip.fromJson(Map<String, dynamic> json) {
    final settings = json['profile_settings'] as Map<String, dynamic>? ?? {};
    final vehicleList = (settings['vehicles'] as List<dynamic>? ?? [])
        .map((v) => VehicleOption.fromJson(v as Map<String, dynamic>))
        .toList();
    return CrewMemberForTrip(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      vehicles: vehicleList,
    );
  }
}

class VehicleOption {
  final String id;
  final String name;
  final String type;
  final int seats;
  final double mileagePerLiter;
  final double avgDistancePerDay;

  VehicleOption({
    required this.id,
    required this.name,
    required this.type,
    required this.seats,
    required this.mileagePerLiter,
    required this.avgDistancePerDay,
  });

  factory VehicleOption.fromJson(Map<String, dynamic> json) => VehicleOption(
        id: json['id'],
        name: json['name'] ?? '${json['type']} (${json['seats']} seats)',
        type: json['type'],
        seats: json['seats'],
        mileagePerLiter: (json['mileage_per_liter'] as num?)?.toDouble() ?? 15.0,
        avgDistancePerDay: (json['avg_distance_per_day'] as num?)?.toDouble() ?? 500.0,
      );

  String get displayLabel => '$name • $seats seats • ${mileagePerLiter.toStringAsFixed(0)}km/L';
}


// ─── Participant assignment ───────────────────────────────────────────────────

class TripParticipantAssignment {
  final String userId;
  String role; // 'driver' | 'passenger'
  String? vehicleId;

  TripParticipantAssignment({
    required this.userId,
    this.role = 'passenger',
    this.vehicleId,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'role': role,
        'vehicle_id': vehicleId,
        'is_driver': role == 'driver',
      };
}

// ─── Provider ────────────────────────────────────────────────────────────────

class PlanTripNotifier {
  final Ref ref;
  PlanTripNotifier(this.ref);

  Future<List<LocationSuggestion>> fetchAutocomplete(String query) async {
    if (query.isEmpty) return [];
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get(
        '/api/trips/autocomplete',
        queryParameters: {'query': query},
      );
      return (response.data as List)
          .map((e) => LocationSuggestion.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<CrewMemberForTrip>> fetchCrewWithVehicles() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/crew/');
    return (response.data as List)
        .map((u) => CrewMemberForTrip.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> calculateItinerary({
    required LocationSuggestion source,
    required LocationSuggestion destination,
    required List<LocationSuggestion> stops,
    List<VehicleOption> selectedVehicles = const [],
    double fuelPricePerLiter = 100.0,
  }) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post(
      '/api/trips/intelligence/plan',
      data: {
        'source': source.toJson(),
        'destination': destination.toJson(),
        'stops': stops.map((s) => s.toJson()).toList(),
        'fuel_price_per_liter': fuelPricePerLiter,
        'selected_vehicles': selectedVehicles.map((v) => {
          'id': v.id,
          'name': v.name,
          'seats': v.seats,
          'mileage_per_liter': v.mileagePerLiter,
          'avg_distance_per_day': v.avgDistancePerDay,
        }).toList(),
      },
    );
    return response.data;
  }

  Future<void> saveTripDraft({
    required String title,
    required LocationSuggestion source,
    required LocationSuggestion destination,
    required List<LocationSuggestion> stops,
    required List<TripParticipantAssignment> participants,
    double? totalDistanceKm,
    int? totalTimeMins,
    int? estimatedDays,
  }) async {
    final dio = ref.read(dioProvider);
    await dio.post('/api/trips/', data: {
      'title': title,
      'source': source.toJson(),
      'destination': destination.toJson(),
      'stops': stops.map((s) => s.toJson()).toList(),
      'participants': participants.map((p) => p.toJson()).toList(),
      'status': 'planned',
      // ignore: use_null_aware_elements
      if (totalDistanceKm != null) 'total_distance_km': totalDistanceKm,
      // ignore: use_null_aware_elements
      if (totalTimeMins != null) 'total_estimated_time_mins': totalTimeMins,
    });
  }
}

final planTripProvider = Provider<PlanTripNotifier>((ref) => PlanTripNotifier(ref));
