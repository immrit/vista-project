import 'dart:async';
import 'package:dio/dio.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'package:Vista/features/auth/data/auth_repository.dart';
import 'package:Vista/features/auth/domain/auth_exceptions.dart';
import 'package:Vista/services/session_manager_service_v2.dart';

class RefreshTokenInterceptor extends Interceptor {
  final Dio dio;

  RefreshTokenInterceptor(this.dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // If another flow (health check, another request's interceptor) already
      // rotated the tokens, the stored access token is newer than the one this
      // request failed with — just retry with it instead of burning another
      // refresh (each refresh rotates the refresh token; pointless rotations
      // widen the replay-race window).
      final failedAuth = err.requestOptions.headers['Authorization']?.toString();
      final storedToken = await TokenStorage.getAccessToken();
      if (storedToken != null &&
          storedToken.isNotEmpty &&
          failedAuth != 'Bearer $storedToken' &&
          await TokenStorage.hasValidSession()) {
        try {
          err.requestOptions.headers['Authorization'] = 'Bearer $storedToken';
          final retryResponse = await _retry(err.requestOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          // Retry with the newer token failed too — fall through to a full
          // refresh below.
        }
      }

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
        // Tokens are persisted inside the coordinator, before the future
        // resolves, so no later caller can read the pre-rotation token.
        final response = await RefreshCoordinator.instance.refresh(
          refreshToken,
          AuthRepository(),
          persist: (r) => TokenStorage.saveTokens(r.session),
        );

        // Update authorization header of the failed request
        err.requestOptions.headers['Authorization'] =
            'Bearer ${response.session.accessToken}';

        // Retry the original failed request
        final retryResponse = await _retry(err.requestOptions);

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
        final networkErr = DioException(
          requestOptions: err.requestOptions,
          error: 'خطای ارتباط با شبکه هنگام تمدید نشست',
          type: DioExceptionType.connectionError,
        );
        return handler.next(networkErr);
      }
    }

    return handler.next(err);
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) {
    return dio.request(
      requestOptions.path,
      options: Options(
        method: requestOptions.method,
        headers: requestOptions.headers,
      ),
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
    );
  }

  Future<void> _forceLogout() async {
    // Full termination (wipe + user-visible "session ended" flow) instead of
    // silently clearing tokens and leaving the app in a broken half-state.
    await SessionManagerServiceV2.instance.forceLogoutFromAuthFailure();
  }
}
