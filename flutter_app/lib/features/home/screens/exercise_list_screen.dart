import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/skill_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../exercise/screens/exercise_screen.dart' as exercise_feature;
import '../../exercise/screens/listening_exercise_screen.dart';
import '../../exercise/screens/reading_exercise_screen.dart';
import '../../exercise/screens/vocab_grammar_exercise_screen.dart';
import '../../exercise/screens/writing_exercise_screen.dart';

class ExerciseListScreen extends StatefulWidget {
  const ExerciseListScreen({
    super.key,
    required this.client,
    required this.moduleId,
    required this.skillKind,
  });
  final ApiClient client;
  final String moduleId;
  final String skillKind;

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  List<ExerciseSummary> _exercises = [];
  bool _loading = true;
  String? _error;
  String? _filterTag; // null = all, '1'/'2'/'3'/'4' = filter by uloha

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await widget.client.listModuleExercises(widget.moduleId, skillKind: widget.skillKind);
      if (!mounted) return;
      setState(() {
        _exercises = raw.map((e) => ExerciseSummary.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  Future<void> _openExercise(BuildContext context, ExerciseSummary exercise, {bool replace = false}) async {
    final ExerciseDetail detail;
    try {
      detail = ExerciseDetail.fromJson(await widget.client.getExercise(exercise.id));
    } catch (_) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        // ignore: use_build_context_synchronously
        SnackBar(content: Text(AppLocalizations.of(context).exerciseOpenError)),
      );
      return;
    }
    if (!mounted) return;

    // Route reading exercises to ReadingExerciseScreen.
    if (detail.isCteni) {
      // ignore: use_build_context_synchronously
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReadingExerciseScreen(client: widget.client, detail: detail),
        ),
      );
      return;
    }

