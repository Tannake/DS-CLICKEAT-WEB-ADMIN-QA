import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ds_clickeat_web_admin/core/http/dio_client.dart';
import 'package:ds_clickeat_web_admin/features/auth/models/session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider));
});

class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  Future<Session> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post('auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = res.data;
      if (res.statusCode == 200 &&
          data is Map &&
          data['state'] == 1 &&
          data['result'] is Map) {
        final session = Session.fromBackend(
          Map<String, dynamic>.from(data['result'] as Map),
        );

        _dio.options.headers['Authorization'] = 'Bearer ${session.accessToken}';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(kSessionKey, jsonEncode(session.toJson()));
        return session;
      }

      final msg = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'Error al iniciar sesión';
      throw AuthException(msg);
    } on DioException catch (e) {
      final body = e.response?.data;
      String msg = e.message ?? 'Error de conexión';
      if (body is Map && body['message'] is String) {
        msg = body['message'] as String;
      }
      throw AuthException(msg);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kSessionKey);
    _dio.options.headers.remove('Authorization');
  }

  Future<Session?> readPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSessionKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final session = Session.fromJson(map);
    _dio.options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    return session;
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
