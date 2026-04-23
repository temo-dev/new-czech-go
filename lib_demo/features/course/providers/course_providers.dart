import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/supabase/supabase_config.dart';
import 'package:app_czech/features/course/models/course_models.dart';
import 'package:app_czech/features/dashboard/providers/dashboard_provider.dart';
import 'package:app_czech/shared/providers/auth_provider.dart';

class _LessonProgressSnapshot {
  const _LessonProgressSnapshot({
    required this.lessonId,
    required this.moduleId,
    required this.completedBlockCount,
    required this.totalBlockCount,
    required this.status,
  });

  final String lessonId;
  final String moduleId;
  final int completedBlockCount;
  final int totalBlockCount;
  final LessonStatus status;

  bool get isCompleted => status == LessonStatus.completed;
}

class _ModuleProgressSnapshot {
  const _ModuleProgressSnapshot({
    required this.lessonCount,
    required this.completedCount,
    required this.status,
  });

  final int lessonCount;
  final int completedCount;
  final ModuleStatus status;
}

// ── Course detail ─────────────────────────────────────────────────────────────

/// Fetches full course with module list and per-module completion progress.
/// courseId can be a UUID or slug — tries both.
final courseDetailProvider = FutureProvider.autoDispose
    .family<CourseDetail, String>((ref, courseId) async {
  final courseRaw = await _fetchCourse(courseId);
  if (courseRaw == null) throw Exception('Không tìm thấy khóa học.');

  final course = Map<String, dynamic>.from(courseRaw as Map);
  final actualId = course['id'] as String;

  // Fetch modules ordered by index
  final modulesRaw = await supabase
      .from('modules')
      .select()
      .eq('course_id', actualId)
      .order('order_index');

  final modules = _toMapList(modulesRaw);
  final moduleIds = modules.map((module) => module['id'] as String).toList();
  final moduleLockById = {
    for (final module in modules)
      module['id'] as String: module['is_locked'] as bool? ?? false,
  };

  final lessons = moduleIds.isEmpty
      ? <Map<String, dynamic>>[]
      : _toMapList(await supabase
          .from('lessons')
          .select('id, module_id')
          .inFilter('module_id', moduleIds));
  final lessonIds = lessons.map((lesson) => lesson['id'] as String).toList();

  final blocks = lessonIds.isEmpty
      ? <Map<String, dynamic>>[]
      : _toMapList(await supabase
          .from('lesson_blocks')
          .select('id, lesson_id')
          .inFilter('lesson_id', lessonIds));

  final userId = supabase.auth.currentUser?.id;
  final progressRows = userId == null || lessonIds.isEmpty
      ? <Map<String, dynamic>>[]
      : _toMapList(await supabase
          .from('user_progress')
          .select('lesson_id, lesson_block_id')
          .eq('user_id', userId)
          .inFilter('lesson_id', lessonIds));

  final lessonSnapshots = _buildLessonProgressSnapshots(
    lessons: lessons,
    blocks: blocks,
    progressRows: progressRows,
    moduleLockById: moduleLockById,
  );

  final modulesData = modules.asMap().entries.map((e) {
    final mm = Map<String, dynamic>.from(e.value as Map);
    final mId = mm['id'] as String;
    final moduleLessons = lessonSnapshots.values
        .where((lesson) => lesson.moduleId == mId)
        .toList();
    final progress = _buildModuleProgressSnapshot(
      lessons: moduleLessons,
      isLocked: mm['is_locked'] as bool? ?? false,
    );

    return ModuleSummary(
      id: mId,
      courseId: actualId,
      title: mm['title'] as String,
      orderIndex: mm['order_index'] as int? ?? e.key,
      lessonCount: progress.lessonCount,
      completedCount: progress.completedCount,
      status: progress.status,
      isLocked: mm['is_locked'] as bool? ?? false,
      description: mm['description'] as String?,
    );
  }).toList();

  final total = modulesData.fold<int>(0, (s, m) => s + m.lessonCount);
  final done = modulesData.fold<int>(0, (s, m) => s + m.completedCount);

  return CourseDetail(
    id: actualId,
    slug: course['slug'] as String? ?? courseId,
    title: course['title'] as String,
    description: course['description'] as String? ?? '',
    skill: course['skill'] as String? ?? '',
    isPremium: course['is_premium'] as bool? ?? false,
    thumbnailUrl: course['thumbnail_url'] as String?,
    modules: modulesData,
    overallProgress: total > 0 ? done / total : 0,
    instructorName: course['instructor_name'] as String?,
    instructorBio: course['instructor_bio'] as String?,
    durationDays: course['duration_days'] as int? ?? 30,
  );
});

