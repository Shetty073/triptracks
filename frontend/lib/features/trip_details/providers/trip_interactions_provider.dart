import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/trip_details/providers/trip_details_provider.dart';

class TripInteractionsNotifier {
  final Ref ref;
  TripInteractionsNotifier(this.ref);

  Future<void> addExpense(String tripId, String description, double amount) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '/api/trips/$tripId/expenses',
      data: {
        'description': description,
        'amount': amount,
        'paid_by': '', // Handled by backend from token
      },
    );
    ref.invalidate(tripDetailsProvider(tripId));
  }

  Future<void> addComment(String tripId, String text) async {
    final dio = ref.read(dioProvider);
    await dio.post(
      '/api/trips/$tripId/comments',
      data: {'text': text},
    );
    ref.invalidate(tripDetailsProvider(tripId));
  }
}

final tripInteractionsProvider = Provider((ref) => TripInteractionsNotifier(ref));
