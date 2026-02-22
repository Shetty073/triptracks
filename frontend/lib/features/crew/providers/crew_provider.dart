import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/user.dart';

class CrewRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;

  CrewRequest({required this.id, required this.senderId, required this.receiverId, required this.status});

  factory CrewRequest.fromJson(Map<String, dynamic> json) {
    return CrewRequest(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      status: json['status'],
    );
  }
}

final searchCrewProvider = FutureProvider.family<List<User>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/api/crew/search', queryParameters: {'query': query});
  return (response.data as List).map((u) => User.fromJson(u)).toList();
});

final myCrewProvider = FutureProvider<List<User>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/api/crew/');
  return (response.data as List).map((u) => User.fromJson(u)).toList();
});

final pendingRequestsProvider = FutureProvider<List<CrewRequest>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/api/crew/requests/pending');
  return (response.data as List).map((r) => CrewRequest.fromJson(r)).toList();
});

class CrewNotifier {
  final Ref ref;
  CrewNotifier(this.ref);

  Future<void> sendRequest(String userId) async {
    final dio = ref.read(dioProvider);
    await dio.post('/api/crew/requests/$userId');
  }

  Future<void> acceptRequest(String requestId) async {
    final dio = ref.read(dioProvider);
    await dio.post('/api/crew/requests/$requestId/accept');
    ref.invalidate(myCrewProvider);
    ref.invalidate(pendingRequestsProvider);
  }
}

final crewNotifierProvider = Provider((ref) => CrewNotifier(ref));
