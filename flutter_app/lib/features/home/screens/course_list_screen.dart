import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import 'course_detail_screen.dart';

// Card color palette — cycles through these per course index
const _cardColors = [
  (bg: AppColors.primary, text: AppColors.onPrimary, badge: Color(0x33FFFFFF)),
  (bg: AppColors.surfaceContainerLow, text: AppColors.onSurface, badge: AppColors.primaryFixed),
  (bg: AppColors.secondaryContainer, text: AppColors.onSecondaryContainer, badge: AppColors.surfaceContainerLowest),
  (bg: AppColors.tertiaryFixed, text: AppColors.onTertiaryFixed, badge: AppColors.surfaceContainerLowest),
  (bg: AppColors.inverseSurfaceLight, text: AppColors.inverseOnSurfaceLight, badge: Color(0x33FFFFFF)),
];

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key, required this.client});
  final ApiClient client;

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  List<Course> _courses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await widget.client.listCourses();
      if (!mounted) return;
      setState(() {
        _courses = raw.map((e) => Course.fromJson(e as Map<String, dynamic>)).toList()
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final l = AppLocalizations.of(context);
    final h = AppSpacing.pagePaddingH(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Padding(
        padding: EdgeInsets.all(AppSpacing.x5),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.x3),
          FilledButton(onPressed: _load, child: Text(l.retry)),
        ]),
      ));
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: h),
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.x5),
        Text(
          'CHÀO MỪNG BẠN TRỞ LẠI',
          style: AppTypography.labelUppercase.copyWith(
            color: AppColors.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          l.courseListTitle == 'Courses'
              ? 'Chọn khóa\nhọc của bạn'
              : l.courseListTitle,
          style: AppTypography.titleLarge.copyWith(
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          'Lộ trình học tập chuyên sâu cho người Việt tại Séc.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.x5),

        // ── Course cards ────────────────────────────────────────────────────
        if (_courses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
            child: Text(l.courseListEmpty, textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant)),
          )
        else
          ...List.generate(_courses.length, (i) {
            final c = _courses[i];
            final colors = _cardColors[i % _cardColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x3),
              child: _CourseCard(
                course: c,
                client: widget.client,
                bgColor: colors.bg,
                textColor: colors.text,
                badgeColor: colors.badge,
                isFeatured: i == 0,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CourseDetailScreen(client: widget.client, course: c),
                )),
              ),
            );
          }),

        const SizedBox(height: AppSpacing.x8),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.client,
    required this.bgColor,
    required this.textColor,
    required this.badgeColor,
    required this.isFeatured,
    required this.onTap,
  });

  final Course course;
  final ApiClient client;
  final Color bgColor;
  final Color textColor;
  final Color badgeColor;
  final bool isFeatured;
  final VoidCallback onTap;

  String get _statusLabel => switch (course.status) {
    'published' => isFeatured ? 'BẠN ĐANG HỌC' : 'KHÓA HỌC',
    'draft'     => 'SẮP RA MẮT',
    _           => 'KHÓA HỌC',
  };

  bool get _hasBanner => course.bannerImageId.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isLocked = course.status == 'draft';
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Opacity(
        opacity: isLocked ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.lgAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner image (when available) or solid color header strip
              if (_hasBanner)
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                  child: Stack(
                    children: [
                      Image.network(
                        client.mediaUri(course.bannerImageId).toString(),
                        headers: client.authHeaders,
                        height: isFeatured ? 160 : 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: isFeatured ? 160 : 120, color: bgColor),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(height: isFeatured ? 160 : 120, color: bgColor),
                      ),
                      // Gradient overlay for text legibility
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                            ),
                          ),
                        ),
                      ),
                      // Badge + lock on banner
                      Positioned(
                        left: isFeatured ? AppSpacing.x5 : AppSpacing.x4,
                        right: isFeatured ? AppSpacing.x5 : AppSpacing.x4,
                        bottom: isFeatured ? AppSpacing.x3 : AppSpacing.x2,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                _statusLabel,
                                style: AppTypography.labelUppercase.copyWith(
                                  color: Colors.white.withAlpha(220),
                                  fontSize: 10, letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (isLocked)
                              const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              Padding(
            padding: EdgeInsets.all(isFeatured ? AppSpacing.x5 : AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_hasBanner) ...[
                // Top row: badge + lock icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        _statusLabel,
                        style: AppTypography.labelUppercase.copyWith(
                          color: textColor.withAlpha(200),
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isLocked)
                      Icon(Icons.lock_outline_rounded, color: textColor.withAlpha(140), size: 16),
                  ],
                ),
                SizedBox(height: isFeatured ? AppSpacing.x3 : AppSpacing.x2),
                ],

                // Title
                Text(
                  course.title,
                  style: AppTypography.titleLarge.copyWith(
                    color: textColor,
                    fontSize: isFeatured ? 22 : 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),

                if (course.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    course.description,
                    style: AppTypography.bodySmall.copyWith(
                      color: textColor.withAlpha(180),
                    ),
                    maxLines: isFeatured ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                SizedBox(height: isFeatured ? AppSpacing.x4 : AppSpacing.x3),

                // Progress bar
                if (!isLocked) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: null, // indeterminate — real progress not available yet
                      minHeight: 4,
                      backgroundColor: textColor.withAlpha(25),
                      valueColor: AlwaysStoppedAnimation<Color>(textColor.withAlpha(140)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                ],

                // Footer row
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: textColor.withAlpha(140),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Nói • A2',
                      style: AppTypography.labelSmall.copyWith(
                        color: textColor.withAlpha(140),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: textColor.withAlpha(28),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_forward, color: textColor, size: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),    // close inner Padding
          ],    // close outer Column children
        ),      // close outer Column
        ),      // close Container
      ),        // close Opacity
    );
  }
}
