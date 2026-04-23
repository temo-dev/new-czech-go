enum FriendshipStatus { pending, accepted, declined }

/// A friendship record between two users.
class Friendship {
  const Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;

  factory Friendship.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'pending';
    final status = switch (statusStr) {
      'accepted' => FriendshipStatus.accepted,
      'declined' => FriendshipStatus.declined,
      _ => FriendshipStatus.pending,
    };
    return Friendship(
      id: map['id'] as String,
      requesterId: map['requester_id'] as String,
      addresseeId: map['addressee_id'] as String,
      status: status,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Minimal user profile used in friend lists and search results.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.totalXp,
    this.friendshipStatus,
    this.friendshipId,
    this.isRequester,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final int totalXp;

  /// null = no relationship with current user
  final FriendshipStatus? friendshipStatus;
  final String? friendshipId;

  /// true = current user sent the request; false = current user received it
  final bool? isRequester;

  bool get isFriend => friendshipStatus == FriendshipStatus.accepted;
  bool get isPending => friendshipStatus == FriendshipStatus.pending;

  factory UserProfile.fromMap(
    Map<String, dynamic> map, {
    FriendshipStatus? friendshipStatus,
    String? friendshipId,
    bool? isRequester,
  }) {
    return UserProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String? ?? 'Người dùng',
      avatarUrl: map['avatar_url'] as String?,
      totalXp: map['total_xp'] as int? ?? 0,
      friendshipStatus: friendshipStatus,
      friendshipId: friendshipId,
      isRequester: isRequester,
    );
  }
}