Future<dynamic> _fetchCourse(String courseId) async {
  final byId =
      await supabase.from('courses').select().eq('id', courseId).maybeSingle();
  if (byId != null) return byId;
  return supabase.from('courses').select().eq('slug', courseId).maybeSingle();
}

// ── Module detail ─────────────────────────────────────────────────────────────

/// Fetches module with its lesson list and per-lesson status.
final moduleDetailProvider = FutureProvider.autoDispose
    .family<ModuleDetail, String>((ref, moduleId) async {
  final userId = supabase.auth.currentUser?.id;

  // Fetch module
  final moduleRaw =
      await supabase.from('modules').select().eq('id', moduleId).maybeSingle();
  if (moduleRaw == null) throw Exception('Không tìm thấy module.');

  final module = Map<String, dynamic>.from(moduleRaw as Map);
  final courseId = module['course_id'] as String;

  // Fetch course title for breadcrumb
  final courseRaw = await supabase
      .from('courses')
      .select('title')
      .eq('id', courseId)
      .single();
  final courseTitle = (courseRaw as Map)['title'] as String? ?? '';

  // Fetch lessons ordered
  final lessonsRaw = await supabase
      .from('lessons')
      .select()
      .eq('module_id', moduleId)
      .order('order_index');
  final lessons = _toMapList(lessonsRaw);
  final lessonIds = lessons.map((lesson) => lesson['id'] as String).toList();
  final blocks = lessonIds.isEmpty
      ? <Map<String, dynamic>>[]
      : _toMapList(await supabase
          .from('lesson_blocks')
          .select('id, lesson_id')
          .inFilter('lesson_id', lessonIds));
  final progressRows = userId == null || lessonIds.isEmpty
      ? <Map<String, dynamic>>[]
      : _toMapList(await supabase
          .from('user_progress')
          .select('lesson_id, lesson_block_id')
          .eq('user_id', userId)
          .inFilter('lesson_id', lessonIds));

  final isModuleLocked = module['is_locked'] as bool? ?? false;
  final lessonSnapshots = _buildLessonProgressSnapshots(
    lessons: lessons,
    blocks: blocks,
    progressRows: progressRows,
    moduleLockById: {moduleId: isModuleLocked},
  );

  final lessonItems = lessons.asMap().entries.map((e) {
    final lm = Map<String, dynamic>.from(e.value as Map);
    final lId = lm['id'] as String;
    final snapshot = lessonSnapshots[lId]!;
    return LessonSummary(
      id: lId,
      moduleId: moduleId,
      title: lm['title'] as String,
      orderIndex: lm['order_index'] as int? ?? e.key,
      status: snapshot.status,
      completedBlockCount: snapshot.completedBlockCount,
      totalBlockCount: snapshot.totalBlockCount,
      durationMinutes: lm['duration_minutes'] as int? ?? 15,
      canReplay: snapshot.isCompleted,
    );
  }).toList();
  final moduleProgress = _buildModuleProgressSnapshot(
    lessons: lessonSnapshots.values,
    isLocked: isModuleLocked,
  );

  return ModuleDetail(
    module: ModuleSummary(
      id: moduleId,
      courseId: courseId,
      title: module['title'] as String,
      orderIndex: module['order_index'] as int? ?? 0,
      lessonCount: moduleProgress.lessonCount,
      completedCount: moduleProgress.completedCount,
      status: moduleProgress.status,
      isLocked: isModuleLocked,
      description: module['description'] as String?,
    ),
    courseTitle: courseTitle,
    lessons: lessonItems,
  );
});

// ── Lesson detail ─────────────────────────────────────────────────────────────

