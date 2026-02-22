import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/trip.dart';

class FeedSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) {
    state = query;
  }
}

final feedSearchQueryProvider =
    NotifierProvider<FeedSearchQueryNotifier, String>(
      FeedSearchQueryNotifier.new,
    );

final publicFeedProvider = FutureProvider<List<Trip>>((ref) async {
  final dio = ref.watch(dioProvider);
  final searchQuery = ref.watch(feedSearchQueryProvider);

  final queryParams = searchQuery.isNotEmpty ? {'search': searchQuery} : null;

  final response = await dio.get(
    '/api/trips/feed/completed',
    queryParameters: queryParams,
  );
  final List<dynamic> data = response.data;
  return data.map((json) => Trip.fromJson(json)).toList();
});
