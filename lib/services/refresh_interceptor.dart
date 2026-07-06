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

        // A FormData body is single-use — Dio finalizes it on the first send,
        // so replaying the same instance throws "already finalized". Rather
        // than fail the upload, surface a retriable error so the caller can
        // rebuild fresh FormData and resend (its token is now valid).
        if (err.requestOptions.data is FormData) {
          return handler.next(DioException(
            requestOptions: err.requestOptions,
            error: 'token_refreshed_retry_upload',
            type: DioExceptionType.cancel,
          ));
        }

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
    // fetch(requestOptions) preserves EVERYTHING (responseType, contentType,
    // sendTimeout, extra, ...). The old Options(method, headers) copy dropped
    // those, so e.g. a JSON-expecting call could come back mistyped after a
    // mid-request token refresh.
    return dio.fetch<dynamic>(requestOptions);
  }

  Future<void> _forceLogout() async {
    // Full termination (wipe + user-visible "session ended" flow) instead of
    // silently clearing tokens and leaving the app in a broken half-state.
    await SessionManagerServiceV2.instance.forceLogoutFromAuthFailure();
  }
}
