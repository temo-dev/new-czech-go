import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/features/chat/models/friend_models.dart';

part 'friend_providers.g.dart';

// ── Friends list (accepted) ────────────────────────────────────────────────

@riverpod
Stream<List<UserProfile>> friends(Ref ref) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  final controller = StreamController<List<UserProfile>>();

  Future<void> reload() async {
    try {
      final data = await _fetchFriends(userId);
      if (!controller.isClosed) controller.add(data);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  reload();

  final channel = supabase
      .channel('friendships_${userId}_friends')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'friendships',
        callback: (_) => reload(),
      )
      .subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
}

Future<List<UserProfile>> _fetchFriends(String userId) async {
  final rows = await supabase
      .from('friendships')
      .select('id, requester_id, addressee_id, status')
      .eq('status', 'accepted')
      .or('requester_id.eq.$userId,addressee_id.eq.$userId');

  final friendships = (rows as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  if (friendships.isEmpty) return [];

  final peerIds = friendships.map((r) {
    return r['requester_id'] == userId
        ? r['addressee_id'] as String
        : r['requester_id'] as String;
  }).toList();

  final profileRows = await supabase
      .from('public_profiles')
      .select('id, display_name, avatar_url, total_xp')
      .inFilter('id', peerIds);

  final profileById = <String, Map<String, dynamic>>{
    for (final p in (profileRows as List))
      (p as Map)['id'] as String: Map<String, dynamic>.from(p),
  };

  final result = <UserProfile>[];
  for (final r in friendships) {
    final friendshipId = r['id'] as String;
    final peerId = r['requester_id'] == userId
        ? r['addressee_id'] as String
        : r['requester_id'] as String;
    final profile = profileById[peerId];
    if (profile != null) {
      result.add(UserProfile.fromMap(
        profile,
        friendshipStatus: FriendshipStatus.accepted,
        friendshipId: friendshipId,
        isRequester: r['requester_id'] == userId,
      ));
    }
  }

  result.sort((a, b) => a.displayName.compareTo(b.displayName));
  return result;
}

// ── Pending friend requests (received) ────────────────────────────────────

@riverpod
Stream<List<UserProfile>> pendingRequests(Ref ref) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  final controller = StreamController<List<UserProfile>>();

  Future<void> reload() async {
    try {
      final data = await _fetchPendingRequests(userId);
      if (!controller.isClosed) controller.add(data);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  reload();

  final channel = supabase
      .channel('friendships_${userId}_pending')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'friendships',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'addressee_id',
          value: userId,
        ),
        callback: (_) => reload(),
      )
      .subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
}

