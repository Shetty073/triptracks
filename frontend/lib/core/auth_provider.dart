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

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'username': username, 'password': password},
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

  Future<void> register(String email, String username, String password) async {
    state = const AsyncValue.loading();
    try {
      await _dio.post(
        '/api/auth/register',
        data: {'email': email, 'username': username, 'password': password},
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
