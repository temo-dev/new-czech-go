import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../widgets/matching_widget.dart';
import '../widgets/quizcard_widget.dart';

/// Sequential deck session for vocab/grammar exercises.
/// quizcard_basic: Anki-style (Đã biết removes, Ôn lại pushes back).
/// choice_word / fill_blank / matching: local scoring, always advance after answer.
/// No attempt API calls — fully local.
class DeckSessionScreen extends StatefulWidget {
  const DeckSessionScreen({
    super.key,
    required this.client,
    required this.moduleId,
    required this.exerciseType,
    required this.typeLabel,
    required this.exercises,
  });

  final ApiClient client;
  final String moduleId;
  final String exerciseType;
  final String typeLabel;
  final List<ExerciseSummary> exercises;

  @override
  State<DeckSessionScreen> createState() => _DeckSessionScreenState();
}

class _DeckSessionScreenState extends State<DeckSessionScreen> {
  late ListQueue<ExerciseSummary> _queue;
  final Set<String> _knownIds = {};
  int _totalCount = 0;
  ExerciseDetail? _currentDetail;
  bool _loadingDetail = false;
  bool _sessionComplete = false;

  @override
  void initState() {
    super.initState();
    _totalCount = widget.exercises.length;
    _queue = ListQueue.from(widget.exercises);
    _loadCurrentDetail();
  }

  Future<void> _loadCurrentDetail() async {
    if (_queue.isEmpty) return;
    setState(() { _loadingDetail = true; _currentDetail = null; });
    try {
      final raw = await widget.client.getExercise(_queue.first.id);
      if (!mounted) return;
      setState(() {
        _currentDetail = ExerciseDetail.fromJson(raw);
        _loadingDetail = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
    }
  }

  void _handleQuizcardChoice(String choice) {
    HapticFeedback.lightImpact();
    final current = _queue.removeFirst();
    if (choice == 'known') {
      _knownIds.add(current.id);
    } else {
      _queue.addLast(current);
    }
    if (_queue.isEmpty) {
      setState(() => _sessionComplete = true);
    } else {
      _loadCurrentDetail();
    }
  }

  void _advanceKnown() {
    HapticFeedback.lightImpact();
    _knownIds.add(_queue.removeFirst().id);
    if (_queue.isEmpty) {
      setState(() => _sessionComplete = true);
    } else {
      _loadCurrentDetail();
    }
  }

  Future<bool> _onWillPop() async {
    if (_sessionComplete || _queue.isEmpty) return true;
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deckConfirmExit),
        content: Text(l.deckConfirmExitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await _onWillPop();
        if (confirmed && mounted) Navigator.of(context).pop(); // ignore: use_build_context_synchronously
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              // ── App bar ──────────────────────────────────────────────
              _DeckAppBar(
                title: widget.typeLabel,
                onBack: () async {
                  final ok = await _onWillPop();
                  if (ok && mounted) Navigator.of(context).pop(); // ignore: use_build_context_synchronously
                },
              ),

              // ── Content ──────────────────────────────────────────────
              Expanded(
                child: _sessionComplete
                    ? _CompletionView(
                        knownCount: _knownIds.length,
                        totalCount: _totalCount,
                        onDone: () => Navigator.of(context).pop(),
                      )
                    : _DeckBody(
                        detail: _currentDetail,
                        loading: _loadingDetail,
                        knownCount: _knownIds.length,
                        totalCount: _totalCount,
                        onQuizcardChoice: _handleQuizcardChoice,
                        onAdvance: _advanceKnown,
                        client: widget.client,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _DeckAppBar extends StatelessWidget {
  const _DeckAppBar({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.pagePaddingH(context), AppSpacing.x3,
          AppSpacing.pagePaddingH(context), 0),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: const Icon(Icons.arrow_back, size: 22),
        ),
        const SizedBox(width: AppSpacing.x3),
        Text(title, style: AppTypography.titleMedium),
      ]),
    );
  }
}

// ── Deck body (progress + card) ───────────────────────────────────────────────

class _DeckBody extends StatelessWidget {
  const _DeckBody({
    required this.detail,
    required this.loading,
    required this.knownCount,
    required this.totalCount,
    required this.onQuizcardChoice,
    required this.onAdvance,
    required this.client,
  });

  final ExerciseDetail? detail;
  final bool loading;
  final int knownCount;
  final int totalCount;
  final void Function(String) onQuizcardChoice;
  final VoidCallback onAdvance;
  final ApiClient client;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = AppSpacing.pagePaddingH(context);

    return Column(
      children: [
        // ── Progress ─────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(h, AppSpacing.x4, h, AppSpacing.x2),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.deckKnownOf(knownCount, totalCount),
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                  Text(
                    '${totalCount > 0 ? (knownCount * 100 ~/ totalCount) : 0}%',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: totalCount > 0 ? knownCount / totalCount : 0,
                  minHeight: 6,
                  backgroundColor: AppColors.outlineVariant,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        // ── Card area ─────────────────────────────────────────────────
        Expanded(
          child: loading || detail == null
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary))
              : _CardArea(
                  detail: detail!,
                  onQuizcardChoice: onQuizcardChoice,
                  onAdvance: onAdvance,
                  client: client,
                ),
        ),
      ],
    );
  }
}

