import 'package:dio/dio.dart';

import 'package:ds_clickeat_web_admin/core/env.dart';

/// Fire-and-forget error reporting to the backend's `scrip/log-error`
/// endpoint (`<API_BASE_URL>scrip/log-error`, e.g.
/// `http://localhost:3000/api/admin/scrip/log-error` — same base/prefix as
/// every other request, just like a repository would call it). Wired in two
/// places to cover the whole app: every failed/non-`state:1` HTTP call
/// (`core/http/dio_client.dart`'s interceptor) and every uncaught
/// Flutter/Dart error (`main.dart`'s `FlutterError.onError`/
/// `runZonedGuarded`).
class ErrorLogger {
  ErrorLogger._();

  /// A bare `Dio` with no interceptors of its own — reusing the app's
  /// authenticated [dioProvider] instance here would let a failed log call
  /// re-trigger this same error-logging interceptor and recurse.
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    headers: {'Content-Type': 'application/json'},
  ));

  /// [parameters] is whatever's useful to reproduce the failure (request
  /// query/body, widget args, a stack trace, …) — stringified and truncated
  /// as-is, no particular shape expected. [token] is the current session's
  /// access token — every backend endpoint requires it, this one included,
  /// so callers without direct `Dio`/interceptor access to it (e.g.
  /// `main.dart`'s global error handlers) must pass it explicitly.
  static Future<void> log({
    required String functionName,
    required String message,
    Object? parameters,
    String? token,
  }) async {
    try {
      await _dio.post(
        'scrip/log-error',
        data: {
          'prem_id': 0,
          'log_type': 'WebAdmin',
          'function_name': functionName,
          'message': _truncate(message),
          'parameters': parameters == null ? '' : _truncate(parameters.toString()),
        },
        options: Options(
          headers: token != null && token.isNotEmpty
              ? {'Authorization': 'Bearer $token'}
              : null,
        ),
      );
    } catch (_) {
      // Logging must never throw — there's nowhere further to report it,
      // and it must never mask the original error.
    }
  }

  static String _truncate(String s) => s.length > 4000 ? s.substring(0, 4000) : s;
}
