import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/features/chat/models/chat_models.dart';

part 'chat_providers.g.dart';

// ── Inbox conversations ────────────────────────────────────────────────────

@riverpod
Stream<List<DmConversation>> conversations(Ref ref) {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  final controller = StreamController<List<DmConversation>>();

  Future<void> reload() async {
    try {
      final data = await _fetchConversations(userId);
      if (!controller.isClosed) controller.add(data);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  // Initial load
  reload();

  // Subscribe to Realtime — re-fetch on any dm_messages or dm_members change
  final channel = supabase
      .channel('inbox_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'dm_messages',
        callback: (_) => reload(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'dm_members',
        callback: (_) => reload(),
      )
      .subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
}

Future<List<DmConversation>> _fetchConversations(String userId) async {
  // 1. My memberships
  final myMemberships = await supabase
      .from('dm_members')
      .select('room_id, last_read_at')
      .eq('user_id', userId);

  if ((myMemberships as List).isEmpty) return [];

  final roomIds =
      myMemberships.map((m) => m['room_id'] as String).toList();

  // 2. Peer members (no embedded join — dm_members.user_id FK points to auth.users, not profiles)
  final peerRows = await supabase
      .from('dm_members')
      .select('room_id, user_id')
      .inFilter('room_id', roomIds)
      .neq('user_id', userId);

  final peerUserIds = (peerRows as List)
      .map((r) => r['user_id'] as String)
      .toSet()
      .toList();

  final profileRows = peerUserIds.isNotEmpty
      ? await supabase
          .from('public_profiles')
          .select('id, display_name, avatar_url')
          .inFilter('id', peerUserIds)
      : [];

  final profileById = <String, Map<String, dynamic>>{
    for (final p in (profileRows as List))
      (p as Map)['id'] as String: Map<String, dynamic>.from(p),
  };

  final peerByRoom = <String, Map<String, dynamic>>{};
  for (final row in peerRows) {
    final r = Map<String, dynamic>.from(row as Map);
    final profile = profileById[r['user_id'] as String];
    peerByRoom[r['room_id'] as String] = {
      ...r,
      'profiles': profile,
    };
  }

  // 3. Last message + unread count per room (parallel)
  final futures = roomIds.map((roomId) async {
    final lastMsgData = await supabase
        .from('dm_messages')
        .select(
            'id, room_id, sender_id, message_type, body, attachment_name, attachment_url, attachment_size, attachment_mime, created_at')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final myMembership = myMemberships.firstWhere(
      (m) => m['room_id'] == roomId,
      orElse: () => {'last_read_at': null},
    );
    final lastReadAt = myMembership['last_read_at'] as String?;

    int unreadCount = 0;
    if (lastReadAt != null) {
      final unreadRes = await supabase
          .from('dm_messages')
          .select('id')
          .eq('room_id', roomId)
          .neq('sender_id', userId)
          .gt('created_at', lastReadAt);
      unreadCount = (unreadRes as List).length;
    } else {
      final allRes = await supabase
          .from('dm_messages')
          .select('id')
          .eq('room_id', roomId)
          .neq('sender_id', userId);
      unreadCount = (allRes as List).length;
    }

    return (roomId: roomId, lastMsg: lastMsgData, unreadCount: unreadCount);
  });

  final roomData = await Future.wait(futures);

  // 4. Assemble conversations
  final convs = <DmConversation>[];
  for (final data in roomData) {
    final peer = peerByRoom[data.roomId];
    if (peer == null) continue;

    final profile = peer['profiles'] as Map<String, dynamic>?;
    ChatMessage? lastMessage;
    if (data.lastMsg != null) {
      final raw = Map<String, dynamic>.from(data.lastMsg as Map);
      raw['room_id'] = data.roomId;
      lastMessage = ChatMessage.fromMap(raw);
    }

    convs.add(DmConversation(
      roomId: data.roomId,
      peerId: peer['user_id'] as String,
      peerName: profile?['display_name'] as String? ?? 'Người dùng',
      peerAvatarUrl: profile?['avatar_url'] as String?,
      lastMessage: lastMessage,
      unreadCount: data.unreadCount,
      lastActivityAt: lastMessage?.createdAt,
    ));
  }

  convs.sort((a, b) {
    final aTime = a.lastActivityAt;
    final bTime = b.lastActivityAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });

  return convs;
}

// ── Messages in a room ─────────────────────────────────────────────────────

@riverpod
Stream<List<ChatMessage>> chatMessages(Ref ref, String roomId) {
  final controller = StreamController<List<ChatMessage>>();

  Future<void> reload() async {
    try {
      final data = await _fetchMessages(roomId);
      if (!controller.isClosed) controller.add(data);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  reload();

  final channel = supabase
      .channel('messages_$roomId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'dm_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
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

Future<List<ChatMessage>> _fetchMessages(String roomId) async {
  final rows = await supabase
      .from('dm_messages')
      .select(
          'id, room_id, sender_id, message_type, body, attachment_url, attachment_name, attachment_size, attachment_mime, created_at')
      .eq('room_id', roomId)
      .order('created_at', ascending: true)
      .limit(100);

  final messages = (rows as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();

  if (messages.isEmpty) return [];

  final senderIds = messages
      .map((m) => m['sender_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();

  final profileRows = await supabase
      .from('public_profiles')
      .select('id, display_name, avatar_url')
      .inFilter('id', senderIds);

  final profileById = <String, Map<String, dynamic>>{
    for (final p in (profileRows as List))
      (p as Map)['id'] as String: Map<String, dynamic>.from(p),
  };

  return messages.map((m) {
    final profile = profileById[m['sender_id'] as String?];
    return ChatMessage.fromMap({
      ...m,
      'sender': profile,
    });
  }).toList();
}

// ── Unread count (derived from conversations) ──────────────────────────────

@riverpod
int unreadCount(Ref ref) {
  final convs = ref.watch(conversationsProvider);
  return convs.maybeWhen(
    data: (list) => list.fold(0, (sum, c) => sum + c.unreadCount),
    orElse: () => 0,
  );
}

// ── Chat actions ───────────────────────────────────────────────────────────

@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  AsyncValue<void> build(String roomId) => const AsyncData(null);

  Future<void> sendMessage(String body) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.from('dm_messages').insert({
        'room_id': roomId,
        'sender_id': userId,
        'message_type': 'text',
        'body': body,
      });
    });
  }

  Future<void> markRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase
        .from('dm_members')
        .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }
}

// ── Open DM (find or create room) ─────────────────────────────────────────

@riverpod
class OpenDmNotifier extends _$OpenDmNotifier {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  /// Returns the room ID, or throws if users are not friends.
  Future<String?> open(String peerId) async {
    state = const AsyncLoading();
    return AsyncValue.guard(() async {
      final result = await supabase.rpc(
        'find_or_create_dm',
        params: {'other_user_id': peerId},
      );
      final roomId = result as String?;
      state = AsyncData(roomId);
      return roomId;
    }).then((v) {
      state = v;
      return v.valueOrNull;
    });
  }
}

// ── Attachment upload ──────────────────────────────────────────────────────

@riverpod
class AttachmentUploadNotifier extends _$AttachmentUploadNotifier {
  @override
  AsyncValue<void> build(String roomId) => const AsyncData(null);

  /// Picks a file and uploads it, then inserts the message row.
  Future<void> upload(PlatformFile file) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Không đọc được file');

      final mime = file.extension != null
          ? _mimeFromExtension(file.extension!)
          : 'application/octet-stream';
      final isImage = mime.startsWith('image/');
      final messageType = isImage ? 'image' : 'file';

      final uniqueName = '${const Uuid().v4()}_${file.name}';
      final path = '$userId/$roomId/$uniqueName';

      await supabase.storage
          .from('chat-attachments')
          .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));

      final publicUrl =
          supabase.storage.from('chat-attachments').getPublicUrl(path);

      await supabase.from('dm_messages').insert({
        'room_id': roomId,
        'sender_id': userId,
        'message_type': messageType,
        'attachment_url': publicUrl,
        'attachment_name': file.name,
        'attachment_size': file.size,
        'attachment_mime': mime,
      });
    });
  }

  static String _mimeFromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }
}
