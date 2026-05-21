import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/app_notification.dart';
import '../objective_submit_error.dart';
import '../widgets/ano_ne_widget.dart';
import '../widgets/exercise_context_image.dart';
import '../widgets/fill_in_widget.dart';
import '../widgets/multiple_choice_widget.dart';
import '../widgets/objective_result_card.dart';

/// Screen for all poslech_* exercise types.
///
/// Flow: show audio player → learner answers → submit answers (sync) → result.
///
/// V26 — when every poslech_1 item has its own `audio_source.asset_id`, the
/// screen renders one mini-player per question card instead of a single
/// top-level player. Falls back to the merged-audio path for legacy seeds.
class ListeningExerciseScreen extends StatefulWidget {
  const ListeningExerciseScreen({
    super.key,
    required this.client,
    required this.detail,
    this.onAttemptCompleted,
    this.showResultOnCompletion = true,
    this.onOpenNext,
  });

  final ApiClient client;
  final ExerciseDetail detail;
  final FutureOr<void> Function(String attemptId)? onAttemptCompleted;
  final bool showResultOnCompletion;
  // Daily-sprint queue advance — see ReadingExerciseScreen for shape.
  final VoidCallback? onOpenNext;

  @override
  State<ListeningExerciseScreen> createState() =>
      _ListeningExerciseScreenState();
}

class _ListeningExerciseScreenState extends State<ListeningExerciseScreen> {
  // Legacy single-audio player. Only initialised when [_usePerItemAudio] is
  // false (older seeds without per-item asset_ids).
  final AudioPlayer _legacyPlayer = AudioPlayer();
  // V26 — coordinates "only one item plays at a time" across mini-players.
  final _PlaybackCoordinator _coordinator = _PlaybackCoordinator();

  final Map<String, String> _answers = {};

  bool _audioLoading = true;
  bool _audioError = false;
  bool _submitting = false;
  String? _submitError;
  AttemptResult? _result;

  bool get _usePerItemAudio => itemsHavePerItemAudio(widget.detail);

  @override
  void initState() {
    super.initState();
    if (_usePerItemAudio) {
      // Per-item players each load on first tap; nothing to do here.
      _audioLoading = false;
    } else {
      _loadLegacyAudio();
    }
  }

  @override
  void dispose() {
    _legacyPlayer.dispose();
    _coordinator.dispose();
    super.dispose();
  }

