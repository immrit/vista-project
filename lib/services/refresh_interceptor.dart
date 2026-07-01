import 'dart:async';
import 'package:dio/dio.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'package:Vista/features/auth/data/auth_repository.dart';
import 'package:Vista/features/auth/domain/auth_exceptions.dart';

class RefreshTokenInterceptor extends Interceptor {
  final Dio dio;

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

      try {
        // Routed through RefreshCoordinator so this never races the session
        // manager's own health-check-triggered refresh — only one
        // /auth/refresh call is ever in flight at a time for the process.
        final response = await RefreshCoordinator.instance
            .refresh(refreshToken, AuthRepository());

        await TokenStorage.saveTokens(response.session);

        // Update authorization header of the failed request
        err.requestOptions.headers['Authorization'] =
            'Bearer ${response.session.accessToken}';

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

        return handler.resolve(retryResponse);
      } on UnauthorizedAuthException {
        // The server gave an explicit, unambiguous "this refresh token is
        // dead" answer — the one case that should ever force a logout.
        await _forceLogout();
        return handler.next(err);
      } catch (e) {
        // NetworkAuthException (timeout, 5xx, unexpected status/body) or a
        // failure retrying the original request. None of these mean the
        // token is invalid — just let this one request fail; the session
        // stays intact and the next attempt (this interceptor or the
        // session manager's health check) can retry.
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  Future<void> _forceLogout() async {
    await TokenStorage.clearAll();
    // Use navigator to push to login if needed
  }
}
