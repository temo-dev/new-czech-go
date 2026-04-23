// Plain Dart models for the course hierarchy.
// No codegen required — keeps Day 9 buildable without running `make gen`.

// ── Enums ─────────────────────────────────────────────────────────────────────

enum ModuleStatus { locked, notStarted, inProgress, completed }

enum LessonStatus { locked, available, inProgress, completed }

enum BlockType { vocab, grammar, reading, listening, speaking, writing }

enum BlockStatus { pending, inProgress, completed }

// ── Course detail (CourseOverviewScreen) ─────────────────────────────────────

class CourseDetail {
  const CourseDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.skill,
    required this.isPremium,
    required this.modules,
    required this.overallProgress,
    this.thumbnailUrl,
    this.instructorName,
    this.instructorBio,
    this.durationDays = 30,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String skill;
  final bool isPremium;
  final List<ModuleSummary> modules;
  final double overallProgress; // 0.0 – 1.0
  final String? thumbnailUrl;
  final String? instructorName;
  final String? instructorBio;
  final int durationDays;
}

// ── Module summary (card in CourseOverviewScreen) ─────────────────────────────

class ModuleSummary {
  const ModuleSummary({
    required this.id,
    required this.courseId,
    required this.title,
    required this.orderIndex,
    required this.lessonCount,
    required this.completedCount,
    required this.status,
    this.isLocked = false,
    this.description,
  });

  final String id;
  final String courseId;
  final String title;
  final int orderIndex;
  final int lessonCount;
  final int completedCount;
  final ModuleStatus status;
  final bool isLocked;
  final String? description;

  double get progressFraction =>
      lessonCount > 0 ? completedCount / lessonCount : 0;

  bool get isCompleted => status == ModuleStatus.completed;
  bool get isInProgress => status == ModuleStatus.inProgress;
}

// ── Module detail (ModuleDetailScreen) ───────────────────────────────────────

class ModuleDetail {
  const ModuleDetail({
    required this.module,
    required this.courseTitle,
    required this.lessons,
  });

  final ModuleSummary module;
  final String courseTitle;
  final List<LessonSummary> lessons;
}

// ── Lesson summary (tile in ModuleDetailScreen) ───────────────────────────────

class LessonSummary {
  const LessonSummary({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.orderIndex,
    required this.status,
    required this.completedBlockCount,
    required this.totalBlockCount,
    this.durationMinutes = 15,
    this.canReplay = false,
  });

  final String id;
  final String moduleId;
  final String title;
  final int orderIndex;
  final LessonStatus status;
  final int completedBlockCount;
  final int totalBlockCount;
  final int durationMinutes;
  final bool canReplay;

  bool get isCompleted => status == LessonStatus.completed;
}

// ── Lesson detail (LessonPlayerScreen) ───────────────────────────────────────

class LessonDetail {
  const LessonDetail({
    required this.lesson,
    required this.courseId,
    required this.courseTitle,
    required this.moduleId,
    required this.moduleTitle,
    required this.blocks,
    required this.isCompleted,
    this.bonusUnlocked = false,
    this.bonusXpCost = 50,
  });

  final LessonInfo lesson;
  final String courseId;
  final String courseTitle;
  final String moduleId;
  final String moduleTitle;
  final List<LessonBlock> blocks;
  final bool isCompleted;
  final bool bonusUnlocked;
  final int bonusXpCost;

  int get completedBlockCount =>
      blocks.where((b) => b.status == BlockStatus.completed).length;

  bool get allBlocksDone =>
      blocks.isNotEmpty && completedBlockCount >= blocks.length;
}

// ── Basic lesson info ─────────────────────────────────────────────────────────

class LessonInfo {
  const LessonInfo({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.skill,
    required this.orderIndex,
    this.description,
    this.durationMinutes = 15,
  });

  final String id;
  final String moduleId;
  final String title;
  final String skill;
  final int orderIndex;
  final String? description;
  final int durationMinutes;
}

// ── Lesson block (card in LessonPlayerScreen) ─────────────────────────────────

class LessonBlock {
  const LessonBlock({
    required this.id,
    required this.lessonId,
    required this.type,
    required this.exerciseIds,
    required this.orderIndex,
    this.status = BlockStatus.pending,
    this.prompt,
  });

  final String id;
  final String lessonId;
  final BlockType type;

  /// Ordered list of exercise IDs belonging to this block.
  final List<String> exerciseIds;
  final int orderIndex;
  final BlockStatus status;

  /// Prompt from the first exercise — used for speaking/writing AI screens.
  final String? prompt;

  bool get hasExercises => exerciseIds.isNotEmpty;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

BlockType blockTypeFromString(String s) => switch (s.toLowerCase()) {
      'vocab' => BlockType.vocab,
      'grammar' => BlockType.grammar,
      'reading' => BlockType.reading,
      'listening' => BlockType.listening,
      'speaking' => BlockType.speaking,
      'writing' => BlockType.writing,
      _ => BlockType.reading,
    };

LessonStatus lessonStatusFromCounts(int completedBlocks, int totalBlocks,
    {bool isLocked = false}) {
  if (isLocked) return LessonStatus.locked;
  if (completedBlocks == 0) return LessonStatus.available;
  if (completedBlocks >= totalBlocks && totalBlocks > 0) {
    return LessonStatus.completed;
  }
  return LessonStatus.inProgress;
}

ModuleStatus moduleStatusFromLessons(
  List<LessonStatus> lessonStatuses, {
  bool isLocked = false,
}) {
  if (isLocked) return ModuleStatus.locked;
  if (lessonStatuses.isEmpty) return ModuleStatus.notStarted;
  if (lessonStatuses.every((status) => status == LessonStatus.completed)) {
    return ModuleStatus.completed;
  }
  if (lessonStatuses.any((status) => status == LessonStatus.inProgress)) {
    return ModuleStatus.inProgress;
  }

  final hasCompleted =
      lessonStatuses.any((status) => status == LessonStatus.completed);
  final hasRemaining = lessonStatuses.any((status) =>
      status == LessonStatus.available || status == LessonStatus.locked);

  if (hasCompleted && hasRemaining) return ModuleStatus.inProgress;
  return ModuleStatus.notStarted;
}