/// Fetches lesson with its 6 blocks and per-block completion status.
final lessonDetailProvider = FutureProvider.autoDispose
    .family<LessonDetail, String>((ref, lessonId) async {
  final userId = supabase.auth.currentUser?.id;

  // Fetch lesson
  final lessonRaw =
      await supabase.from('lessons').select().eq('id', lessonId).maybeSingle();
  if (lessonRaw == null) throw Exception('Không tìm thấy bài học.');

  final lesson = Map<String, dynamic>.from(lessonRaw as Map);
  final moduleId = lesson['module_id'] as String;

  // Fetch module + course for breadcrumbs
  final moduleRaw = await supabase
      .from('modules')
      .select('id, course_id, title')
      .eq('id', moduleId)
      .single();
  final moduleMeta = Map<String, dynamic>.from(moduleRaw as Map);
  final courseId = moduleMeta['course_id'] as String;

  final courseRaw = await supabase
      .from('courses')
      .select('id, title, skill')
      .eq('id', courseId)
      .single();
  final courseMeta = Map<String, dynamic>.from(courseRaw as Map);

  // Fetch blocks ordered
  final blocksRaw = await supabase
      .from('lesson_blocks')
      .select('id, lesson_id, type, order_index')
      .eq('lesson_id', lessonId)
      .order('order_index');

  // Fetch exercises per block via junction table (includes first exercise prompt)
  final blockIds =
      (blocksRaw as List).map((b) => (b as Map)['id'] as String).toList();

  final Map<String, List<String>> exerciseIdsPerBlock = {};
  final Map<String, String?> promptPerBlock = {};

  if (blockIds.isNotEmpty) {
    final blockExercisesRaw = await supabase
        .from('lesson_block_exercises')
        .select('block_id, exercise_id, exercises(content_json)')
        .inFilter('block_id', blockIds)
        .order('order_index');

    for (final row in (blockExercisesRaw as List)) {
      final rm = Map<String, dynamic>.from(row as Map);
      final bId = rm['block_id'] as String;
      final exId = rm['exercise_id'] as String;
      exerciseIdsPerBlock.putIfAbsent(bId, () => []).add(exId);
      // Capture prompt from first exercise only
      if (!promptPerBlock.containsKey(bId)) {
        final exData = rm['exercises'] as Map?;
        final cj = exData?['content_json'] as Map?;
        promptPerBlock[bId] = cj?['prompt'] as String?;
      }
    }
  }

  // Fetch user block progress
  final Set<String> completedBlockIds = {};
  if (userId != null && blockIds.isNotEmpty) {
    final progressRaw = await supabase
        .from('user_progress')
        .select('lesson_block_id')
        .eq('user_id', userId)
        .inFilter('lesson_block_id', blockIds);

    for (final p in (progressRaw as List)) {
      final pm = Map<String, dynamic>.from(p as Map);
      completedBlockIds.add(pm['lesson_block_id'] as String);
    }
  }

  final blocks = (blocksRaw as List).asMap().entries.map((e) {
    final bm = Map<String, dynamic>.from(e.value as Map);
    final blockId = bm['id'] as String;
    return LessonBlock(
      id: blockId,
      lessonId: lessonId,
      type: blockTypeFromString(bm['type'] as String? ?? 'reading'),
      exerciseIds: exerciseIdsPerBlock[blockId] ?? [],
      orderIndex: bm['order_index'] as int? ?? e.key + 1,
      status: completedBlockIds.contains(blockId)
          ? BlockStatus.completed
          : BlockStatus.pending,
      prompt: promptPerBlock[blockId],
    );
  }).toList();

  final allDone = blocks.isNotEmpty &&
      blocks.every((b) => b.status == BlockStatus.completed);

  return LessonDetail(
    lesson: LessonInfo(
      id: lessonId,
      moduleId: moduleId,
      title: lesson['title'] as String,
      skill: courseMeta['skill'] as String? ?? '',
      orderIndex: lesson['order_index'] as int? ?? 0,
      description: lesson['description'] as String?,
      durationMinutes: lesson['duration_minutes'] as int? ?? 15,
    ),
    courseId: courseId,
    courseTitle: courseMeta['title'] as String? ?? '',
    moduleId: moduleId,
    moduleTitle: moduleMeta['title'] as String? ?? '',
    blocks: blocks,
    isCompleted: allDone,
    bonusUnlocked: lesson['bonus_unlocked'] as bool? ?? allDone,
    bonusXpCost: lesson['bonus_xp_cost'] as int? ?? 50,
  );
});

// ── Mark block complete ───────────────────────────────────────────────────────

