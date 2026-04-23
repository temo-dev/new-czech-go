import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class AppUser with _$AppUser {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory AppUser({
    required String id,
    required String email,
    String? displayName,
    String? avatarUrl,
    @Default('vi') String locale,
    DateTime? examDate,
    @Default(0) int dailyGoalMinutes,
    @Default(0) int currentStreakDays,
    @Default(0) int totalXp,
    @Default(0) int weeklyXp,
    DateTime? lastActivityDate,
    @Default(SubscriptionTier.free) SubscriptionTier subscriptionTier,
    DateTime? subscriptionExpiresAt,
    DateTime? createdAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}

enum SubscriptionTier { free, premium }

extension AppUserX on AppUser {
  bool get isPremium => subscriptionTier == SubscriptionTier.premium;
  bool get hasExamDate => examDate != null;

  String get initials {
    final name = displayName ?? email;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
