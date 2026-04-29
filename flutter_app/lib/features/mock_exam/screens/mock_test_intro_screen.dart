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
  const MockTestIntroScreen({super.key, required this.client, required this.test});

  final ApiClient client;
  final MockTest test;

  @override
  State<MockTestIntroScreen> createState() => _MockTestIntroScreenState();
}

class _MockTestIntroScreenState extends State<MockTestIntroScreen> {
  bool _starting = false;
  String? _error;

  Future<void> _startExam() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final payload = await widget.client.createMockExam(mockTestId: widget.test.id);
      final session = MockExamSessionView.fromJson(payload);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MockExamScreen(
            client: widget.client,
            initialSession: session,
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
    final totalPts = test.totalMaxPoints + 3;
    final passScore = ((test.totalMaxPoints * test.passThresholdPercent) / 100).ceil();
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
                    color: AppColors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.x5),

            // 3-stat grid
            Row(
              children: [
                Expanded(child: _StatBox(
                  icon: Icons.timer_outlined,
                  value: '${test.estimatedDurationMinutes} phút',
                  label: 'Thời gian',
                  valueColor: AppColors.primary,
                )),
                const SizedBox(width: AppSpacing.x2),
                Expanded(child: _StatBox(
                  icon: Icons.star_outline,
                  value: '$totalPts điểm',
                  label: 'Điểm tối đa',
                  valueColor: AppColors.onSurface,
                )),
                const SizedBox(width: AppSpacing.x2),
                Expanded(child: _StatBox(
                  icon: Icons.flag_outlined,
                  value: '$passScore điểm',
                  label: 'Điểm đỗ',
                  valueColor: AppColors.success,
                )),
              ],
            ),
            const SizedBox(height: AppSpacing.x5),

            // Part breakdown
            Text(
              '${test.sections.length} PHẦN THI',
              style: AppTypography.labelUppercase.copyWith(
                fontSize: 11, color: AppColors.onSurfaceVariant, letterSpacing: 0.8),
            ),
            const SizedBox(height: AppSpacing.x3),

            ...test.sections.map((sec) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x2),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x3, vertical: AppSpacing.x3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${sec.sequenceNo}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _ulohaLabel(sec.exerciseType),
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _exerciseTypeLabel(sec.exerciseType, l),
                            style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${sec.maxPoints}đ',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x3),
              Text(_error!,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
            ],

            const SizedBox(height: AppSpacing.x5),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _starting ? null : _startExam,
                icon: _starting
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
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
                  color: AppColors.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _ulohaLabel(String type) => switch (type) {
    'uloha_2_dialogue_questions' => 'ÚLOHA 2',
    'uloha_3_story_narration'   => 'ÚLOHA 3',
    'uloha_4_choice_reasoning'  => 'ÚLOHA 4',
    _                           => 'ÚLOHA 1',
  };

  String _exerciseTypeLabel(String type, AppLocalizations l) => switch (type) {
    'uloha_2_dialogue_questions' => l.exerciseUloha2Label,
    'uloha_3_story_narration'   => l.exerciseUloha3Label,
    'uloha_4_choice_reasoning'  => l.exerciseUloha4Label,
    _                           => l.exerciseUloha1Label,
  };
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
            color: AppColors.outlineVariant.withValues(alpha: 0.6)),
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
