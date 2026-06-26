import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'package:Vista/core/app_config.dart';

class RefreshTokenInterceptor extends Interceptor {
  final Dio dio;
  bool _isRefreshing = false;
  final _requestsQueue = <Completer<Response>>[];

  RefreshTokenInterceptor(this.dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        // No refresh token, means user needs to log in
        await _forceLogout();
        return handler.next(err);
      }

      if (_isRefreshing) {
        // Queue the request
        final completer = Completer<Response>();
        _requestsQueue.add(completer);
        try {
          final response = await completer.future;
          // Retry the original request
          final retryResponse = await dio.request(
            err.requestOptions.path,
            options: Options(
              method: err.requestOptions.method,
              headers: err.requestOptions.headers,
            ),
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
          );
          return handler.resolve(retryResponse);
        } catch (e) {
          return handler.next(err);
        }
      }

      _isRefreshing = true;

      try {
        // Call refresh endpoint directly using a separate Dio instance to avoid interceptor loops
        final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
        final response = await refreshDio.post('/auth/refresh', data: {
          'refresh_token': refreshToken,
        });

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data['session'];
          if (data != null && data['access_token'] != null) {
            // Save new tokens
            // Note: Since we don't have AuthSessionResponse easily accessible here without
            // importing auth_repository.dart, we'll manually save or use a helper
            // We can just construct a map and save.
            await TokenStorage.saveTokensFromMap(data);

            // Update authorization header of the failed request
            err.requestOptions.headers['Authorization'] = 'Bearer ${data['access_token']}';

            // Retry the original failed request
            final retryResponse = await dio.request(
              err.requestOptions.path,
              options: Options(
                method: err.requestOptions.method,
                headers: err.requestOptions.headers,
              ),
              data: err.requestOptions.data,
              queryParameters: err.requestOptions.queryParameters,
            );

            // Resolve queued requests
            for (var c in _requestsQueue) {
              c.complete(retryResponse); // actually they will retry themselves, but we just trigger complete
            }
            _requestsQueue.clear();
            _isRefreshing = false;

            return handler.resolve(retryResponse);
          }
        }
        
        // Refresh failed (e.g. invalid refresh token)
        await _forceLogout();
        _rejectQueue(err);
        return handler.next(err);
      } catch (e) {
        await _forceLogout();
        _rejectQueue(err);
        return handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    }

    return handler.next(err);
  }

  void _rejectQueue(DioException err) {
    for (var c in _requestsQueue) {
      c.completeError(err);
    }
    _requestsQueue.clear();
  }

  Future<void> _forceLogout() async {
    await TokenStorage.clearAll();
    // Use navigator to push to login if needed
  }
}