    // Route listening exercises to ListeningExerciseScreen.
    if (detail.isPoslech) {
      // ignore: use_build_context_synchronously
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListeningExerciseScreen(client: widget.client, detail: detail),
        ),
      );
      return;
    }

    // Route writing exercises to WritingExerciseScreen.
    if (detail.isPsani1 || detail.isPsani2) {
      // ignore: use_build_context_synchronously
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WritingExerciseScreen(client: widget.client, detail: detail),
        ),
      );
      return;
    }

    final idx = _exercises.indexOf(exercise);
    final next = (idx >= 0 && idx + 1 < _exercises.length) ? _exercises[idx + 1] : null;

    // Route V6 vocab/grammar exercises to VocabGrammarExerciseScreen.
    // Use pushReplacement for subsequent exercises so the stack stays flat:
    //   ExerciseList → CurrentExercise (never deeper).
    // Without this, pop from the last exercise returns to previous result screens
    // which still show "Bài tiếp theo →" → infinite loop.
    if (detail.isVocabGrammar) {
      if (!mounted) return;
      final route = MaterialPageRoute(
        builder: (ctx) => VocabGrammarExerciseScreen(
          client: widget.client,
          detail: detail,
          onOpenNext: next == null ? null : () => _openExercise(ctx, next, replace: true),
        ),
      );
      // ignore: use_build_context_synchronously
      if (replace) {
        // ignore: use_build_context_synchronously
        await Navigator.of(context).pushReplacement(route);
      } else {
        // ignore: use_build_context_synchronously
        await Navigator.of(context).push(route);
      }
      return;
    }
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => exercise_feature.ExerciseScreen(
          client: widget.client,
          detail: detail,
          onOpenNext: next == null ? null : () => _openExercise(ctx, next),
        ),
      ),
    );
  }

  String _ulohaTag(String exerciseType) {
    if (exerciseType.startsWith('uloha_1')) return 'ÚLOHA 1';
    if (exerciseType.startsWith('uloha_2')) return 'ÚLOHA 2';
    if (exerciseType.startsWith('uloha_3')) return 'ÚLOHA 3';
    if (exerciseType.startsWith('uloha_4')) return 'ÚLOHA 4';
    return exerciseType.split('_').take(2).join(' ').toUpperCase();
  }

  static bool _exerciseMatchesSkillKind(String exerciseType, String skillKind) {
    switch (skillKind) {
      case 'noi':      return exerciseType.startsWith('uloha_');
      case 'viet':     return exerciseType.startsWith('psani_');
      case 'nghe':     return exerciseType.startsWith('poslech_');
      case 'doc':      return exerciseType.startsWith('cteni_');
      case 'tu_vung':  return ['quizcard_basic', 'matching', 'fill_blank', 'choice_word'].contains(exerciseType);
      case 'ngu_phap': return ['matching', 'fill_blank', 'choice_word'].contains(exerciseType);
      default:         return true;
    }
  }

  List<ExerciseSummary> get _filtered {
    final kindFiltered = _exercises
        .where((e) => _exerciseMatchesSkillKind(e.exerciseType, widget.skillKind))
        .toList();
    if (_filterTag == null) return kindFiltered;
    if (widget.skillKind == 'noi') {
      return kindFiltered.where((e) => e.exerciseType.startsWith('uloha_$_filterTag')).toList();
    }
    // vocab/grammar: filter by exact exercise type
    return kindFiltered.where((e) => e.exerciseType == _filterTag).toList();
  }

  // Per-type metadata for vocab/grammar exercise cards
  static _ExerciseTypeStyle _typeStyle(String exerciseType) {
    switch (exerciseType) {
      case 'quizcard_basic':
        return const _ExerciseTypeStyle(
          label: 'FLASHCARD',
          icon: Icons.style_rounded,
          color: Color(0xFF059669),
          bg: Color(0xFFD1FAE5),
        );
      case 'matching':
        return const _ExerciseTypeStyle(
          label: 'GHÉP ĐÔI',
          icon: Icons.compare_arrows_rounded,
          color: Color(0xFF7C3AED),
          bg: Color(0xFFEDE9FE),
        );
      case 'fill_blank':
        return const _ExerciseTypeStyle(
          label: 'ĐIỀN TỪ',
          icon: Icons.edit_outlined,
          color: Color(0xFF0369A1),
          bg: Color(0xFFE0F2FE),
        );
      case 'choice_word':
        return const _ExerciseTypeStyle(
          label: 'CHỌN TỪ',
          icon: Icons.check_circle_outline_rounded,
          color: Color(0xFF0F3D3A),
          bg: Color(0xFFD9E5E3),
        );
      default:
        return const _ExerciseTypeStyle(
          label: 'BÀI TẬP',
          icon: Icons.school_rounded,
          color: Color(0xFF4D4540),
          bg: Color(0xFFF5F0EA),
        );
    }
  }

  int _estimatedMin(ExerciseSummary ex) {
    // rough estimate based on type
    if (ex.exerciseType.contains('uloha_2')) return 8;
    if (ex.exerciseType.contains('uloha_3')) return 10;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = AppSpacing.pagePaddingH(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(h, AppSpacing.x3, h, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back, size: 22),
                ),
                const Spacer(),
                // Only show speaking progress link for noi skill
                if (widget.skillKind == 'noi')
                  Text(l.exerciseListProgressLink,
                      style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w600)),
              ]),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(h, AppSpacing.x4, h, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.skillKind == 'noi')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(l.exerciseListFlowBadge,
                          style: AppTypography.labelUppercase.copyWith(
                              color: AppColors.primary, fontSize: 10)),
                    ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(skillLabel(l, widget.skillKind),
                      style: AppTypography.titleLarge.copyWith(
                          fontSize: 30, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.x1),
                  Text(l.exerciseListSubtitle,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.x4),

            // ── Filter pills ─────────────────────────────────────────────────
            if (widget.skillKind == 'noi')
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: h),
                  children: [
                    _FilterPill(label: 'Tất cả', active: _filterTag == null,
                        onTap: () => setState(() => _filterTag = null)),
                    const SizedBox(width: AppSpacing.x2),
                    for (final n in ['1', '2', '3', '4']) ...[
                      _FilterPill(
                        label: 'Úloha $n',
                        active: _filterTag == n,
                        onTap: () => setState(() => _filterTag = _filterTag == n ? null : n),
                      ),
                      if (n != '4') const SizedBox(width: AppSpacing.x2),
                    ],
                  ],
                ),
              ),

            // Vocab/grammar type filter pills
            if (widget.skillKind == 'tu_vung' || widget.skillKind == 'ngu_phap')
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: h),
                  children: [
                    _FilterPill(label: 'Tất cả', active: _filterTag == null,
                        onTap: () => setState(() => _filterTag = null)),
                    const SizedBox(width: AppSpacing.x2),
                    for (final entry in [
                      if (widget.skillKind == 'tu_vung')
                        ('quizcard_basic', 'Flashcard'),
                      ('matching', 'Ghép đôi'),
                      ('fill_blank', 'Điền từ'),
                      ('choice_word', 'Chọn từ'),
                    ]) ...[
                      _FilterPill(
                        label: entry.$2,
                        active: _filterTag == entry.$1,
                        onTap: () => setState(() => _filterTag = _filterTag == entry.$1 ? null : entry.$1),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.x3),

            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!),
                          FilledButton(onPressed: _load, child: Text(l.retry)),
                        ]))
                      : _filtered.isEmpty
                          ? Center(child: Padding(
                              padding: EdgeInsets.all(AppSpacing.x5),
                              child: Text('Chưa có bài tập nào.',
                                  style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.onSurfaceVariant),
                                  textAlign: TextAlign.center),
                            ))
                          : ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: h, vertical: 0),
                              itemCount: _filtered.length + 1,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x3),
                              itemBuilder: (context, i) {
                                if (i == _filtered.length) {
                                  return _DailySprintCard(
                                    onTap: _filtered.isEmpty ? null : () => _openExercise(context, _filtered.first),
                                  );
                                }
                                final ex = _filtered[i];
                                return _ExerciseCard(
                                  exercise: ex,
                                  ulohaTag: _ulohaTag(ex.exerciseType),
                                  estimatedMin: _estimatedMin(ex),
                                  skillKind: widget.skillKind,
                                  onTap: () => _openExercise(context, ex),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.ulohaTag,
    required this.estimatedMin,
    required this.onTap,
    this.skillKind = 'noi',
  });

  final ExerciseSummary exercise;
  final String ulohaTag;
  final int estimatedMin;
  final VoidCallback onTap;
  final String skillKind;

  @override
  Widget build(BuildContext context) {
    final isVocabGrammar = skillKind == 'tu_vung' || skillKind == 'ngu_phap';
    final typeStyle = isVocabGrammar
        ? _ExerciseListScreenState._typeStyle(exercise.exerciseType)
        : null;

    final iconColor = typeStyle?.color ?? AppColors.primary;
    final iconBg = typeStyle?.bg ?? AppColors.primaryFixed;
    final iconData = typeStyle?.icon ?? _skillIcon(skillKind);
    final badgeLabel = typeStyle?.label ?? ulohaTag;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            // Icon — type-specific for vocab/grammar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(badgeLabel,
                          style: AppTypography.labelUppercase.copyWith(
                              fontSize: 9, color: iconColor)),
                    ),
                    const Spacer(),
                    const Icon(Icons.timer_outlined, size: 12, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text('$estimatedMin min',
                        style: AppTypography.bodySmall.copyWith(
                            fontSize: 11, color: AppColors.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: AppSpacing.x1),
                  Text(exercise.title,
                      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
                  if (exercise.shortInstruction.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x1),
                    Text(exercise.shortInstruction,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

IconData _skillIcon(String skillKind) => switch (skillKind) {
  'noi'      => Icons.mic_rounded,
  'nghe'     => Icons.headphones_rounded,
  'viet'     => Icons.edit_rounded,
  'doc'      => Icons.menu_book_rounded,
  'tu_vung'  => Icons.style_rounded,
  'ngu_phap' => Icons.school_rounded,
  _          => Icons.mic_rounded,
};

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.outlineVariant,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _DailySprintCard extends StatelessWidget {
  const _DailySprintCard({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x5),
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        color: AppColors.inverseSurfaceLight,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.exerciseListDailySprintLabel,
              style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.inverseOnSurfaceLight.withAlpha(160), fontSize: 10)),
          const SizedBox(height: AppSpacing.x2),
          Text(l.exerciseListDailySprintTitle,
              style: AppTypography.titleLarge.copyWith(
                  color: AppColors.inverseOnSurfaceLight, fontWeight: FontWeight.w700, fontSize: 22)),
          const SizedBox(height: AppSpacing.x1),
          Text(l.exerciseListDailySprintSubtitle,
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.inverseOnSurfaceLight.withAlpha(200))),
          const SizedBox(height: AppSpacing.x4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: Text(l.exerciseListDailySprintCta),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTypeStyle {
  const _ExerciseTypeStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
}
