import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/writing_ai/providers/writing_provider.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';
import 'package:app_czech/shared/widgets/writing_text_area.dart';

/// Writing exercise screen — shows prompt + text area, submits for AI scoring.
/// Receives prompt/question or exercise context via GoRouter extra.
class WritingPromptScreen extends ConsumerStatefulWidget {
  const WritingPromptScreen({super.key});

  @override
  ConsumerState<WritingPromptScreen> createState() =>
      _WritingPromptScreenState();
}

class _WritingPromptScreenState extends ConsumerState<WritingPromptScreen> {
  final _controller = TextEditingController();
  ProviderSubscription<WritingSessionState>? _writingSubscription;
  int _wordCount = 0;
  String _prompt = '';
  String _questionId = '';
  String _exerciseId = '';
  String _lessonId = '';
  String _lessonBlockId = '';
  String _courseId = '';
  String _moduleId = '';
  String _examAttemptId = '';

  static const _minWords = 30;
  static const _maxWords = 250;

  @override
  void initState() {
    super.initState();
    _writingSubscription = ref.listenManual<WritingSessionState>(
      writingSessionProvider,
      (_, next) {
        if (!mounted || next.status != WritingFeedbackStatus.pending) return;
        context.push(
          AppRoutes.writingFeedback,
          extra: {
            'attemptId': next.attemptId,
            'questionId': _questionId,
            'exerciseId': _exerciseId,
            'lessonId': _lessonId,
            'lessonBlockId': _lessonBlockId,
            'courseId': _courseId,
            'moduleId': _moduleId,
            'source': _lessonId.isNotEmpty
                ? 'lesson'
                : (_examAttemptId.isNotEmpty ? 'mock_test' : 'practice'),
            'originalText': _controller.text,
          },
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _prompt = extra?['prompt'] as String? ?? '';
    _questionId = extra?['questionId'] as String? ?? '';
    _exerciseId = extra?['exerciseId'] as String? ?? '';
    _lessonId = extra?['lessonId'] as String? ?? '';
    _lessonBlockId = extra?['lessonBlockId'] as String? ?? '';
    _courseId = extra?['courseId'] as String? ?? '';
    _moduleId = extra?['moduleId'] as String? ?? '';
    _examAttemptId = extra?['examAttemptId'] as String? ?? '';
  }

  @override
  void dispose() {
    _writingSubscription?.close();
    _controller.dispose();
    super.dispose();
  }

  int _countWords(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(writingSessionProvider);
    final isSubmitting = state.status == WritingFeedbackStatus.submitting;

    final cs = Theme.of(context).colorScheme;
    final canSubmit = _wordCount >= _minWords && !isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Bài viết')),
      body: SingleChildScrollView(
        child: ResponsivePageContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Prompt card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: AppSpacing.x2),
                          Text(
                            'Đề bài',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      Text(
                        _prompt.isEmpty
                            ? 'Viết đoạn văn theo yêu cầu.'
                            : _prompt,
                        style: AppTypography.bodyLarge.copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),

                // Requirement hint
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.x1),
                    Text(
                      'Tối thiểu $_minWords từ, tối đa $_maxWords từ',
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),

                // Text area
                WritingTextArea(
                  controller: _controller,
                  wordCount: _wordCount,
                  maxWords: _maxWords,
                  onChanged: (text) =>
                      setState(() => _wordCount = _countWords(text)),
                ),
                const SizedBox(height: AppSpacing.x6),

                // Error
                if (state.status == WritingFeedbackStatus.error &&
                    state.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x3),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      state.errorMessage!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                ],

                AppButton(
                  label: 'Nộp bài',
                  icon: Icons.send_rounded,
                  loading: isSubmitting,
                  onPressed: canSubmit
                      ? () => ref
                          .read(writingSessionProvider.notifier)
                          .submitWriting(
                            text: _controller.text,
                            questionId: _questionId,
                            exerciseId:
                                _exerciseId.isEmpty ? null : _exerciseId,
                            lessonId: _lessonId,
                            examAttemptId:
                                _examAttemptId.isEmpty ? null : _examAttemptId,
                          )
                      : null,
                ),

                if (_wordCount < _minWords && _wordCount > 0) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'Cần thêm ${_minWords - _wordCount} từ nữa',
                    style: AppTypography.bodySmall
                        .copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
