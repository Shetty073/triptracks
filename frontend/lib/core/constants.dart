class AppConstants {
  // API Base Configurations
  static const String apiBaseUrl = 'http://localhost:8000';
  static const String wsBaseUrl = 'ws://localhost:8000';

  // WebSocket Endpoints
  static String chatWebSocketUrl(
    String tripId,
    String userId,
    String username,
  ) {
    return '$wsBaseUrl/ws/trips/$tripId?user_id=$userId&username=$username';
  }
}