// ── Card area (dispatches to per-type card) ───────────────────────────────────

class _CardArea extends StatelessWidget {
  const _CardArea({
    required this.detail,
    required this.onQuizcardChoice,
    required this.onAdvance,
    required this.client,
  });

  final ExerciseDetail detail;
  final void Function(String) onQuizcardChoice;
  final VoidCallback onAdvance;
  final ApiClient client;

  @override
  Widget build(BuildContext context) {
    final h = AppSpacing.pagePaddingH(context);
    if (detail.isQuizcard) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: h),
        child: QuizcardWidget(
          front: detail.flashcardFront,
          back: detail.flashcardBack,
          example: detail.flashcardExample.isNotEmpty
              ? detail.flashcardExample
              : null,
          exampleTranslation: detail.flashcardExampleTranslation.isNotEmpty
              ? detail.flashcardExampleTranslation
              : null,
          imageUrl: detail.flashcardImageAssetId.isNotEmpty
              ? client.mediaUri(detail.flashcardImageAssetId).toString()
              : null,
          authHeaders: client.authHeaders,
          submitting: false,
          onChoice: onQuizcardChoice,
        ),
      );
    }
    if (detail.isChoiceWord) {
      return _ChoiceWordDeckCard(
          detail: detail, onAdvance: onAdvance, padding: h);
    }
    if (detail.isFillBlank) {
      return _FillBlankDeckCard(
          detail: detail, onAdvance: onAdvance, padding: h);
    }
    if (detail.isMatching) {
      return _MatchingDeckCard(detail: detail, onAdvance: onAdvance, padding: h);
    }
    return const SizedBox.shrink();
  }
}

// ── Choice word deck card ─────────────────────────────────────────────────────

class _ChoiceWordDeckCard extends StatefulWidget {
  const _ChoiceWordDeckCard({
    required this.detail,
    required this.onAdvance,
    required this.padding,
  });

  final ExerciseDetail detail;
  final VoidCallback onAdvance;
  final double padding;

  @override
  State<_ChoiceWordDeckCard> createState() => _ChoiceWordDeckCardState();
}

class _ChoiceWordDeckCardState extends State<_ChoiceWordDeckCard> {
  String? _selectedKey;
  bool _revealed = false;

