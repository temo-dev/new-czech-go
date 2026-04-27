import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import 'full_exam_intro_screen.dart';
import 'mock_test_intro_screen.dart';

class MockTestListScreen extends StatefulWidget {
  const MockTestListScreen({super.key, required this.client});

  final ApiClient client;

  @override
  State<MockTestListScreen> createState() => _MockTestListScreenState();
}

class _MockTestListScreenState extends State<MockTestListScreen> {
  List<MockTest> _tests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.client.listMockTests();
      if (!mounted) return;
      setState(() {
        _tests = raw.map((e) => MockTest.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.mockTestListTitle)),
      body: SafeArea(child: _buildBody(l)),
    );
  }

  Widget _buildBody(AppLocalizations l) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.x3),
              FilledButton(onPressed: _load, child: Text(l.retry)),
            ],
          ),
        ),
      );
    }

    if (_tests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x5),
          child: Text(l.mockTestListEmpty, textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x5,
      ),
      children: List.generate(_tests.length, (i) => _MockTestCard(
        test: _tests[i],
        index: i,
        onTap: () => _openIntro(_tests[i]),
      )),
    );
  }

  void _openIntro(MockTest test) {
    if (test.isPisemna || test.isFull) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FullExamIntroScreen(client: widget.client, test: test),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MockTestIntroScreen(client: widget.client, test: test),
      ),
    );
  }
}

class _MockTestCard extends StatelessWidget {
  const _MockTestCard({required this.test, required this.onTap, required this.index});

  final MockTest test;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final passScore = (test.totalMaxPoints * 0.6).round(); // 60% pass threshold
    final totalPts = test.totalMaxPoints + 3; // +3 pronunciation bonus

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
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
              // Row 1: brand pill + chevron
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'MOCK ${(index + 1).toString().padLeft(2, '0')}',
                      style: AppTypography.labelUppercase.copyWith(
                        fontSize: 10,
                        color: AppColors.primary,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),

              // Row 2: title
              Text(
                test.title,
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),

              // Row 3: description
              if (test.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x1),
                Text(
                  test.description,
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.x3),

              // Row 4: metadata icons
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 13, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    l.mockTestCardMinutes(test.estimatedDurationMinutes),
                    style: AppTypography.bodySmall.copyWith(
                        fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  const Icon(Icons.view_list_rounded,
                      size: 13, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    l.mockTestCardSections(test.sections.length),
                    style: AppTypography.bodySmall.copyWith(
                        fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  const Icon(Icons.flag_outlined,
                      size: 13, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Đạt $passScore/$totalPts',
                    style: AppTypography.bodySmall.copyWith(
                        fontSize: 12, color: AppColors.success),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
