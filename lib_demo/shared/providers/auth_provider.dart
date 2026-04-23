import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/core/storage/prefs_storage.dart';
import 'package:app_czech/shared/models/user_model.dart';

part 'auth_provider.g.dart';

// ── Raw Supabase session ────────────────────────────────────────────────────

/// Emits the current session (null = logged out).
/// Backed by Supabase's onAuthStateChange stream.
@riverpod
Stream<Session?> authSession(Ref ref) {
  return supabase.auth.onAuthStateChange
      .map((event) => event.session);
}

// ── App user profile ────────────────────────────────────────────────────────

@riverpod
class CurrentUser extends _$CurrentUser {
  @override
  Future<AppUser?> build() async {
    final session = supabase.auth.currentSession;
    if (session == null) return null;
    return _fetchProfile(session.user.id);
  }

  Future<AppUser?> _fetchProfile(String userId) async {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      // Profile row missing — trigger may have failed for this user.
      // Build a minimal AppUser from auth metadata so the app doesn't crash.
      final authUser = supabase.auth.currentUser;
      if (authUser == null) return null;
      return AppUser(
        id: userId,
        email: authUser.email ?? '',
        displayName: authUser.userMetadata?['display_name'] as String? ??
            authUser.email?.split('@').first,
      );
    }

    return AppUser.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final userId = supabase.auth.currentUser!.id;
      return _fetchProfile(userId);
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      final user = response.user;
      if (user == null) {
        // Supabase trả về null user khi email đã tồn tại (email enumeration protection)
        throw const AuthException('Email này đã được đăng ký hoặc yêu cầu xác nhận email.');
      }

      if (response.session == null) {
        // Email confirmation bật — user đã được tạo nhưng chưa có session.
        // Profile row đã được tạo qua trigger on_auth_user_created.
        // Thông báo để user kiểm tra email.
        throw const AuthException('Vui lòng kiểm tra email để xác nhận tài khoản, sau đó đăng nhập.');
      }

      // Email confirmation tắt — có session ngay, fetch profile bình thường.
      state = AsyncData(await _fetchProfile(user.id));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow; // authNotifier bắt và hiển thị lỗi
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    await PrefsStorage.instance.setOnboardingComplete(false);
    state = const AsyncData(null);
  }

  Future<void> sendPasswordReset(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> updateProfile(AppUser updated) async {
    final previous = state;
    state = AsyncData(updated);
    try {
      await supabase.from('profiles').upsert(updated.toJson());
    } catch (_) {
      state = previous; // rollback
      rethrow;
    }
  }
}

// ── Convenience booleans ────────────────────────────────────────────────────

@riverpod
bool isAuthenticated(Ref ref) {
  return supabase.auth.currentSession != null;
}