  Future<void> _loadLegacyAudio() async {
    setState(() {
      _audioLoading = true;
      _audioError = false;
    });
    try {
      await _legacyPlayer.setAudioSource(
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
      if (d.anoNeStatements.isEmpty) return false;
      return d.anoNeStatements.every(
        (s) => _answers[s.questionNo.toString()]?.isNotEmpty == true,
      );
    }
    if (d.isPoslech5) {
      return d.poslechQuestions.every(
        (q) => _answers[q.questionNo.toString()]?.isNotEmpty == true,
      );
    }
    // Use the wire `question_no` (not the index) — when admins delete or
    // reorder items in CMS, question_no can skip values (e.g. [1,3,4,5]) and
    // the answer keys we store in `_answers` follow item.questionNo. Falling
    // back to (i+1) for legacy seeds that have no question_no.
    if (d.poslechItems.isNotEmpty) {
      return d.poslechItems.asMap().entries.every((e) {
        final key =
            e.value.questionNo > 0
                ? e.value.questionNo.toString()
                : (e.key + 1).toString();
        return _answers[key]?.isNotEmpty == true;
      });
    }
    return List.generate(
      5,
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
          _submitError = objectiveSubmitErrorMessage(
            AppLocalizations.of(context),
            e,
          );
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
              onNext: widget.onOpenNext,
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
          d.title.isNotEmpty
              ? d.title
              : d.exerciseType.replaceAll('_', ' ').toUpperCase(),
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

            // Top-level audio player — only in legacy single-audio mode.
            if (!_usePerItemAudio) ...[
              _LegacyAudioPlayerBar(
                player: _legacyPlayer,
                loading: _audioLoading,
                error: _audioError,
                onRetry: _loadLegacyAudio,
              ),
              const SizedBox(height: AppSpacing.x4),
            ],

            // Answer UI
            if (d.isPoslech6)
              AnoNeWidget(
                statements: d.anoNeStatements,
                onAnswersChanged:
                    (a) => setState(() {
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
              AppNotification.error(message: _submitError!),
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
      // Fallback: 5 generic A-D questions (no per-item audio).
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
            if (_usePerItemAudio) ...[
              _ItemAudioPlayerBar(
                audioUri: widget.client.mediaUri(item.audioAssetId),
                authHeaders: widget.client.authHeaders,
                coordinator: _coordinator,
                playerId: item.questionNo,
              ),
              const SizedBox(height: AppSpacing.x2),
            ],
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
              onSelect:
                  (k) =>
                      setState(() => _answers[item.questionNo.toString()] = k),
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

/// V26 — true when the exercise has poslech items and every item carries an
/// `audio_source.asset_id`. The screen uses this flag to switch between the
/// per-item player layout and the legacy single-audio player.
@visibleForTesting
bool itemsHavePerItemAudio(ExerciseDetail detail) {
  if (detail.exerciseType != 'poslech_1') return false;
  if (detail.poslechItems.isEmpty) return false;
  return detail.poslechItems.every((it) => it.audioAssetId.isNotEmpty);
}

/// Tiny notifier that lets per-item players pause each other so two questions
/// don't play at the same time. Player 0 = nothing playing.
class _PlaybackCoordinator extends ChangeNotifier {
  int _active = 0;
  int get active => _active;
  void claim(int id) {
    if (_active == id) return;
    _active = id;
    notifyListeners();
  }

  void release(int id) {
    if (_active != id) return;
    _active = 0;
    notifyListeners();
  }
}

class _LegacyAudioPlayerBar extends StatefulWidget {
  const _LegacyAudioPlayerBar({
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
  State<_LegacyAudioPlayerBar> createState() => _LegacyAudioPlayerBarState();
}

class _LegacyAudioPlayerBarState extends State<_LegacyAudioPlayerBar> {
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
    return _AudioBarShell(
      loading: widget.loading,
      error: widget.error,
      playing: _playing,
      onRetry: widget.onRetry,
      onTogglePlay: () async {
        if (_playing) {
          await widget.player.pause();
        } else {
          await widget.player.seek(Duration.zero);
          await widget.player.play();
        }
      },
    );
  }
}

/// V26 — per-item audio bar. Lazy-loads its source on first play, registers
/// with the [_PlaybackCoordinator] so other items pause when this one starts.
class _ItemAudioPlayerBar extends StatefulWidget {
  const _ItemAudioPlayerBar({
    required this.audioUri,
    required this.authHeaders,
    required this.coordinator,
    required this.playerId,
  });
  final Uri audioUri;
  final Map<String, String> authHeaders;
  final _PlaybackCoordinator coordinator;
  final int playerId;

  @override
  State<_ItemAudioPlayerBar> createState() => _ItemAudioPlayerBarState();
}

class _ItemAudioPlayerBarState extends State<_ItemAudioPlayerBar> {
  AudioPlayer? _player;
  bool _loading = false;
  bool _error = false;
  bool _playing = false;
  bool _sourceLoaded = false;
  StreamSubscription<PlayerState>? _sub;

  @override
  void initState() {
    super.initState();
    widget.coordinator.addListener(_onCoordinatorChanged);
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_onCoordinatorChanged);
    _sub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  void _onCoordinatorChanged() {
    if (widget.coordinator.active != widget.playerId && _playing) {
      _player?.pause();
    }
  }

  Future<void> _ensurePlayer() async {
    if (_sourceLoaded) return;
    _loading = true;
    setState(() {});
    _player ??= AudioPlayer();
    _sub ??= _player!.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s.playing);
      if (s.processingState == ProcessingState.completed) {
        widget.coordinator.release(widget.playerId);
      }
    });
    try {
      await _player!.setAudioSource(
        AudioSource.uri(widget.audioUri, headers: widget.authHeaders),
      );
      _sourceLoaded = true;
      _error = false;
    } catch (_) {
      _error = true;
    } finally {
      _loading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggle() async {
    await _ensurePlayer();
    if (_error || _player == null) return;
    if (_playing) {
      await _player!.pause();
      widget.coordinator.release(widget.playerId);
    } else {
      widget.coordinator.claim(widget.playerId);
      await _player!.seek(Duration.zero);
      await _player!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AudioBarShell(
      loading: _loading,
      error: _error,
      playing: _playing,
      onRetry: () {
        _sourceLoaded = false;
        _ensurePlayer();
      },
      onTogglePlay: _toggle,
    );
  }
}

/// Shared visual shell for both legacy and per-item audio bars. Centralises
/// the headphones row + play/pause icon so we only style this in one place.
class _AudioBarShell extends StatelessWidget {
  const _AudioBarShell({
    required this.loading,
    required this.error,
    required this.playing,
    required this.onTogglePlay,
    this.onRetry,
  });
  final bool loading;
  final bool error;
  final bool playing;
  final Future<void> Function() onTogglePlay;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (error) {
      return AppNotification.error(
        message: l.audioError,
        actionLabel: onRetry == null ? null : l.retry,
        onAction: onRetry,
      );
    }

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
                loading
                    ? Text(l.audioLoading, style: AppTypography.bodySmall)
                    : Text(l.audioHint, style: AppTypography.bodySmall),
          ),
          if (!error && !loading)
            IconButton(
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              color: AppColors.secondary,
              onPressed: () {
                onTogglePlay();
              },
            ),
        ],
      ),
    );
  }
}
