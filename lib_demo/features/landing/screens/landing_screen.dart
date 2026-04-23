import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/sticky_bottom_cta.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Sticky header ────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: const Border(
                  bottom: BorderSide(
                    color: Color(0x99D8D0C8), // outlineVariant 60%
                    width: 1,
                  ),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Trvalý',
                        style: AppTypography.titleMedium.copyWith(
                          fontFamily: 'EBGaramond',
                          fontWeight: FontWeight.w700,
                          color: AppColors.onBackground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8), // 👈 đều 2 bên
                    child: SizedBox(
                      width: 120, // hoặc theo design
                      child: AppButton(
                        label: 'Thi thử ngay',
                        icon: Icons.book,
                        size: AppButtonSize.sm,
                        onPressed: () => context.push(AppRoutes.mockTestIntro),
                        fullWidth: false,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8), // 👈 đều 2 bên
                    child: SizedBox(
                      width: 120, // hoặc theo design
                      child: AppButton(
                        label: 'Đăng Nhập',
                        icon: Icons.login,
                        size: AppButtonSize.sm,
                        onPressed: () => context.push(AppRoutes.login),
                        fullWidth: false,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Content ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _HeroSection(
                        onStartMockTest: () =>
                            context.push(AppRoutes.mockTestIntro)),
                    _HowItWorksSection(),
                    _BenefitsSection(),
                    _ResultPreviewSection(),
                    _LearningPathSection(),
                    _TestimonialsSection(),
                    // _GuaranteeSection(),
                    _FaqSection(),
                    const SizedBox(height: 80), // space for sticky CTA
                  ],
                ),
              ),
            ],
          ),

          // ── Sticky bottom CTA ─────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: StickyBottomCta(
              label: 'Thi thử miễn phí ngay',
              icon: Icons.book,
              onTap: () => context.push(AppRoutes.mockTestIntro),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section: Hero ────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onStartMockTest});

  final VoidCallback onStartMockTest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 80),
      child: Stack(
        children: [
          // Decorative radial glow
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryFixed.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Headline
              Text(
                'Vượt qua kỳ thi Trvalý nhanh hơn',
                style: AppTypography.displayLarge.copyWith(
                  color: AppColors.onBackground,
                  fontSize: 40,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Giải pháp ôn thi tiếng Séc chuyên biệt dành riêng cho cộng đồng người Việt tại CH Séc.',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // CTA buttons
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  key: const Key('landing_start_exam_button'),
                  label: 'Thi thử miễn phí ngay',
                  icon: Icons.book,
                  onPressed: onStartMockTest,
                  size: AppButtonSize.lg,
                ),
              ),
              const SizedBox(height: 48),
              // Hero image placeholder
              Container(
                height: 200,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    image: DecorationImage(
                        image: AssetImage('assets/images/banner01.png'),
                        fit: BoxFit.contain)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section: How it works ─────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        '1',
        'Đánh giá trình độ',
        'Làm bài test nhanh 5 phút để AI phân tích điểm mạnh, điểm yếu của bạn.'
      ),
      (
        '2',
        'Học 10 phút/ngày',
        'Lộ trình cá nhân hóa tập trung vào những từ vựng và cấu trúc hay ra đề.'
      ),
      (
        '3',
        'Thi thử & Đỗ',
        'Trải nghiệm môi trường mô phỏng phòng thi thật để tự tin 100% khi đi thi.'
      ),
    ];

    return Container(
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Text(
            '3 bước để thành công',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: AppColors.outlineVariant.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryFixed,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            step.$1,
                            style: AppTypography.headlineSmall.copyWith(
                              color: AppColors.primary,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.$2,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.onBackground,
                                fontFamily: 'EBGaramond',
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              step.$3,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Section: Benefits ─────────────────────────────────────────────────────────

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection();

  @override
  Widget build(BuildContext context) {
    final benefits = [
      (Icons.assignment_turned_in_rounded, 'Thi thử như thật'),
      (Icons.timer_rounded, '10 phút mỗi ngày'),
      (Icons.psychology_rounded, 'Sửa lỗi bởi AI'),
      (Icons.translate_rounded, 'Cho người Việt'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Text(
            'Ưu điểm vượt trội',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tại sao 5,000+ người Việt chọn Trvalý Exam?',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
            children: benefits
                .map(
                  (b) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: AppColors.outlineVariant.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(b.$1, color: AppColors.primary, size: 32),
                        const SizedBox(height: 16),
                        Text(
                          b.$2,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.onBackground,
                            fontFamily: 'EBGaramond',
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Section: Result Preview ───────────────────────────────────────────────────

class _ResultPreviewSection extends StatelessWidget {
  const _ResultPreviewSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3A302A).withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // User info
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryFixed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nguyễn Văn A',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'HẠNG: SƠ CẤP A1',
                      style: AppTypography.labelUppercase.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Score + progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '82%',
                  style: AppTypography.displayLarge.copyWith(
                    color: AppColors.primary,
                    fontSize: 40,
                  ),
                ),
                Text(
                  'Khả năng đỗ',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: 0.82,
                minHeight: 10,
                backgroundColor: AppColors.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            // Skill mini cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nghe',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '22/25',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.onBackground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đọc',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '18/25',
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.onBackground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '"Bạn đang đi đúng hướng! Chỉ cần luyện thêm phần Đọc."',
              style: AppTypography.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section: Learning Path ────────────────────────────────────────────────────

class _LearningPathSection extends StatelessWidget {
  const _LearningPathSection();

  @override
  Widget build(BuildContext context) {
    final milestones = [
      (
        AppColors.primary,
        'A1 Foundation',
        'Nắm vững 500 từ vựng và ngữ pháp cơ bản để giao tiếp hàng ngày.'
      ),
      (
        AppColors.primaryFixed,
        'Trvalý Master',
        'Tập trung giải đề, luyện kỹ năng nghe và đọc hiểu văn bản hành chính.'
      ),
      (
        AppColors.surfaceContainerHighest,
        'Life in Czechia',
        'Văn hóa, ứng xử và các kiến thức cần thiết để định cư lâu dài.'
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lộ trình học cá nhân',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 48),
          IntrinsicHeight(
            child: Row(
              children: [
                // Vertical line
                Column(
                  children: [
                    ...List.generate(
                      milestones.length,
                      (i) => Padding(
                        padding: EdgeInsets.only(
                            bottom: i < milestones.length - 1 ? 0 : 0),
                        child: Column(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: milestones[i].$1,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 3,
                                ),
                              ),
                            ),
                            if (i < milestones.length - 1)
                              Container(
                                width: 2,
                                height: 80,
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: milestones
                        .map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(bottom: 48),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.$2,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.onBackground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  m.$3,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section: Testimonials ─────────────────────────────────────────────────────

class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Text(
            'Học viên nói gì',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _TestimonialCard(
            quote:
                '"App cực kỳ dễ hiểu. Tôi chỉ học 15 phút mỗi tối sau khi đi làm về mà vẫn thi đỗ ngay lần đầu."',
            name: 'Chị Linh',
            location: 'Prague',
            showStars: true,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: _TestimonialCard(
              quote:
                  '"Phần AI sửa bài viết rất hay, giúp tôi nhận ra những lỗi sai ngữ pháp mà trước đây không ai chỉ."',
              name: 'Anh Tuấn',
              location: 'Brno',
            ),
          ),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({
    required this.quote,
    required this.name,
    required this.location,
    this.showStars = false,
  });

  final String quote;
  final String name;
  final String location;
  final bool showStars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A302A).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showStars) ...[
            Row(
              children: List.generate(
                5,
                (_) => const Icon(Icons.star_rounded,
                    size: 16, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            quote,
            style: AppTypography.bodyMedium.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.onBackground,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$name ($location)',
                style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.onBackground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section: Guarantee ────────────────────────────────────────────────────────

class _GuaranteeSection extends StatelessWidget {
  const _GuaranteeSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.tertiary,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                'Cam kết đậu hoặc hoàn tiền',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.onBackground,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Chúng tôi tin tưởng vào phương pháp học của mình. Nếu bạn hoàn thành lộ trình mà không đỗ, chúng tôi hoàn 100% học phí.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                width: 80,
                height: 1,
                color: AppColors.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section: FAQ ──────────────────────────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  @override
  Widget build(BuildContext context) {
    final faqs = [
      (
        'App có tốn phí không?',
        'Bạn có thể bắt đầu thi thử và học các bài cơ bản miễn phí. Gói Premium mở khóa toàn bộ kho đề thi và tính năng AI.'
      ),
      (
        'AI sửa bài như thế nào?',
        'AI của chúng tôi được huấn luyện trên hàng ngàn bài thi thực tế để nhận diện lỗi sai về giống, số và cách chia động từ đặc trưng của người Việt.'
      ),
      (
        'Học bao lâu thì đi thi được?',
        'Trung bình 4–6 tuần nếu bạn học 10–15 phút mỗi ngày. Người có nền tảng sẵn có thể rút ngắn xuống 2–3 tuần.'
      ),
    ];

    return Container(
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Text(
            'Câu hỏi thường gặp',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          ...faqs.map(
            (faq) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _FaqItem(question: faq.$1, answer: faq.$2),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5).animate(_ctrl),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Text(
                      widget.answer,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
