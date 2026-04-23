import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/teacher_feedback/providers/teacher_feedback_provider.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/shared/widgets/error_state.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

class TeacherThreadScreen extends ConsumerWidget {
  const TeacherThreadScreen({super.key, required this.threadId});
  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherFeedbackProvider(threadId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _AppBar(),
          Expanded(
            child: async.when(
              loading: () => const ShimmerCardList(count: 3),
              error: (e, _) => ErrorState(
                message: 'Không tải được phản hồi.',
                onRetry: () =>
                    ref.refresh(teacherFeedbackProvider(threadId)),
              ),
              data: (comments) => _ThreadBody(
                comments: comments,
                reviewId: threadId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
              color: AppColors.outlineVariant.withOpacity(0.6)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  'Teacher Feedback',
                  style: AppTypography.headlineSmall.copyWith(fontSize: 22),
                ),
                const Spacer(),
                const Icon(Icons.history_rounded,
                    color: AppColors.primary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Thread Body ───────────────────────────────────────────────────────────────

class _ThreadBody extends StatelessWidget {
  const _ThreadBody({
    required this.comments,
    required this.reviewId,
  });

  final List<TeacherComment> comments;
  final String reviewId;

  TeacherComment? get _teacherComment =>
      comments.where((c) => c.isTeacher).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final teacherMsg = _teacherComment;

    if (comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_empty_rounded,
                  size: 48, color: AppColors.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Đang chờ giáo viên chấm bài...',
                style: AppTypography.headlineSmall.copyWith(
                    fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn sẽ nhận được thông báo khi giáo viên đã phản hồi.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: ResponsivePageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero: title + score ring
            _HeroSection(teacherMsg: teacherMsg),
            const SizedBox(height: 32),

            // Summary bento
            if (teacherMsg != null) ...[
              _SummaryBento(comment: teacherMsg),
              const SizedBox(height: 32),
            ],

            // Detailed comments
            _DetailedComments(comments: comments),
            const SizedBox(height: 32),

            // Analysis grid
            _AnalysisGrid(),
            const SizedBox(height: 40),

            // CTA
            _CtaSection(),
          ],
        ),
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({this.teacherMsg});
  final TeacherComment? teacherMsg;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 768;
    final dateStr = teacherMsg != null
        ? DateFormat('dd/MM/yyyy').format(teacherMsg!.createdAt)
        : '';

    final heroContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STUDENT SUBMISSION',
          style: AppTypography.labelUppercase.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bài nộp của bạn',
          style: AppTypography.headlineLarge.copyWith(
            fontSize: isWide ? 44 : 32,
          ),
        ),
        const SizedBox(height: 16),
        // Teacher chip
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                teacherMsg?.authorName ?? 'Ms. Jana Nováková',
                style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (dateStr.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ],
    );

    // Score ring
    final scoreRing = _ScoreRing(score: 18, maxScore: 20);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: heroContent),
          const SizedBox(width: 40),
          scoreRing,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heroContent,
        const SizedBox(height: 32),
        Center(child: scoreRing),
      ],
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.maxScore});
  final int score;
  final int maxScore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(
        painter: _RingPainter(
          progress: score / maxScore,
          ringColor: AppColors.primary,
          bgColor: AppColors.surfaceContainerHighest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$score',
              style: AppTypography.headlineLarge.copyWith(
                color: AppColors.primary,
                fontSize: 56,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: AppColors.outlineVariant, width: 1),
                ),
              ),
              child: Text(
                '$maxScore',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.bgColor,
  });

  final double progress;
  final Color ringColor;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    const startAngle = -3.14159 / 2; // -90 degrees
    final sweepAngle = 2 * 3.14159 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress;
}

// ── Summary Bento ─────────────────────────────────────────────────────────────

class _SummaryBento extends StatelessWidget {
  const _SummaryBento({required this.comment});
  final TeacherComment comment;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 768;

    final summaryCard = Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary Feedback',
            style: AppTypography.headlineSmall.copyWith(
              fontSize: 22,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            comment.body,
            style: AppTypography.bodySmall.copyWith(height: 1.7),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _Tag(label: 'B1 Level', color: AppColors.primary),
              _Tag(label: 'Grammar Focus', color: AppColors.tertiary),
            ],
          ),
        ],
      ),
    );

    final achievementCard = Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: Colors.white, size: 36),
          const SizedBox(height: 16),
          Text(
            'Highest Accuracy in Vocabulary',
            style: AppTypography.headlineSmall.copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You used 12 advanced Czech idiomatic expressions correctly.',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );

    if (isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 2, child: summaryCard),
            const SizedBox(width: 24),
            Expanded(child: achievementCard),
          ],
        ),
      );
    }

    return Column(
      children: [
        summaryCard,
        const SizedBox(height: 24),
        achievementCard,
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelUppercase.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Detailed Comments ─────────────────────────────────────────────────────────

class _DetailedComments extends StatelessWidget {
  const _DetailedComments({required this.comments});
  final List<TeacherComment> comments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detailed Comments',
            style: AppTypography.headlineSmall.copyWith(fontSize: 26)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: AppColors.onBackground.withOpacity(0.04),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: comments
                .where((c) => c.isTeacher)
                .map((c) => _CommentBlock(comment: c))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _CommentBlock extends StatelessWidget {
  const _CommentBlock({required this.comment});
  final TeacherComment comment;

  @override
  Widget build(BuildContext context) {
    return Text(
      comment.body,
      style: AppTypography.bodyMedium.copyWith(
        fontStyle: FontStyle.italic,
        height: 1.8,
        color: AppColors.onBackground.withOpacity(0.8),
      ),
    );
  }
}

// ── Analysis Grid ─────────────────────────────────────────────────────────────

class _AnalysisGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 768;

    final strongPoints = _AnalysisCard(
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.primary,
      title: 'Strong Points',
      accentColor: AppColors.primary,
      items: const [
        'Natural command of informal Czech salutations.',
        'Clear and logical structure of the invitation.',
      ],
    );

    final improvements = _AnalysisCard(
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.tertiary,
      title: 'Areas for Improvement',
      accentColor: AppColors.tertiary,
      items: const [
        'Consistent use of the infinitive after modal verbs.',
        'Punctuation in complex sentences (comma before "že", "jestli").',
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: strongPoints),
          const SizedBox(width: 32),
          Expanded(child: improvements),
        ],
      );
    }

    return Column(
      children: [
        strongPoints,
        const SizedBox(height: 24),
        improvements,
      ],
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.accentColor,
    required this.items,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color accentColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: AppTypography.labelUppercase.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border(
              left: BorderSide(color: accentColor, width: 4),
              top: BorderSide(
                  color: AppColors.outlineVariant.withOpacity(0.3)),
              right: BorderSide(
                  color: AppColors.outlineVariant.withOpacity(0.3)),
              bottom: BorderSide(
                  color: AppColors.outlineVariant.withOpacity(0.3)),
            ),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final idx = (e.key + 1).toString().padLeft(2, '0');
              return Padding(
                padding: EdgeInsets.only(
                    bottom: e.key < items.length - 1 ? 12 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idx,
                      style: AppTypography.headlineSmall.copyWith(
                        color: accentColor,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── CTA Section ───────────────────────────────────────────────────────────────

class _CtaSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Ready to perfect this task? Apply the feedback in a new attempt.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 48),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_note_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'LUYỆN TẬP LẠI',
                  style: AppTypography.labelUppercase.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
