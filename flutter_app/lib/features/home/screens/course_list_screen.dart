import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/level_api.dart';
import '../../../core/api/progress_api.dart';
import '../../../core/iap/iap_service_provider.dart';
import '../../../core/level_utils.dart';
import '../../../core/streak/streak_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../auth/screens/signup_screen.dart' show AuthServiceProvider;
import '../../courses/widgets/locked_course_sheet.dart';
import '../../courses/widgets/locked_course_tile.dart';
import '../../home/widgets/home_level_header.dart';
import '../../home/widgets/quota_indicator.dart';
import '../../paywall/screens/paywall_screen.dart';
import '../../promotion/promotion_exam_flow.dart';
import '../../progress/screens/progress_detail_screen.dart';
import '../../progress/skill_labels.dart';
import '../../progress/widgets/home_progress_card.dart';
import 'course_detail_screen.dart';

// Card color palette — vivid block bg + contrasting accent strip on bottom edge.
// Each tuple = (card body color, bottom accent strip color, foreground text color).
const _cardColors = [
  (bg: Color(0xFF7C3AED), accent: Color(0xFFF97316), text: Colors.white), // purple / orange strip
  (bg: Color(0xFFFB923C), accent: Color(0xFFB91C1C), text: Colors.white), // orange / red strip
  (bg: Color(0xFF22C55E), accent: Color(0xFFEAB308), text: Colors.white), // green  / amber strip
  (bg: Color(0xFF3B82F6), accent: Color(0xFFA855F7), text: Colors.white), // blue   / violet strip
  (bg: Color(0xFFEC4899), accent: Color(0xFFF59E0B), text: Colors.white), // pink   / amber strip
];

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key, required this.client, this.levelApi});
  final ApiClient client;
  final LevelApi? levelApi;

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  List<Course> _courses = [];
  bool _loading = true;
  String? _error;
  ProgressApi? _progressApi;
  final GlobalKey<HomeProgressCardState> _progressKey =
      GlobalKey<HomeProgressCardState>();

  // V21.3 D1: level progress for HomeLevelHeader + locked-tile rendering.
  Future<LevelProgressResponse>? _levelFuture;

  // V25-F2: surface free-tier daily usage so the home tab can nudge a
  // hard-blocked free learner toward upgrade. Pro learners see this
  // counter hidden via `proHide`.
  DailyUsageSummary? _usage;

  @override
  void initState() {
    super.initState();
    _load();
    _initProgressApi();
    _loadUsage();
    if (widget.levelApi != null) {
      _levelFuture = widget.levelApi!.fetchLevelProgress();
    }
  }

  Future<void> _loadUsage() async {
    try {
      final result = await widget.client.fetchStreakAndUsageV17();
      if (!mounted) return;
      setState(() => _usage = result.usage);
    } catch (_) {
      // V17 endpoint absent (legacy fixture build) or transient
      // failure — silently skip; QuotaIndicator stays unrendered.
    }
  }

  bool _resolveIsPro(BuildContext context) {
    try {
      final auth = AuthServiceProvider.of(context);
      return auth.currentUser?.isPro ?? false;
    } catch (_) {
      return false;
    }
  }

  void _openPaywall(BuildContext context) {
    final iap = IAPServiceProvider.maybeOf(context);
    if (iap == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PaywallScreen(iap: iap)),
    );
  }

  Future<void> _refreshLevelProgress() async {
    final api = widget.levelApi;
    if (api == null) return;
    setState(() {
      _levelFuture = api.fetchLevelProgress();
    });
  }

  Future<void> _initProgressApi() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _progressApi = ProgressApi(client: widget.client, prefs: prefs);
    });
  }

  void _openLockedSheet(
    BuildContext ctx,
    Course course,
    LevelProgressResponse? progress,
  ) {
    showModalBottomSheet<void>(
      context: ctx,
      builder:
          (_) => LockedCourseSheet(
            title: course.title,
            level: course.level,
            coveragePct: progress?.coveragePct ?? 0,
            coverageThresholdPct: progress?.coverageThresholdPct ?? 80,
            hasDemoExercise: course.demoExerciseId.isNotEmpty,
            onTapDemo: () => _openDemoExercise(course),
            onTapContinueLowerLevel: () {},
          ),
    );
  }

  void _openPromotionExam(LevelProgressResponse progress, String testId) {
    final api = widget.levelApi;
    if (api == null) return;
    final target = progress.nextLevel;
    if (target == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => PromotionExamFlow(
              levelApi: api,
              client: widget.client,
              targetLevel: target,
              promotionTestId: testId,
              onFinished: () async {
                Navigator.of(context).pop();
                await _refreshLevelProgress();
              },
            ),
      ),
    );
  }

  void _openDemoExercise(Course course) {
    // Demo exercise navigation reuses the same push path as regular exercises.
    // The server enforces recordMastery: false for demo sessions.
    if (course.demoExerciseId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => CourseDetailScreen(
              client: widget.client,
              course: course,
            ),
      ),
    );
  }

  void _openProgressDetail({String? skillKind}) {
    final api = _progressApi;
    if (api == null) return;
    final l = AppLocalizations.of(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProgressDetailScreen(
        fetcher: api.fetch,
        labels: ProgressDetailLabels(
          titleAll: l.progressDetailTitle,
          titleForSkill: (kind) => skillKindLabel(l, kind),
          moduleLabelFor: (id) => id,
          skillLabelFor: (kind) => skillKindLabel(l, kind),
          attemptsCountLabel: (n) => l.progressDetailAttemptsLabel(n),
          overallLabel: l.progressOverallTitle,
          emptyTitle: l.progressEmptyTitle,
          emptyMessage: '',
          emptyCtaLabel: l.progressEmptyCta,
          errorTitle: l.progressErrorTitle,
          errorMessage: '',
          retryLabel: l.progressErrorRetry,
          offlineLabel: l.progressOfflineChip,
        ),
        skillKind: skillKind,
      ),
    ));
  }

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
        // ── V21.3 D1: CEFR level header (badge + ring + promotion banner) ──
        if (_levelFuture != null)
          FutureBuilder<LevelProgressResponse>(
            future: _levelFuture,
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              return HomeLevelHeader(
                progress: snap.data!,
                onTapBadge: () {},
                onTapPromotion:
                    (testId) => _openPromotionExam(snap.data!, testId),
              );
            },
          ),

        // ── V25-F2: free-tier daily quota banner ──
        if (_usage != null) ...[
          const SizedBox(height: AppSpacing.x3),
          QuotaIndicator(
            usage: _usage!,
            proHide: _resolveIsPro(context),
            onTapWhenFull: () => _openPaywall(context),
          ),
        ],

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
        const SizedBox(height: AppSpacing.x4),

        // ── Progress card (V20) ────────────────────────────────────────────
        if (_progressApi != null) ...[
          HomeProgressCard(
            key: _progressKey,
            fetcher: _progressApi!.fetch,
            labels: HomeProgressCardLabels(
              cardTitle: l.homeProgressCardTitle,
              overallLabel: l.progressOverallTitle,
              emptyTitle: l.progressEmptyTitle,
              emptyMessage: '',
              emptyCtaLabel: l.progressEmptyCta,
              errorTitle: l.progressErrorTitle,
              errorMessage: '',
              retryLabel: l.progressErrorRetry,
              offlineLabel: l.progressOfflineChip,
              skillLabelFor: (kind) => skillKindLabel(l, kind),
            ),
            onSkillTap: (kind) => _openProgressDetail(skillKind: kind),
          ),
          const SizedBox(height: AppSpacing.x5),
        ],

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

            // V21.3 D2: locked courses use LockedCourseTile.
            if (c.unlockState == CourseUnlockState.locked) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                child: FutureBuilder<LevelProgressResponse>(
                  future: _levelFuture,
                  builder: (ctx, snap) {
                    final progress = snap.data;
                    return LockedCourseTile(
                      title: c.title,
                      level: c.level,
                      coveragePct: progress?.coveragePct ?? 0,
                      coverageThresholdPct:
                          progress?.coverageThresholdPct ?? 80,
                      hasDemoExercise: c.demoExerciseId.isNotEmpty,
                      // D3: tap body → sheet
                      onTap: () => _openLockedSheet(ctx, c, progress),
                      // D3: tap demo → exercise
                      onTapDemo: () => _openDemoExercise(c),
                    );
                  },
                ),
              );
            }

            final colors = _cardColors[i % _cardColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x3),
              child: _CourseCard(
                course: c,
                client: widget.client,
                bgColor: colors.bg,
                accentColor: colors.accent,
                textColor: colors.text,
                isFeatured: i == 0,
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder:
                        (_) =>
                            CourseDetailScreen(client: widget.client, course: c),
                  ));
                  // D4: refresh progress after pop-back.
                  await _progressKey.currentState?.refresh();
                  await _refreshLevelProgress();
                },
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
    required this.accentColor,
    required this.textColor,
    required this.isFeatured,
    required this.onTap,
  });

  final Course course;
  final ApiClient client;
  final Color bgColor;
  final Color accentColor;
  final Color textColor;
  final bool isFeatured;
  final VoidCallback onTap;

  bool get _hasBanner => course.bannerImageId.isNotEmpty;

  bool get _isDraft => course.status == 'draft';

  String get _levelCode => course.level.name.toUpperCase();

  String get _subtitle => 'Cấp độ $_levelCode';

  // Top-left pill label. Draft state wins over "đang học" so we don't claim a
  // learner is actively studying a coming-soon course.
  String? get _pillLabel {
    if (_isDraft) return 'SẮP RA MẮT';
    if (isFeatured) return 'ĐANG HỌC';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pill = _pillLabel;
    // Decode banners to roughly card width × DPR so we don't keep full-res
    // upload bitmaps in memory for every card.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cardW =
        MediaQuery.of(context).size.width - 2 * AppSpacing.pagePaddingH(context);
    final imageCacheWidth = (cardW * dpr).round().clamp(200, 1600);

    return GestureDetector(
      onTap: _isDraft ? null : onTap,
      child: Opacity(
        opacity: _isDraft ? 0.55 : 1.0,
        child: AspectRatio(
          aspectRatio: 1.05, // ~square, slightly portrait — matches reference proportion
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Solid color body (always painted — fallback under banner load)
                Container(color: bgColor),

                // Watermark big-letter pattern when no banner image — design baked
                // into banner_image_id will replace this when present.
                if (!_hasBanner)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (ctx, c) {
                          // Size watermark to card height so it scales with the
                          // device without overflowing or shrinking too small.
                          final fs = c.maxHeight * 0.68;
                          return ClipRect(
                            child: Center(
                              child: Text(
                                _levelCode * 2,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: textColor.withAlpha(60),
                                  fontSize: fs,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -fs * 0.035,
                                  height: 0.9,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Banner image (design-baked artwork w/ giant text overlay lives here)
                if (_hasBanner)
                  Image.network(
                    client.mediaUri(course.bannerImageId).toString(),
                    headers: client.authHeaders,
                    fit: BoxFit.cover,
                    cacheWidth: imageCacheWidth,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : const SizedBox.shrink(),
                  ),

                // Bottom darkening gradient so title stays readable on any art
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 140,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x80000000)],
                        ),
                      ),
                    ),
                  ),
                ),

                // Top-left status pill — "ĐANG HỌC" for the featured course,
                // "SẮP RA MẮT" for draft. Hidden otherwise.
                if (pill != null)
                  Positioned(
                    top: 18, left: 22,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(46),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        pill,
                        style: AppTypography.labelUppercase.copyWith(
                          color: textColor,
                          fontSize: 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                // Title + subtitle anchored bottom-left
                Positioned(
                  left: 22, right: 80, bottom: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLarge.copyWith(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: textColor.withAlpha(220),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // White circular chevron CTA bottom-right
                Positioned(
                  right: 20, bottom: 26,
                  child: Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: bgColor,
                      size: 22,
                    ),
                  ),
                ),

                // Accent strip pinned to bottom edge — replaces the old progress bar.
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(height: 6, color: accentColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
