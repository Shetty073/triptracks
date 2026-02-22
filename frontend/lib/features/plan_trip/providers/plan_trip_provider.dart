import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api_client.dart';

class LocationSuggestion {
  final String name;
  final double lat;
  final double lng;

  LocationSuggestion({required this.name, required this.lat, required this.lng});

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      name: json['name'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': lat,
    'lng': lng,
  };
}

class PlanTripNotifier {
  final Ref ref;

  PlanTripNotifier(this.ref);

  Future<List<LocationSuggestion>> fetchAutocomplete(String query) async {
    if (query.isEmpty) return [];
    
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/api/trips/autocomplete', queryParameters: {'query': query});
      return (response.data as List).map((e) => LocationSuggestion.fromJson(e)).toList();
    } catch (e) {
      // Handle error gracefully
      return [];
    }
  }

  Future<Map<String, dynamic>> calculateItinerary({
    required LocationSuggestion source,
    required LocationSuggestion destination,
    required List<LocationSuggestion> stops,
  }) async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.post(
        '/api/trips/intelligence/plan',
        data: {
          'source': source.toJson(),
          'destination': destination.toJson(),
          'stops': stops.map((s) => s.toJson()).toList(),
        },
      );
      return response.data;
    } catch (e) {
      throw Exception("Failed to plan trip");
    }
  }

  Future<void> saveTripDraft({
    required String title,
    required LocationSuggestion source,
    required LocationSuggestion destination,
    required List<LocationSuggestion> stops,
  }) async {
    final dio = ref.read(dioProvider);
    try {
      await dio.post(
        '/api/trips/',
        data: {
          'title': title,
          'source': source.toJson(),
          'destination': destination.toJson(),
          'stops': stops.map((s) => s.toJson()).toList(),
          'status': 'planned',
        },
      );
    } catch (e) {
      throw Exception("Failed to save draft");
    }
  }
}

final planTripProvider = Provider<PlanTripNotifier>((ref) {
  return PlanTripNotifier(ref);
});