Future<List<UserProfile>> _fetchPendingRequests(String userId) async {
  final rows = await supabase
      .from('friendships')
      .select('id, requester_id')
      .eq('addressee_id', userId)
      .eq('status', 'pending');

  final friendships = (rows as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  if (friendships.isEmpty) return [];

  final requesterIds =
      friendships.map((r) => r['requester_id'] as String).toList();

  final profileRows = await supabase
      .from('public_profiles')
      .select('id, display_name, avatar_url, total_xp')
      .inFilter('id', requesterIds);

  final profileById = <String, Map<String, dynamic>>{
    for (final p in (profileRows as List))
      (p as Map)['id'] as String: Map<String, dynamic>.from(p),
  };

  final result = <UserProfile>[];
  for (final r in friendships) {
    final friendshipId = r['id'] as String;
    final requesterId = r['requester_id'] as String;
    final profile = profileById[requesterId];
    if (profile != null) {
      result.add(UserProfile.fromMap(
        profile,
        friendshipStatus: FriendshipStatus.pending,
        friendshipId: friendshipId,
        isRequester: false,
      ));
    }
  }

  return result;
}

// ── User search ────────────────────────────────────────────────────────────

@riverpod
Future<List<UserProfile>> searchUsers(Ref ref, String query) async {
  if (query.trim().length < 2) return [];

  final userId = supabase.auth.currentUser?.id;

  final rows = await supabase
      .from('public_profiles')
      .select('id, display_name, avatar_url, total_xp')
      .ilike('display_name', '%${query.trim()}%')
      .limit(20);

  // Fetch existing friendships with each result in parallel
  final profiles = (rows as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .where((r) => r['id'] != userId) // exclude self
      .toList();

  if (profiles.isEmpty) return [];

  // Get all friendships relevant to current user
  final friendshipRows = userId != null
      ? await supabase
          .from('friendships')
          .select('id, requester_id, addressee_id, status')
          .or('requester_id.eq.$userId,addressee_id.eq.$userId')
      : [];

  // Build lookup: peer_id → friendship info
  final friendshipByPeer = <String, Map<String, dynamic>>{};
  for (final row in friendshipRows as List) {
    final r = Map<String, dynamic>.from(row as Map);
    final peerId = r['requester_id'] == userId
        ? r['addressee_id'] as String
        : r['requester_id'] as String;
    friendshipByPeer[peerId] = r;
  }

  return profiles.map((profile) {
    final peerId = profile['id'] as String;
    final friendship = friendshipByPeer[peerId];
    FriendshipStatus? status;
    String? friendshipId;
    bool? isRequester;

    if (friendship != null) {
      final statusStr = friendship['status'] as String;
      status = switch (statusStr) {
        'accepted' => FriendshipStatus.accepted,
        'declined' => FriendshipStatus.declined,
        _ => FriendshipStatus.pending,
      };
      friendshipId = friendship['id'] as String;
      isRequester = friendship['requester_id'] == userId;
    }

    return UserProfile.fromMap(
      profile,
      friendshipStatus: status,
      friendshipId: friendshipId,
      isRequester: isRequester,
    );
  }).toList();
}

// ── Single user profile + friendship status ────────────────────────────────

final userFriendshipProvider =
    FutureProvider.autoDispose.family<UserProfile?, String>((ref, peerId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null || userId == peerId) return null;

  final profileData = await supabase
      .from('public_profiles')
      .select('id, display_name, avatar_url, total_xp')
      .eq('id', peerId)
      .maybeSingle();

  if (profileData == null) return null;

  final friendshipRows = await supabase
      .from('friendships')
      .select('id, requester_id, addressee_id, status')
      .or('requester_id.eq.$userId,addressee_id.eq.$userId');

  Map<String, dynamic>? friendship;
  for (final row in friendshipRows as List) {
    final r = Map<String, dynamic>.from(row as Map);
    final a = r['requester_id'] as String;
    final b = r['addressee_id'] as String;
    if ((a == userId && b == peerId) || (a == peerId && b == userId)) {
      friendship = r;
      break;
    }
  }

  FriendshipStatus? status;
  String? friendshipId;
  bool? isRequester;
  if (friendship != null) {
    status = switch (friendship['status'] as String) {
      'accepted' => FriendshipStatus.accepted,
      'declined' => FriendshipStatus.declined,
      _ => FriendshipStatus.pending,
    };
    friendshipId = friendship['id'] as String;
    isRequester = friendship['requester_id'] == userId;
  }

  return UserProfile.fromMap(
    Map<String, dynamic>.from(profileData as Map),
    friendshipStatus: status,
    friendshipId: friendshipId,
    isRequester: isRequester,
  );
});

// ── Friendship actions ─────────────────────────────────────────────────────

@riverpod
class FriendshipNotifier extends _$FriendshipNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> sendRequest(String addresseeId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('friendships').insert({
        'requester_id': userId,
        'addressee_id': addresseeId,
        'status': 'pending',
      });
    });
  }

  Future<void> accept(String friendshipId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId);
    });
  }

  Future<void> decline(String friendshipId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase
          .from('friendships')
          .update({'status': 'declined'})
          .eq('id', friendshipId);
    });
  }

  Future<void> unfriend(String friendshipId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('friendships').delete().eq('id', friendshipId);
    });
  }

  Future<void> cancelRequest(String friendshipId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('friendships').delete().eq('id', friendshipId);
    });
  }
}
