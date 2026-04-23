import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = true,
    this.reminderHour = 20,
    this.reminderMinute = 0,
  });

  final bool enabled;
  final int reminderHour;   // 0–23
  final int reminderMinute; // 0 or 30

  NotificationPrefs copyWith({
    bool? enabled,
    int? reminderHour,
    int? reminderMinute,
  }) =>
      NotificationPrefs(
        enabled: enabled ?? this.enabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'reminder_hour': reminderHour,
        'reminder_minute': reminderMinute,
      };

  static NotificationPrefs fromJson(Map<String, dynamic> m) =>
      NotificationPrefs(
        enabled: m['enabled'] as bool? ?? true,
        reminderHour: m['reminder_hour'] as int? ?? 20,
        reminderMinute: m['reminder_minute'] as int? ?? 0,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class NotificationPrefsNotifier
    extends StateNotifier<AsyncValue<NotificationPrefs>> {
  NotificationPrefsNotifier()
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data(NotificationPrefs());
        return;
      }
      final row = await supabase
          .from('profiles')
          .select('notification_prefs')
          .eq('id', userId)
          .maybeSingle();

      if (row == null) {
        state = const AsyncValue.data(NotificationPrefs());
        return;
      }

      final raw =
          (row as Map)['notification_prefs'] as Map<String, dynamic>?;
      state = AsyncValue.data(
          raw != null ? NotificationPrefs.fromJson(raw) : const NotificationPrefs());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> update(NotificationPrefs prefs) async {
    final previous = state;
    state = AsyncValue.data(prefs); // optimistic

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      await supabase
          .from('profiles')
          .update({'notification_prefs': prefs.toJson()})
          .eq('id', userId);
    } catch (e, st) {
      state = previous; // rollback
      state = AsyncValue.error(e, st);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final notificationPrefsProvider = StateNotifierProvider.autoDispose<
    NotificationPrefsNotifier, AsyncValue<NotificationPrefs>>(
  (_) => NotificationPrefsNotifier(),
);
