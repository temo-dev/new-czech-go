// V20 — typed wire models for GET /v1/users/me/progress.
//
// Mirrors `backend/internal/contracts/progress.go`. Bands and weights are
// passed through verbatim so the client never hardcodes thresholds.

class UserProgress {
  const UserProgress({
    required this.overallProgress,
    required this.overallBand,
    required this.skills,
    required this.bands,
    required this.weights,
  });

  factory UserProgress.fromApiJson(Map<String, dynamic> json) {
    final skillsRaw = (json['skills'] as List?) ?? const [];
    final weightsRaw = (json['weights'] as Map?) ?? const {};
    return UserProgress(
      overallProgress: _asDouble(json['overall_progress']),
      overallBand: (json['overall_band'] as String?) ?? 'needs_work',
      skills: skillsRaw
          .whereType<Map<String, dynamic>>()
          .map(SkillProgress.fromApiJson)
          .toList(growable: false),
      bands: ProgressBands.fromApiJson(
        _asMap(json['bands']),
      ),
      weights: {
        for (final entry in weightsRaw.entries)
          if (entry.key is String)
            entry.key as String: (entry.value as num?)?.toInt() ?? 0,
      },
    );
  }

  factory UserProgress.empty() => const UserProgress(
        overallProgress: 0,
        overallBand: 'needs_work',
        skills: [],
        bands: ProgressBands(needsWork: 0.40, solid: 0.70, ready: 0.85),
        weights: {},
      );

  final double overallProgress;
  final String overallBand;
  final List<SkillProgress> skills;
  final ProgressBands bands;
  final Map<String, int> weights;

  bool get isEmpty => skills.isEmpty;

  Map<String, dynamic> toJson() => {
        'overall_progress': overallProgress,
        'overall_band': overallBand,
        'skills': skills.map((s) => s.toJson()).toList(),
        'bands': bands.toJson(),
        'weights': weights,
      };
}

class SkillProgress {
  const SkillProgress({
    required this.skillKind,
    required this.mastery,
    required this.band,
    required this.attemptsCount,
    required this.modules,
    this.lastAttemptAt,
  });

  factory SkillProgress.fromApiJson(Map<String, dynamic> json) {
    final modulesRaw = (json['modules'] as List?) ?? const [];
    return SkillProgress(
      skillKind: (json['skill_kind'] as String?) ?? '',
      mastery: _asDouble(json['mastery']),
      band: (json['band'] as String?) ?? 'needs_work',
      attemptsCount: (json['attempts_count'] as num?)?.toInt() ?? 0,
      lastAttemptAt: _parseDate(json['last_attempt_at']),
      modules: modulesRaw
          .whereType<Map<String, dynamic>>()
          .map(ModuleProgress.fromApiJson)
          .toList(growable: false),
    );
  }

  final String skillKind;
  final double mastery;
  final String band;
  final int attemptsCount;
  final DateTime? lastAttemptAt;
  final List<ModuleProgress> modules;

  Map<String, dynamic> toJson() => {
        'skill_kind': skillKind,
        'mastery': mastery,
        'band': band,
        'attempts_count': attemptsCount,
        if (lastAttemptAt != null)
          'last_attempt_at': lastAttemptAt!.toUtc().toIso8601String(),
        'modules': modules.map((m) => m.toJson()).toList(),
      };
}

class ModuleProgress {
  const ModuleProgress({
    required this.moduleId,
    required this.mastery,
    required this.band,
    required this.attemptsCount,
    this.lastAttemptAt,
  });

  factory ModuleProgress.fromApiJson(Map<String, dynamic> json) =>
      ModuleProgress(
        moduleId: (json['module_id'] as String?) ?? '',
        mastery: _asDouble(json['mastery']),
        band: (json['band'] as String?) ?? 'needs_work',
        attemptsCount: (json['attempts_count'] as num?)?.toInt() ?? 0,
        lastAttemptAt: _parseDate(json['last_attempt_at']),
      );

  final String moduleId;
  final double mastery;
  final String band;
  final int attemptsCount;
  final DateTime? lastAttemptAt;

  Map<String, dynamic> toJson() => {
        'module_id': moduleId,
        'mastery': mastery,
        'band': band,
        'attempts_count': attemptsCount,
        if (lastAttemptAt != null)
          'last_attempt_at': lastAttemptAt!.toUtc().toIso8601String(),
      };
}

class ProgressBands {
  const ProgressBands({
    required this.needsWork,
    required this.solid,
    required this.ready,
  });

  factory ProgressBands.fromApiJson(Map<String, dynamic> json) => ProgressBands(
        needsWork: _asDouble(json['needs_work']),
        solid: _asDouble(json['solid']),
        ready: _asDouble(json['ready']),
      );

  final double needsWork;
  final double solid;
  final double ready;

  Map<String, dynamic> toJson() => {
        'needs_work': needsWork,
        'solid': solid,
        'ready': ready,
      };
}

double _asDouble(Object? v) {
  if (v is num) return v.toDouble();
  return 0.0;
}

Map<String, dynamic> _asMap(Object? v) {
  if (v is Map) {
    return {
      for (final entry in v.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }
  return const {};
}

DateTime? _parseDate(Object? v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v)?.toUtc();
}
