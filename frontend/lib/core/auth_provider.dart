import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/models/user.dart';

const _storage = FlutterSecureStorage();

final authStateProvider = AsyncNotifierProvider<AuthNotifier, User?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<User?> {
  Dio get _dio => ref.read(dioProvider);

  @override
  Future<User?> build() async {
    return _loadUser();
  }

  Future<User?> _loadUser() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      try {
        final response = await _dio.get('/api/users/me');
        return User.fromJson(response.data);
      } catch (e) {
        rethrow;
      }
    } else {
      return null;
    }
  }

  Future<void> login(String usernameOrEmail, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'username': usernameOrEmail, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      await _storage.write(
        key: 'access_token',
        value: response.data['access_token'],
      );
      await _storage.write(
        key: 'refresh_token',
        value: response.data['refresh_token'],
      );
      final user = await _loadUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Sends a mock OTP to the given email (OTP is always 123456 in dev).
  Future<void> sendOtp(String email) async {
    await _dio.post('/api/auth/otp/send', data: {'email': email});
  }

  /// Verifies the OTP for the given email. Throws on failure.
  Future<void> verifyOtp(String email, String otp) async {
    final response = await _dio.post(
      '/api/auth/otp/verify',
      data: {'email': email, 'otp': otp},
    );
    if (response.data['verified'] != true) {
      throw Exception('Invalid OTP. Please try again.');
    }
  }

  /// Registers a new user. OTP must have been verified beforehand.
  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String serviceCode,
    String? fullName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _dio.post(
        '/api/auth/register',
        data: {
          'email': email,
          'username': username,
          'password': password,
          'service_code': serviceCode,
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        },
      );
      await login(username, password);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    state = const AsyncValue.data(null);
  }
}
