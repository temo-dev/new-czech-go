import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../exercise/screens/exercise_screen.dart' as exercise_feature;

class ExerciseListScreen extends StatefulWidget {
  const ExerciseListScreen({super.key, required this.client, required this.skill});
  final ApiClient client;
  final Skill skill;

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
      final raw = await widget.client.listSkillExercises(widget.skill.id);
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

  Future<void> _openExercise(BuildContext context, ExerciseSummary exercise) async {
    final detail = ExerciseDetail.fromJson(await widget.client.getExercise(exercise.id));
    if (!mounted) return;
    final idx = _exercises.indexOf(exercise);
    final next = (idx >= 0 && idx + 1 < _exercises.length) ? _exercises[idx + 1] : null;
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

  List<ExerciseSummary> get _filtered {
    if (_filterTag == null) return _exercises;
    return _exercises.where((e) => e.exerciseType.startsWith('uloha_$_filterTag')).toList();
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
                Text('Pokrok v mluvení',
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w600)),
              ]),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(h, AppSpacing.x4, h, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('PROUD',
                        style: AppTypography.labelUppercase.copyWith(
                            color: AppColors.primary, fontSize: 10)),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(widget.skill.title,
                      style: AppTypography.titleLarge.copyWith(
                          fontSize: 30, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.x1),
                  Text('Zaměřte se na plynulost a správnou výslovnost v reálných situacích.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.x4),

            // ── Filter pills ─────────────────────────────────────────────────
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
  });

  final ExerciseSummary exercise;
  final String ulohaTag;
  final int estimatedMin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mic_rounded, color: AppColors.primary, size: 20),
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
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(ulohaTag,
                          style: AppTypography.labelUppercase.copyWith(
                              fontSize: 9, color: AppColors.primary)),
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
          Text('DOPORUČENÝ REŽIM',
              style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.inverseOnSurfaceLight.withAlpha(160), fontSize: 10)),
          const SizedBox(height: AppSpacing.x2),
          Text('Denní Sprint',
              style: AppTypography.titleLarge.copyWith(
                  color: AppColors.inverseOnSurfaceLight, fontWeight: FontWeight.w700, fontSize: 22)),
          const SizedBox(height: AppSpacing.x1),
          Text('Procvičte si všechny úkoly najednou a získejte okamžitou zpětnou vazbu od AI kouče.',
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.inverseOnSurfaceLight.withAlpha(200))),
          const SizedBox(height: AppSpacing.x4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: const Text('Spustit vše'),
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
