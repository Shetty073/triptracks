class TripParticipant {
  final String userId;
  final bool isDriver;
  final String role;

  TripParticipant({
    required this.userId,
    required this.isDriver,
    required this.role,
  });

  factory TripParticipant.fromJson(Map<String, dynamic> json) {
    return TripParticipant(
      userId: json['user_id'] ?? '',
      isDriver: json['is_driver'] ?? false,
      role: json['role'] ?? 'passenger',
    );
  }
}

class Expense {
  final String id;
  final String description;
  final double amount;
  final String paidBy;
  final DateTime date;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      paidBy: json['paid_by'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    );
  }
}

class TripComment {
  final String id;
  final String userId;
  final String username;
  final String text;
  final DateTime timestamp;

  TripComment({
    required this.id,
    required this.userId,
    required this.username,
    required this.text,
    required this.timestamp,
  });

  factory TripComment.fromJson(Map<String, dynamic> json) {
    return TripComment(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      username: json['username'] ?? '',
      text: json['text'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

class Trip {
  final String id;
  final String organizerId;
  final String title;
  final String status;
  final double totalDistanceKm;
  final int totalEstimatedTimeMins;
  final Map<String, dynamic> source;
  final Map<String, dynamic> destination;
  final List<TripParticipant> participants;
  final List<Expense> expenses;
  final List<TripComment> comments;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.status,
    required this.totalDistanceKm,
    required this.totalEstimatedTimeMins,
    required this.source,
    required this.destination,
    required this.participants,
    required this.expenses,
    required this.comments,
    required this.createdAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? '',
      organizerId: json['organizer_id'] ?? '',
      title: json['title'] ?? 'Untitled Trip',
      status: json['status'] ?? 'planned',
      totalDistanceKm: (json['total_distance_km'] ?? 0.0).toDouble(),
      totalEstimatedTimeMins: json['total_estimated_time_mins'] ?? 0,
      source: json['source'] ?? {},
      destination: json['destination'] ?? {},
      participants:
          (json['participants'] as List?)
              ?.map((e) => TripParticipant.fromJson(e))
              .toList() ??
          [],
      expenses:
          (json['expenses'] as List?)
              ?.map((e) => Expense.fromJson(e))
              .toList() ??
          [],
      comments:
          (json['comments'] as List?)
              ?.map((e) => TripComment.fromJson(e))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
