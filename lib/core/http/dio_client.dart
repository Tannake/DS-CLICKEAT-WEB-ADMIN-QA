import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ds_clickeat_web_admin/core/env.dart';
import 'package:ds_clickeat_web_admin/core/errors/error_logger.dart';
import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = ref.read(sessionControllerProvider);
        final token = session?.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          options.headers.remove('Authorization');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        // Business-logic failures (`{state: 0, message: "..."}`) return
        // HTTP 200, so they never reach `onError` below — check the
        // envelope here to log those too instead of relying on every
        // repository's own `Exception(message)` throw.
        final data = response.data;
        if (data is Map && data['state'] != null && data['state'] != 1) {
          ErrorLogger.log(
            functionName: '${response.requestOptions.method} ${response.requestOptions.path}',
            message: (data['message'] ?? 'state != 1').toString(),
            parameters: {
              'query': response.requestOptions.queryParameters,
              'data': response.requestOptions.data,
            },
            token: ref.read(sessionControllerProvider)?.accessToken,
          );
        }
        handler.next(response);
      },
      onError: (e, handler) async {
        ErrorLogger.log(
          functionName: '${e.requestOptions.method} ${e.requestOptions.path}',
          message: e.message ?? e.error?.toString() ?? 'Dio error',
          parameters: {
            'query': e.requestOptions.queryParameters,
            'data': e.requestOptions.data,
            'status': e.response?.statusCode,
          },
          token: ref.read(sessionControllerProvider)?.accessToken,
        );
        if (e.response?.statusCode == 401) {
          try {
            await ref.read(sessionControllerProvider.notifier).logout();
          } catch (_) {}
        }
        handler.next(e);
      },
    ),
  );

  return dio;
});
