import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../widgets/ano_ne_widget.dart';
import '../widgets/exercise_context_image.dart';
import '../widgets/fill_in_widget.dart';
import '../widgets/multiple_choice_widget.dart';
import '../widgets/objective_result_card.dart';

/// Screen for all poslech_* exercise types.
///
/// Flow: show audio player → learner answers → submit answers (sync) → result.
class ListeningExerciseScreen extends StatefulWidget {
  const ListeningExerciseScreen({
    super.key,
    required this.client,
    required this.detail,
    this.onAttemptCompleted,
    this.showResultOnCompletion = true,
  });

  final ApiClient client;
  final ExerciseDetail detail;
  final FutureOr<void> Function(String attemptId)? onAttemptCompleted;
  final bool showResultOnCompletion;

  @override
  State<ListeningExerciseScreen> createState() =>
      _ListeningExerciseScreenState();
}

class _ListeningExerciseScreenState extends State<ListeningExerciseScreen> {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _answers = {};

  bool _audioLoading = true;
  bool _audioError = false;
  bool _submitting = false;
  String? _submitError;
  AttemptResult? _result;

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    setState(() {
      _audioLoading = true;
      _audioError = false;
    });
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          widget.client.exerciseAudioUri(widget.detail.id),
          headers: widget.client.authHeaders,
        ),
      );
      if (mounted) setState(() => _audioLoading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _audioLoading = false;
          _audioError = true;
        });
      }
    }
  }

  bool get _hasAllAnswers {
    final d = widget.detail;
    if (d.isPoslech6) {
      return d.anoNeStatements.every(
        (s) => _answers[s.questionNo.toString()]?.isNotEmpty == true,
      );
    }
    if (d.isPoslech5) {
      return d.poslechQuestions.every(
        (q) => _answers[q.questionNo.toString()]?.isNotEmpty == true,
      );
    }
    final count = d.poslechItems.isNotEmpty ? d.poslechItems.length : 5;
    return List.generate(
      count,
      (i) => (i + 1).toString(),
    ).every((k) => _answers[k]?.isNotEmpty == true);
  }

  Future<void> _submit() async {
    if (!_hasAllAnswers || _submitting) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final attempt = await widget.client.createAttempt(
        widget.detail.id,
        locale: 'vi',
      );
      final attemptId = attempt['id'] as String;
      final raw = await widget.client.submitAnswers(attemptId, _answers);
      await widget.onAttemptCompleted?.call(attemptId);
      if (!mounted) return;
      if (!widget.showResultOnCompletion) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _result = AttemptResult.fromJson(raw));
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;

    if (_result != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text(
            AppLocalizations.of(context).resultScreenTitle,
            style: AppTypography.titleMedium,
          ),
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: ObjectiveResultCard(
              result: _result!,
              onRetry: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          d.exerciseType.replaceAll('_', ' ').toUpperCase(),
          style: AppTypography.titleMedium,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            ExerciseContextImage(detail: d, client: widget.client),

            if (d.learnerInstruction.isNotEmpty) ...[
              Text(d.learnerInstruction, style: AppTypography.bodyMedium),
              const SizedBox(height: AppSpacing.x4),
            ],

            // Audio player
            _AudioPlayerBar(
              player: _player,
              loading: _audioLoading,
              error: _audioError,
              onRetry: _loadAudio,
            ),
            const SizedBox(height: AppSpacing.x4),

            // Answer UI
            if (d.isPoslech6)
              AnoNeWidget(
                statements: d.anoNeStatements,
                onAnswersChanged: (a) => setState(() {
                  _answers
                    ..clear()
                    ..addAll(a);
                }),
                result: _result?.feedback?.objectiveResult,
                enabled: _result == null,
              )
            else if (d.isPoslech5)
              FillInWidget(
                questions: d.poslechQuestions,
                answers: _answers,
                onChanged: (k, v) => setState(() => _answers[k] = v),
              )
            else
              ..._buildItemAnswers(d),

            if (_submitError != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                _submitError!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ],

            const SizedBox(height: AppSpacing.x6),
            FilledButton(
              onPressed: (_hasAllAnswers && !_submitting) ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child:
                  _submitting
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        AppLocalizations.of(context).submitAnswersCta,
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItemAnswers(ExerciseDetail d) {
    final items = d.poslechItems;
    if (items.isEmpty) {
      // Fallback: 5 generic A-D questions
      return List.generate(5, (i) {
        final qno = i + 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x4),
          child: MultipleChoiceWidget(
            questionNo: qno,
            options: _defaultABCD(),
            selected: _answers[qno.toString()],
            onSelect: (k) => setState(() => _answers[qno.toString()] = k),
            mediaUri: widget.client.mediaUri,
            authHeaders: widget.client.authHeaders,
          ),
        );
      });
    }
    return items.map((item) {
      final opts = item.options.isNotEmpty ? item.options : d.poslechOptions;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.question.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                child: Text(
                  item.question,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            MultipleChoiceWidget(
              questionNo: item.questionNo,
              options: opts,
              selected: _answers[item.questionNo.toString()],
              onSelect: (k) => setState(() => _answers[item.questionNo.toString()] = k),
              mediaUri: widget.client.mediaUri,
              authHeaders: widget.client.authHeaders,
            ),
          ],
        ),
      );
    }).toList();
  }

  List<PoslechOptionView> _defaultABCD() => const [
    PoslechOptionView(key: 'A', text: 'A'),
    PoslechOptionView(key: 'B', text: 'B'),
    PoslechOptionView(key: 'C', text: 'C'),
    PoslechOptionView(key: 'D', text: 'D'),
  ];
}

class _AudioPlayerBar extends StatefulWidget {
  const _AudioPlayerBar({
    required this.player,
    required this.loading,
    required this.error,
    this.onRetry,
  });
  final AudioPlayer player;
  final bool loading;
  final bool error;
  final VoidCallback? onRetry;

  @override
  State<_AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<_AudioPlayerBar> {
  bool _playing = false;
  StreamSubscription<PlayerState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.player.playerStateStream.listen((s) {
      if (mounted) setState(() => _playing = s.playing);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.headphones_rounded, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child:
                widget.error
                    ? Text(
                      AppLocalizations.of(context).audioError,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    )
                    : widget.loading
                    ? Text(
                      AppLocalizations.of(context).audioLoading,
                      style: AppTypography.bodySmall,
                    )
                    : Text(
                      AppLocalizations.of(context).audioHint,
                      style: AppTypography.bodySmall,
                    ),
          ),
          if (widget.error && widget.onRetry != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.secondary,
              tooltip: 'Thử lại',
              onPressed: widget.onRetry,
            ),
          if (!widget.error && !widget.loading) ...[
            IconButton(
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              color: AppColors.secondary,
              onPressed: () async {
                if (_playing) {
                  await widget.player.pause();
                } else {
                  await widget.player.seek(Duration.zero);
                  await widget.player.play();
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
