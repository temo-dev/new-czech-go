import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import 'mock_exam_screen.dart';

class MockTestIntroScreen extends StatefulWidget {
  const MockTestIntroScreen({
    super.key,
    required this.client,
    required this.test,
  });

  final ApiClient client;
  final MockTest test;

  @override
  State<MockTestIntroScreen> createState() => _MockTestIntroScreenState();
}

class _MockTestIntroScreenState extends State<MockTestIntroScreen> {
  bool _starting = false;
  String? _error;

  Future<void> _startExam() async {
    final mockTestId = widget.test.id.trim();
    if (mockTestId.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(context).mockTestMissingTemplateId;
      });
      return;
    }

    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final payload = await widget.client.createMockExam(
        mockTestId: mockTestId,
      );
      final session = MockExamSessionView.fromJson(payload);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => MockExamScreen(
                client: widget.client,
                initialSession: session,
                mockTest: widget.test,
              ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _starting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final test = widget.test;
    final totalPts = test.totalScoreMax;
    final h = AppSpacing.pagePaddingH(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: h, vertical: AppSpacing.x4),
          children: [
            // Eyebrow + title
            Text(
              'MOCK TEST',
              style: AppTypography.labelUppercase.copyWith(
                color: AppColors.primary,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              test.title,
              style: AppTypography.titleLarge.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
            if (test.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x1),
              Text(
                test.description,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.x5),

            // 3-stat grid
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: Icons.timer_outlined,
                    value: '${test.estimatedDurationMinutes} phút',
                    label: 'Thời gian',
                    valueColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: _StatBox(
                    icon: Icons.star_outline,
                    value: '$totalPts điểm',
                    label: 'Điểm tối đa',
                    valueColor: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: _StatBox(
                    icon: Icons.flag_outlined,
                    value: '≥${test.passThresholdPercent}%',
                    label: 'Điểm đỗ',
                    valueColor: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x5),

            // Part breakdown — grouped by skill_kind
            ..._buildSkillGroups(test, l),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x3),
              Text(
                _error!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ],

            const SizedBox(height: AppSpacing.x5),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _starting ? null : _startExam,
                icon:
                    _starting
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.mic_rounded, size: 20),
                label: Text(l.mockTestIntroStartCta),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              'Hãy đeo tai nghe và ngồi ở nơi yên tĩnh.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _skillKindOrder = ['noi', 'nghe', 'doc', 'viet'];

  static String _skillGroupLabel(String kind) => switch (kind) {
    'noi' => 'Nói (Speaking)',
    'nghe' => 'Nghe (Listening)',
    'doc' => 'Đọc (Reading)',
    'viet' => 'Viết (Writing)',
    _ => kind.toUpperCase(),
  };

  static Color _skillGroupColor(String kind) => switch (kind) {
    'noi' => AppColors.primary,
    'nghe' => AppColors.info,
    'doc' => AppColors.warning,
    'viet' => AppColors.success,
    _ => AppColors.onSurfaceVariant,
  };

  static IconData _skillGroupIcon(String kind) => switch (kind) {
    'noi' => Icons.mic_none_rounded,
    'nghe' => Icons.headphones_outlined,
    'doc' => Icons.menu_book_outlined,
    'viet' => Icons.edit_outlined,
    _ => Icons.school_outlined,
  };

  List<Widget> _buildSkillGroups(MockTest test, AppLocalizations l) {
    // Collect unique skill_kinds in canonical order
    final grouped = <String, List<MockTestSection>>{};
    for (final kind in _skillKindOrder) {
      final secs = test.sections.where((s) => s.skillKind == kind).toList();
      if (secs.isNotEmpty) grouped[kind] = secs;
    }
    // Also include any unknown kinds at end
    for (final sec in test.sections) {
      if (!_skillKindOrder.contains(sec.skillKind)) {
        (grouped[sec.skillKind] ??= []).add(sec);
      }
    }

    if (grouped.isEmpty) {
      return [
        Text(
          '${test.sections.length} PHẦN THI',
          style: AppTypography.labelUppercase.copyWith(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
      ];
    }

    final widgets = <Widget>[
      Text(
        '${grouped.length} PHẦN THI',
        style: AppTypography.labelUppercase.copyWith(
          fontSize: 11,
          color: AppColors.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: AppSpacing.x3),
    ];

    for (final kind in [
      ..._skillKindOrder,
      ...grouped.keys.where((k) => !_skillKindOrder.contains(k)),
    ]) {
      final secs = grouped[kind];
      if (secs == null) continue;
      final totalPts = secs.fold(0, (s, x) => s + x.maxPoints);
      final color = _skillGroupColor(kind);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x2),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3,
              vertical: AppSpacing.x3,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_skillGroupIcon(kind), size: 16, color: color),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _skillGroupLabel(kind),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${secs.length} bài luyện',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$totalPts đ',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.titleSmall.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
