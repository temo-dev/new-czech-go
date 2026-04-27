import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import 'module_detail_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.client, required this.course});
  final ApiClient client;
  final Course course;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  List<ModuleSummary> _modules = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await widget.client.listCourseModules(widget.course.id);
      if (!mounted) return;
      setState(() {
        _modules = raw.map((e) => ModuleSummary.fromJson(e as Map<String, dynamic>)).toList()
          ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() { _error = err.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: _buildBody(l)),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    final h = AppSpacing.pagePaddingH(context);

    return CustomScrollView(
      slivers: [
        // ── Hero header ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Stack(
            children: [
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                ),
              ),
              Positioned(
                top: 0, left: 0, right: 0, bottom: 0,
                child: Container(color: Colors.black.withAlpha(30)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(h, AppSpacing.x3, h, AppSpacing.x5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                      ),
                      const Spacer(),
                    ]),
                    const SizedBox(height: AppSpacing.x4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('INTENSIVE COURSE',
                          style: AppTypography.labelUppercase.copyWith(color: Colors.white, fontSize: 10)),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Text(widget.course.title,
                        style: AppTypography.titleLarge.copyWith(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                    if (widget.course.description.isNotEmpty)
                      Text(widget.course.description,
                          style: AppTypography.bodySmall.copyWith(color: Colors.white.withAlpha(200)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Loading / error ──────────────────────────────────────────────────
        if (_loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          SliverFillRemaining(child: Center(child: Padding(
            padding: EdgeInsets.all(AppSpacing.x5),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.x3),
              FilledButton(onPressed: _load, child: Text(l.retry)),
            ]),
          )))
        else ...[
          // ── Module count stats ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: h, vertical: AppSpacing.x4),
              child: Row(
                children: [
                  _StatBox(value: '${_modules.length}', label: 'MÔ-ĐUN'),
                  _divider(),
                  _StatBox(value: '${_modules.length * 4}', label: 'KỸ NĂNG'),
                  _divider(),
                  _StatBox(value: '${_modules.length * 45}', label: 'PHÚT'),
                ],
              ),
            ),
          ),

          // ── Timeline header ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.moduleListTitle, style: AppTypography.titleSmall),
                  Text('0% Hoàn thành',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.primary)),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x3)),

          // ── Modules timeline ────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: h),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ModuleTimelineTile(
                  module: _modules[i],
                  index: i,
                  total: _modules.length,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ModuleDetailScreen(client: widget.client, module: _modules[i]),
                  )),
                ),
                childCount: _modules.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x8)),
        ],
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: AppColors.outlineVariant,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x4));
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text(value, style: AppTypography.titleLarge.copyWith(fontSize: 28, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label, style: AppTypography.labelUppercase.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
    ]));
  }
}

class _ModuleTimelineTile extends StatelessWidget {
  const _ModuleTimelineTile({
    required this.module,
    required this.index,
    required this.total,
    required this.onTap,
  });

  final ModuleSummary module;
  final int index;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFirst = index == 0;
    final isLast = index == total - 1;
    final isUnlocked = module.status != 'locked'; // all non-locked modules are tappable

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 48,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: AppSpacing.x2, color: AppColors.outlineVariant),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked ? AppColors.primaryContainer : AppColors.surfaceContainerHigh,
                    border: Border.all(
                      color: isUnlocked
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : AppColors.outlineVariant.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: AppTypography.bodySmall.copyWith(
                      color: isUnlocked ? AppColors.primary : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppColors.outlineVariant)),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.x3),

          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x3),
              child: GestureDetector(
                onTap: isUnlocked ? onTap : null,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? AppColors.surfaceContainerLowest
                        : AppColors.surfaceContainerLow,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(
                      color: isUnlocked ? AppColors.outlineVariant : AppColors.outlineVariant.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(module.title,
                                style: AppTypography.titleSmall.copyWith(
                                  color: isUnlocked ? AppColors.onSurface : AppColors.onSurfaceVariant,
                                ))),
                            if (!isUnlocked)
                              Icon(Icons.lock_outline, size: 16, color: AppColors.onSurfaceVariant),
                          ]),
                          if (module.description.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.x1),
                            Text(module.description,
                                style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      )),
                      if (isUnlocked) ...[
                        const SizedBox(width: AppSpacing.x2),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