/// Upserts a user_progress row to mark a lesson block as done.
/// Call from practiceSessionNotifier after a successful exercise submission.
/// After calling, invalidate [lessonDetailProvider(lessonId)] to refresh UI.
Future<void> markBlockComplete({
  required String lessonId,
  required String lessonBlockId,
}) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  final existing = await supabase
      .from('user_progress')
      .select('id')
      .eq('user_id', userId)
      .eq('lesson_block_id', lessonBlockId)
      .maybeSingle();
  if (existing != null) return;

  await supabase.from('user_progress').insert({
    'user_id': userId,
    'lesson_id': lessonId,
    'lesson_block_id': lessonBlockId,
    'completed_at': DateTime.now().toIso8601String(),
  });
}

Future<void> resetLessonProgress({
  required String lessonId,
}) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  await supabase
      .from('user_progress')
      .delete()
      .eq('user_id', userId)
      .eq('lesson_id', lessonId);
}

void refreshCourseProgressProviders(
  WidgetRef ref, {
  required String courseId,
  required String moduleId,
  required String lessonId,
}) {
  ref.invalidate(lessonDetailProvider(lessonId));
  ref.invalidate(moduleDetailProvider(moduleId));
  ref.invalidate(courseDetailProvider(courseId));
  ref.invalidate(dashboardProvider);
}

// ── Course list (catalog) ─────────────────────────────────────────────────────

/// Fetches all available courses ordered by skill.
final courseListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data =
      await supabase.from('courses').select().order('skill').order('title');
  return (data as List)
      .map((c) => Map<String, dynamic>.from(c as Map))
      .toList();
});

// ── Unlock bonus ──────────────────────────────────────────────────────────────

/// Calls the unlock_lesson_bonus RPC: deducts XP and marks lesson.bonus_unlocked = true.
/// Throws 'insufficient_xp' if user doesn't have enough XP.
/// After success, invalidates lessonDetailProvider and currentUserProvider.
final unlockBonusProvider =
    FutureProvider.autoDispose.family<void, String>((ref, lessonId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) throw Exception('Chưa đăng nhập.');

  await supabase.rpc('unlock_lesson_bonus', params: {
    'p_lesson_id': lessonId,
    'p_user_id': userId,
  });

  ref.invalidate(lessonDetailProvider(lessonId));
  ref.invalidate(currentUserProvider);
});

List<Map<String, dynamic>> _toMapList(dynamic rows) {
  return (rows as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
}

Map<String, _LessonProgressSnapshot> _buildLessonProgressSnapshots({
  required List<Map<String, dynamic>> lessons,
  required List<Map<String, dynamic>> blocks,
  required List<Map<String, dynamic>> progressRows,
  required Map<String, bool> moduleLockById,
}) {
  final totalBlocksPerLesson = <String, int>{};
  for (final block in blocks) {
    final lessonId = block['lesson_id'] as String;
    totalBlocksPerLesson[lessonId] = (totalBlocksPerLesson[lessonId] ?? 0) + 1;
  }

  final completedBlockIdsPerLesson = <String, Set<String>>{};
  for (final row in progressRows) {
    final lessonId = row['lesson_id'] as String;
    final blockId = row['lesson_block_id'] as String;
    completedBlockIdsPerLesson.putIfAbsent(lessonId, () => <String>{}).add(
          blockId,
        );
  }

  final snapshots = <String, _LessonProgressSnapshot>{};
  for (final lesson in lessons) {
    final lessonId = lesson['id'] as String;
    final moduleId = lesson['module_id'] as String;
    final completedBlocks = completedBlockIdsPerLesson[lessonId]?.length ?? 0;
    final totalBlocks = totalBlocksPerLesson[lessonId] ?? 0;
    snapshots[lessonId] = _LessonProgressSnapshot(
      lessonId: lessonId,
      moduleId: moduleId,
      completedBlockCount: completedBlocks,
      totalBlockCount: totalBlocks,
      status: lessonStatusFromCounts(
        completedBlocks,
        totalBlocks,
        isLocked: moduleLockById[moduleId] ?? false,
      ),
    );
  }
  return snapshots;
}

_ModuleProgressSnapshot _buildModuleProgressSnapshot({
  required Iterable<_LessonProgressSnapshot> lessons,
  required bool isLocked,
}) {
  final lessonList = lessons.toList();
  return _ModuleProgressSnapshot(
    lessonCount: lessonList.length,
    completedCount: lessonList.where((lesson) => lesson.isCompleted).length,
    status: moduleStatusFromLessons(
      lessonList.map((lesson) => lesson.status).toList(),
      isLocked: isLocked,
    ),
  );
}
