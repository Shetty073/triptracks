import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/trip.dart';

final tripDetailsProvider = FutureProvider.family<Trip, String>((ref, tripId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/api/trips/$tripId');
  return Trip.fromJson(response.data);
});

class TripStatusNotifier {
  final Ref ref;
  TripStatusNotifier(this.ref);

  Future<void> updateStatus(String tripId, String status) async {
    final dio = ref.read(dioProvider);
    await dio.put('/api/trips/$tripId/status', queryParameters: {'status': status});
    ref.invalidate(tripDetailsProvider(tripId));
  }
}

final tripActionProvider = Provider((ref) => TripStatusNotifier(ref));
