import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class TeacherReview {
  const TeacherReview({
    required this.id,
    required this.skill,
    required this.status,
    required this.createdAt,
    this.previewText,
    this.unreadCount = 0,
  });

  final String id;
  final String skill;      // writing | speaking
  final String status;     // pending | reviewed | closed
  final DateTime createdAt;
  final String? previewText;
  final int unreadCount;
}

class TeacherComment {
  const TeacherComment({
    required this.id,
    required this.reviewId,
    required this.body,
    required this.createdAt,
    required this.isTeacher,
    this.authorName,
  });

  final String id;
  final String reviewId;
  final String body;
  final DateTime createdAt;
  final bool isTeacher;
  final String? authorName;
}

// ── Inbox provider ────────────────────────────────────────────────────────────

final teacherInboxProvider =
    FutureProvider.autoDispose<List<TeacherReview>>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final raw = await supabase
      .from('teacher_reviews')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(30);

  return (raw as List).map((r) {
    final rm = Map<String, dynamic>.from(r as Map);
    return TeacherReview(
      id: rm['id'] as String,
      skill: rm['skill'] as String? ?? 'writing',
      status: rm['status'] as String? ?? 'pending',
      createdAt:
          DateTime.tryParse(rm['created_at'] as String? ?? '') ??
              DateTime.now(),
      previewText: rm['preview_text'] as String?,
      unreadCount: rm['unread_count'] as int? ?? 0,
    );
  }).toList();
});

// ── Thread provider ───────────────────────────────────────────────────────────

final teacherFeedbackProvider = FutureProvider.autoDispose
    .family<List<TeacherComment>, String>((ref, reviewId) async {
  final raw = await supabase
      .from('teacher_comments')
      .select()
      .eq('review_id', reviewId)
      .order('created_at');

  return (raw as List).map((r) {
    final rm = Map<String, dynamic>.from(r as Map);
    return TeacherComment(
      id: rm['id'] as String,
      reviewId: reviewId,
      body: rm['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(rm['created_at'] as String? ?? '') ??
              DateTime.now(),
      isTeacher: rm['is_teacher'] as bool? ?? false,
      authorName: rm['author_name'] as String?,
    );
  }).toList();
});
