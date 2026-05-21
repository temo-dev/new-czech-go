import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/app_notification.dart';
import 'mock_test_intro_screen.dart';

// Card color palette — same vivid block + accent strip pattern used by the
// course list cards. Each tuple = (card body color, bottom accent strip color,
// foreground text color).
const _examCardColors = [
  (bg: Color(0xFF7C3AED), accent: Color(0xFFF97316), text: Colors.white),
  (bg: Color(0xFFFB923C), accent: Color(0xFFB91C1C), text: Colors.white),
  (bg: Color(0xFF22C55E), accent: Color(0xFFEAB308), text: Colors.white),
  (bg: Color(0xFF3B82F6), accent: Color(0xFFA855F7), text: Colors.white),
  (bg: Color(0xFFEC4899), accent: Color(0xFFF59E0B), text: Colors.white),
];

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
        _tests =
            raw
                .map((e) => MockTest.fromJson(e as Map<String, dynamic>))
                .toList();
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
              AppNotification.error(message: _error!),
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
          child: Text(
            l.mockTestListEmpty,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH(context),
        vertical: AppSpacing.x5,
      ),
      children: List.generate(
        _tests.length,
        (i) => _MockTestCard(
          test: _tests[i],
          index: i,
          client: widget.client,
          onTap: () => _openIntro(_tests[i]),
        ),
      ),
    );
  }

  void _openIntro(MockTest test) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MockTestIntroScreen(client: widget.client, test: test),
      ),
    );
  }
}

class _MockTestCard extends StatelessWidget {
  const _MockTestCard({
    required this.test,
    required this.onTap,
    required this.index,
    required this.client,
  });

  final MockTest test;
  final VoidCallback onTap;
  final int index;
  final ApiClient client;

  bool get _hasBanner => test.bannerImageId.isNotEmpty;

  String get _indexCode => (index + 1).toString().padLeft(2, '0');
  String get _watermarkCode => _indexCode * 2;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = _examCardColors[index % _examCardColors.length];
    final bgColor = colors.bg;
    final accentColor = colors.accent;
    final textColor = colors.text;

    // Pass score derived from totalScoreMax × passThresholdPercent (ceil).
    final totalPts = test.totalScoreMax;
    final passScore = ((totalPts * test.passThresholdPercent) + 99) ~/ 100;

    final subtitle =
        '${l.mockTestCardMinutes(test.estimatedDurationMinutes)} • '
        '${l.mockTestCardSections(test.sections.length)} • '
        'Đạt $passScore/$totalPts';

    // Decode banners at roughly card width × DPR to avoid keeping full-res
    // upload bitmaps in memory for every card.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cardW =
        MediaQuery.of(context).size.width -
        2 * AppSpacing.pagePaddingH(context);
    final imageCacheWidth = (cardW * dpr).round().clamp(200, 1600);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1.05,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: bgColor),

                // Watermark big-number pattern when no banner — design-baked
                // banner replaces this when present.
                if (!_hasBanner)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (ctx, c) {
                          final fs = c.maxHeight * 0.68;
                          return ClipRect(
                            child: Center(
                              child: Text(
                                _watermarkCode,
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

                if (_hasBanner)
                  Image.network(
                    client.mediaUri(test.bannerImageId).toString(),
                    headers: client.authHeaders,
                    fit: BoxFit.cover,
                    cacheWidth: imageCacheWidth,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    loadingBuilder:
                        (_, child, progress) =>
                            progress == null ? child : const SizedBox.shrink(),
                  ),

                // Bottom darkening gradient
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
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

                // Top-left brand pill — "MOCK 01"
                Positioned(
                  top: 18,
                  left: 22,
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
                      'MOCK $_indexCode',
                      style: AppTypography.labelUppercase.copyWith(
                        color: textColor,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // Title + subtitle bottom-left
                Positioned(
                  left: 22,
                  right: 80,
                  bottom: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        test.title,
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
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  right: 20,
                  bottom: 26,
                  child: Container(
                    width: 36,
                    height: 36,
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

                // Accent strip pinned to bottom edge
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
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
