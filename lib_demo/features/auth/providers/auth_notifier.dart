import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_czech/shared/providers/auth_provider.dart';

part 'auth_notifier.freezed.dart';
part 'auth_notifier.g.dart';

enum AuthFormStatus { idle, submitting, success, validationError, authError }

@freezed
class AuthFormState with _$AuthFormState {
  const factory AuthFormState({
    @Default(AuthFormStatus.idle) AuthFormStatus status,
    String? errorMessage,
  }) = _AuthFormState;
}

/// Owns auth form state (status + error text).
/// Delegates actual auth calls to [CurrentUser] which owns the session.
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthFormState build() => const AuthFormState();

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      state = const AuthFormState(
        status: AuthFormStatus.validationError,
        errorMessage: 'Vui lòng điền đầy đủ thông tin',
      );
      return;
    }

    state = const AuthFormState(status: AuthFormStatus.submitting);
    try {
      await ref
          .read(currentUserProvider.notifier)
          .signIn(email: email.trim(), password: password);
      state = const AuthFormState(status: AuthFormStatus.success);
    } catch (e) {
      state = AuthFormState(
        status: AuthFormStatus.authError,
        errorMessage: _mapError(e),
      );
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (email.trim().isEmpty) {
      state = const AuthFormState(
        status: AuthFormStatus.validationError,
        errorMessage: 'Vui lòng nhập email',
      );
      return;
    }
    if (password.length < 8) {
      state = const AuthFormState(
        status: AuthFormStatus.validationError,
        errorMessage: 'Mật khẩu phải có ít nhất 8 ký tự',
      );
      return;
    }

    state = const AuthFormState(status: AuthFormStatus.submitting);
    try {
      await ref.read(currentUserProvider.notifier).signUp(
            email: email.trim(),
            password: password,
            displayName: displayName,
          );
      state = const AuthFormState(status: AuthFormStatus.success);
    } catch (e) {
      state = AuthFormState(
        status: AuthFormStatus.authError,
        errorMessage: _mapError(e),
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) {
      state = const AuthFormState(
        status: AuthFormStatus.validationError,
        errorMessage: 'Vui lòng nhập email',
      );
      return;
    }
    state = const AuthFormState(status: AuthFormStatus.submitting);
    try {
      await ref
          .read(currentUserProvider.notifier)
          .sendPasswordReset(email.trim());
      state = const AuthFormState(status: AuthFormStatus.success);
    } catch (e) {
      state = AuthFormState(
        status: AuthFormStatus.authError,
        errorMessage: _mapError(e),
      );
    }
  }

  void reset() => state = const AuthFormState();

  String _mapError(Object e) {
    final msg = e.toString().toLowerCase();
    // AuthException message truyền trực tiếp từ auth_provider (tiếng Việt)
    if (e is AuthException) return e.message;
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid login')) {
      return 'Email hoặc mật khẩu không đúng';
    }
    if (msg.contains('already registered') ||
        msg.contains('user already')) {
      return 'Email này đã được đăng ký';
    }
    if (msg.contains('weak password')) {
      return 'Mật khẩu quá yếu, vui lòng chọn mật khẩu khác';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Không có kết nối mạng, vui lòng thử lại';
    }
    if (msg.contains('rate limit')) {
      return 'Quá nhiều lần thử. Vui lòng đợi vài phút';
    }
    return 'Đã xảy ra lỗi. Vui lòng thử lại.';
  }
}