  bool _isCorrect(String key) =>
      key.toLowerCase() ==
      (widget.detail.correctAnswers['1'] ?? '').toLowerCase();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = widget.detail;
    final h = widget.padding;
    // poslechOptions holds the choice_word options (key + text)
    final options = d.poslechOptions;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(h, AppSpacing.x4, h, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Grammar note ────────────────────────────────────────
                if (d.choiceWordGrammarNote.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x3),
                    margin: const EdgeInsets.only(bottom: AppSpacing.x3),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.secondary.withAlpha(60)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(d.choiceWordGrammarNote,
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.secondary))),
                    ]),
                  ),
                // ── Stem ────────────────────────────────────────────────
                Text(d.choiceWordStem.isNotEmpty
                    ? d.choiceWordStem
                    : l.vocabChoiceInstruction,
                    style: AppTypography.titleSmall
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.x4),
                // ── Options ─────────────────────────────────────────────
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.8,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: options.map((opt) {
                    Color bg = AppColors.surfaceContainerLow;
                    Color border = AppColors.outlineVariant;
                    Color fg = AppColors.onSurface;
                    if (_revealed) {
                      if (_isCorrect(opt.key)) {
                        bg = AppColors.success.withAlpha(25);
                        border = AppColors.success;
                        fg = AppColors.success;
                      } else if (_selectedKey == opt.key) {
                        bg = AppColors.error.withAlpha(20);
                        border = AppColors.error;
                        fg = AppColors.error;
                      }
                    } else if (_selectedKey == opt.key) {
                      bg = AppColors.primaryContainer;
                      border = AppColors.primary;
                      fg = AppColors.primary;
                    }
                    return GestureDetector(
                      onTap: _revealed
                          ? null
                          : () => setState(() {
                                _selectedKey = opt.key;
                                _revealed = true;
                              }),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${opt.key}  ${opt.text}',
                          style: AppTypography.bodySmall.copyWith(
                              color: fg, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // ── Result feedback ──────────────────────────────────────
                if (_revealed) ...[
                  const SizedBox(height: AppSpacing.x4),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x3),
                    decoration: BoxDecoration(
                      color: (_selectedKey != null &&
                              _isCorrect(_selectedKey!))
                          ? AppColors.success.withAlpha(20)
                          : AppColors.error.withAlpha(15),
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      (_selectedKey != null && _isCorrect(_selectedKey!))
                          ? l.deckCorrect
                          : l.deckWrong,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: (_selectedKey != null &&
                                _isCorrect(_selectedKey!))
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // ── Next button ───────────────────────────────────────────────
        if (_revealed)
          Padding(
            padding: EdgeInsets.fromLTRB(h, AppSpacing.x3, h, AppSpacing.x4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onAdvance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  elevation: 0,
                ),
                child: Text(l.deckNext),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Fill blank deck card ──────────────────────────────────────────────────────

class _FillBlankDeckCard extends StatefulWidget {
  const _FillBlankDeckCard({
    required this.detail,
    required this.onAdvance,
    required this.padding,
  });

  final ExerciseDetail detail;
  final VoidCallback onAdvance;
  final double padding;

  @override
  State<_FillBlankDeckCard> createState() => _FillBlankDeckCardState();
}

class _FillBlankDeckCardState extends State<_FillBlankDeckCard> {
  final _ctrl = TextEditingController();
  bool _submitted = false;
  bool _isCorrect = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final answer = _ctrl.text.trim();
    if (answer.isEmpty) return;
    final correct = widget.detail.correctAnswers['1'] ?? '';
    setState(() {
      _submitted = true;
      _isCorrect = answer.toLowerCase().contains(correct.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = widget.detail;
    final h = widget.padding;

    // Build sentence display — highlight "___"
    final parts = d.fillBlankSentence.split('___');
    final sentenceSpans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      sentenceSpans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        sentenceSpans.add(TextSpan(
          text: '___',
          style: TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.w800),
        ));
      }
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(h, AppSpacing.x4, h, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Sentence ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface),
                      children: sentenceSpans,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                // ── Input ──────────────────────────────────────────────
                if (!_submitted)
                  TextField(
                    controller: _ctrl,
                    enabled: !_submitted,
                    autofocus: true,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      hintText: l.vocabFillInstruction,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                // ── Result ─────────────────────────────────────────────
                if (_submitted) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x3),
                    decoration: BoxDecoration(
                      color: _isCorrect
                          ? AppColors.success.withAlpha(20)
                          : AppColors.error.withAlpha(15),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCorrect ? l.deckCorrect : l.deckWrong,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _isCorrect
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                        if (!_isCorrect) ...[
                          const SizedBox(height: 4),
                          Text(
                            '✓ ${widget.detail.correctAnswers['1'] ?? ''}',
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // ── Buttons ───────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(h, AppSpacing.x3, h, AppSpacing.x4),
          child: SizedBox(
            width: double.infinity,
            child: _submitted
                ? ElevatedButton(
                    onPressed: widget.onAdvance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      elevation: 0,
                    ),
                    child: Text(l.deckNext),
                  )
                : ElevatedButton(
                    onPressed: _ctrl.text.trim().isEmpty ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor:
                          AppColors.primary.withAlpha(100),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      elevation: 0,
                    ),
                    child: Text(l.confirm),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Matching deck card ────────────────────────────────────────────────────────

class _MatchingDeckCard extends StatefulWidget {
  const _MatchingDeckCard({
    required this.detail,
    required this.onAdvance,
    required this.padding,
  });

  final ExerciseDetail detail;
  final VoidCallback onAdvance;
  final double padding;

  @override
  State<_MatchingDeckCard> createState() => _MatchingDeckCardState();
}

class _MatchingDeckCardState extends State<_MatchingDeckCard> {
  final Map<String, String> _answers = {};

  bool get _allPaired =>
      _answers.length == widget.detail.matchingPairs.length &&
      _answers.values.every((v) => v.isNotEmpty);

  void _onPairChanged(String leftId, String rightId) {
    setState(() {
      if (rightId.isEmpty) {
        _answers.remove(leftId);
      } else {
        // Remove any existing entry with same rightId (un-pair previous)
        _answers.removeWhere((_, v) => v == rightId);
        _answers[leftId] = rightId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = widget.padding;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(h, AppSpacing.x3, h, 0),
            child: MatchingWidget(
              pairs: widget.detail.matchingPairs,
              answers: _answers,
              onChanged: _onPairChanged,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(h, AppSpacing.x3, h, AppSpacing.x4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _allPaired ? widget.onAdvance : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor: AppColors.primary.withAlpha(100),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                elevation: 0,
              ),
              child: Text(l.deckNext),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Completion view ───────────────────────────────────────────────────────────

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.knownCount,
    required this.totalCount,
    required this.onDone,
  });

  final int knownCount;
  final int totalCount;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = AppSpacing.pagePaddingH(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Icon ──────────────────────────────────────────────────
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(44),
            ),
            child: const Icon(Icons.celebration_rounded,
                size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.x5),
          // ── Title ─────────────────────────────────────────────────
          Text(l.deckSessionComplete,
              style: AppTypography.headlineMedium
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.x4),
          // ── Stat ──────────────────────────────────────────────────
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTypography.displaySmall.copyWith(
                  fontWeight: FontWeight.w900, color: AppColors.primary),
              children: [
                TextSpan(text: '$knownCount'),
                TextSpan(
                  text: ' / $totalCount',
                  style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.outline,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(l.deckKnownLabel,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.x6),
          // ── Done button ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                elevation: 0,
              ),
              child: Text(l.deckDone),
            ),
          ),
        ],
      ),
    );
  }
}
