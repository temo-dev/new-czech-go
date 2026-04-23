// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppUserImpl _$$AppUserImplFromJson(Map<String, dynamic> json) =>
    _$AppUserImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      locale: json['locale'] as String? ?? 'vi',
      examDate: json['exam_date'] == null
          ? null
          : DateTime.parse(json['exam_date'] as String),
      dailyGoalMinutes: (json['daily_goal_minutes'] as num?)?.toInt() ?? 0,
      currentStreakDays: (json['current_streak_days'] as num?)?.toInt() ?? 0,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      weeklyXp: (json['weekly_xp'] as num?)?.toInt() ?? 0,
      lastActivityDate: json['last_activity_date'] == null
          ? null
          : DateTime.parse(json['last_activity_date'] as String),
      subscriptionTier: $enumDecodeNullable(
              _$SubscriptionTierEnumMap, json['subscription_tier']) ??
          SubscriptionTier.free,
      subscriptionExpiresAt: json['subscription_expires_at'] == null
          ? null
          : DateTime.parse(json['subscription_expires_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$AppUserImplToJson(_$AppUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'display_name': instance.displayName,
      'avatar_url': instance.avatarUrl,
      'locale': instance.locale,
      'exam_date': instance.examDate?.toIso8601String(),
      'daily_goal_minutes': instance.dailyGoalMinutes,
      'current_streak_days': instance.currentStreakDays,
      'total_xp': instance.totalXp,
      'weekly_xp': instance.weeklyXp,
      'last_activity_date': instance.lastActivityDate?.toIso8601String(),
      'subscription_tier':
          _$SubscriptionTierEnumMap[instance.subscriptionTier]!,
      'subscription_expires_at':
          instance.subscriptionExpiresAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$SubscriptionTierEnumMap = {
  SubscriptionTier.free: 'free',
  SubscriptionTier.premium: 'premium',
};
