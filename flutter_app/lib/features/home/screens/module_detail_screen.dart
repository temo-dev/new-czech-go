import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/skill_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import 'exercise_list_screen.dart';

class ModuleDetailScreen extends StatefulWidget {
  const ModuleDetailScreen({super.key, required this.client, required this.module});
  final ApiClient client;
  final ModuleSummary module;

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  List<SkillSummary> _skills = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await widget.client.listModuleSkills(widget.module.id);
      if (!mounted) return;
      setState(() {
        _skills = raw
            .map((e) => SkillSummary.fromJson(e as Map<String, dynamic>, widget.module.id))
            .toList();
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  String _skillDesc(String kind, AppLocalizations l) => switch (kind) {
    'noi'      => 'Luyện nói và phát âm tiếng Czech tự nhiên.',
    'nghe'     => 'Nghe hiểu trong các tình huống thực tế A2.',
    'doc'      => 'Đọc và hiểu văn bản từ tin nhắn đến bài báo.',
    'viet'     => 'Viết email và điền biểu mẫu tiếng Czech.',
    'tu_vung'  => 'Xây dựng vốn từ cho cuộc sống tại CH Séc.',
    'ngu_phap' => 'Nắm vững ngữ pháp, cách và thì động từ A2.',
    _          => '',
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
            // ── Custom app bar ─────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(h, AppSpacing.x3, h, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back, size: 22),
                ),
              ]),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!),
                          FilledButton(onPressed: _load, child: Text(l.retry)),
                        ]))
                      : ListView(
                          padding: EdgeInsets.symmetric(horizontal: h),
                          children: [
                            const SizedBox(height: AppSpacing.x4),
                            // Section label
                            Text(l.skillModulesLabel,
                                style: AppTypography.labelUppercase.copyWith(
                                    color: AppColors.primary, fontSize: 11, letterSpacing: 1.2)),
                            const SizedBox(height: AppSpacing.x2),
                            Text(l.skillModulesTitle,
                                style: AppTypography.titleLarge.copyWith(fontSize: 26, fontWeight: FontWeight.w700)),
                            const SizedBox(height: AppSpacing.x1),
                            Text(
                              l.skillModulesSubtitle,
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: AppSpacing.x5),

                            // ── Skill grid (2 columns) ───────────────────────
                            if (_skills.isEmpty)
                              Text(l.skillListTitle,
                                  style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant))
                            else
                              GridView.count(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppSpacing.x3,
                                mainAxisSpacing: AppSpacing.x3,
                                childAspectRatio: 1.05,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: _skills.map((sk) => _SkillCard(
                                  skill: sk,
                                  label: skillLabel(l, sk.skillKind),
                                  description: _skillDesc(sk.skillKind, l),
                                  icon: skillIcon(sk.skillKind),
                                  comingSoon: l.skillComingSoon,
                                  onTap: sk.isImplemented ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ExerciseListScreen(
                                        client: widget.client,
                                        moduleId: sk.moduleId,
                                        skillKind: sk.skillKind,
                                      ),
                                    ),
                                  ) : null,
                                )).toList(),
                              ),

                            // ── Mock test teaser ─────────────────────────────
                            const SizedBox(height: AppSpacing.x3),
                            _MockTeaser(),

                            const SizedBox(height: AppSpacing.x8),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.skill,
    required this.label,
    required this.description,
    required this.icon,
    required this.comingSoon,
    this.onTap,
  });

  final SkillSummary skill;
  final String label;
  final String description;
  final IconData icon;
  final String comingSoon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: enabled
                ? AppColors.primary.withAlpha(50)
                : AppColors.outlineVariant.withAlpha(100),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                icon,
                size: 20,
                color: enabled ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),

            // Label
            Text(
              label,
              style: AppTypography.titleSmall.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: enabled ? AppColors.onSurface : AppColors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),

            // Description
            Expanded(
              child: Text(
                description,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Status pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                enabled ? 'Luyện ngay' : comingSoon,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: enabled ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockTeaser extends StatelessWidget {
  const _MockTeaser();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: AppColors.outlineVariant.withAlpha(120),
          width: 1.5,
          // Dashed look via strokeAlign workaround — use solid with low opacity
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mock Test',
                  style: AppTypography.titleSmall.copyWith(fontSize: 14),
                ),
                Text(
                  'Kiểm tra trình độ với đề thi thử A2.',
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded,
              size: 18, color: AppColors.outline),
        ],
      ),
    );
  }
}
