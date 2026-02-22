import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/trip.dart';

final publicFeedProvider = FutureProvider<List<Trip>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/api/trips/feed/completed');
  final List<dynamic> data = response.data;
  return data.map((json) => Trip.fromJson(json)).toList();
});
