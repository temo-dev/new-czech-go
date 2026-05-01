import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import 'vocab_type_list_screen.dart';

/// Groups vocab/grammar exercises by exerciseType and lets the learner pick
/// a type to study — either one-by-one or as a full deck session.
class TypeGroupScreen extends StatefulWidget {
  const TypeGroupScreen({
    super.key,
    required this.client,
    required this.moduleId,
    required this.skillKind,
    required this.moduleTitle,
  });

  final ApiClient client;
  final String moduleId;
  final String skillKind; // 'tu_vung' | 'ngu_phap'
  final String moduleTitle;

  @override
  State<TypeGroupScreen> createState() => _TypeGroupScreenState();
}

class _TypeGroupScreenState extends State<TypeGroupScreen> {
  static const _typeOrder = [
    _TypeMeta(type: 'quizcard_basic', labelKey: 'flashcard', icon: Icons.style_rounded,     bgColor: Color(0xFFFFE5D2)),
    _TypeMeta(type: 'matching',       labelKey: 'matching',  icon: Icons.compare_arrows_rounded, bgColor: Color(0xFFD9E5E3)),
    _TypeMeta(type: 'fill_blank',     labelKey: 'fillBlank', icon: Icons.edit_rounded,       bgColor: Color(0xFFF8EAC9)),
    _TypeMeta(type: 'choice_word',    labelKey: 'choiceWord', icon: Icons.check_circle_outline_rounded, bgColor: Color(0xFFEDE9FE)),
  ];

  Map<String, List<ExerciseSummary>> _grouped = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await widget.client.listModuleExercises(
        widget.moduleId,
        skillKind: widget.skillKind,
      );
      final exercises = raw
          .map((e) => ExerciseSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      final grouped = <String, List<ExerciseSummary>>{};
      for (final ex in exercises) {
        grouped.putIfAbsent(ex.exerciseType, () => []).add(ex);
      }
      if (!mounted) return;
      setState(() { _grouped = grouped; _loading = false; });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  String _skillTitle(AppLocalizations l) =>
      widget.skillKind == 'tu_vung' ? l.skillTuVung : l.skillNguPhap;

  String _typeLabel(AppLocalizations l, String key) => switch (key) {
    'flashcard' => l.exerciseTypeFlashcard,
    'matching'  => l.exerciseTypeMatching,
    'fillBlank' => l.exerciseTypeFillBlank,
    'choiceWord' => l.exerciseTypeChoiceWord,
    _           => key,
  };

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
            // ── App bar ──────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(h, AppSpacing.x3, h, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back, size: 22),
                ),
              ]),
            ),
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(h, AppSpacing.x4, h, AppSpacing.x2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.moduleTitle,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(_skillTitle(l), style: AppTypography.headlineMedium),
                  const SizedBox(height: 4),
                  Text(l.typeGroupSubtitle,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            // ── Body ─────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              TextButton(onPressed: _load, child: Text(AppLocalizations.of(context).retry)),
                            ],
                          ),
                        )
                      : _buildGrid(l, h),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(AppLocalizations l, double h) {
    final available = _typeOrder
        .where((m) => (_grouped[m.type]?.isNotEmpty ?? false))
        .toList();

    if (available.isEmpty) {
      return Center(
        child: Text(l.emptyExerciseList,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.onSurfaceVariant)),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(h, AppSpacing.x3, h, AppSpacing.x4),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: available.map((meta) {
          final exercises = _grouped[meta.type]!;
          return _TypeCard(
            meta: meta,
            count: exercises.length,
            label: _typeLabel(l, meta.labelKey),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => VocabTypeListScreen(
                client: widget.client,
                moduleId: widget.moduleId,
                exerciseType: meta.type,
                typeLabel: _typeLabel(l, meta.labelKey),
                exercises: exercises,
              ),
            )),
          );
        }).toList(),
      ),
    );
  }
}

class _TypeMeta {
  const _TypeMeta({
    required this.type,
    required this.labelKey,
    required this.icon,
    required this.bgColor,
  });
  final String type;
  final String labelKey;
  final IconData icon;
  final Color bgColor;
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.meta,
    required this.count,
    required this.label,
    required this.onTap,
  });

  final _TypeMeta meta;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: meta.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(meta.icon, size: 22, color: Colors.black87),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.outline),
              ],
            ),
            const Spacer(),
            Text(label,
                style: AppTypography.titleSmall
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('$count bài',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
