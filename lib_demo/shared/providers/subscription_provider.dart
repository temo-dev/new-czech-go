import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:app_czech/shared/providers/auth_provider.dart';
import 'package:app_czech/shared/models/user_model.dart';

part 'subscription_provider.g.dart';

enum SubscriptionStatus { active, expired, free }

@riverpod
SubscriptionStatus subscriptionStatus(Ref ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return SubscriptionStatus.free;
      if (user.subscriptionTier == SubscriptionTier.free) {
        return SubscriptionStatus.free;
      }
      final expiry = user.subscriptionExpiresAt;
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        return SubscriptionStatus.expired;
      }
      return SubscriptionStatus.active;
    },
    loading: () => SubscriptionStatus.free,
    error: (_, __) => SubscriptionStatus.free,
  );
}

@riverpod
bool isPremium(Ref ref) {
  return ref.watch(subscriptionStatusProvider) == SubscriptionStatus.active;
}
