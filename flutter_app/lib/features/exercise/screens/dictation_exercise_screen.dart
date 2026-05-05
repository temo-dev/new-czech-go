import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/locale/locale_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../widgets/czech_keyboard_chips.dart';
import '../widgets/dictation_audio_card.dart';
import '../widgets/dictation_ocr_preview_card.dart';
import '../widgets/dictation_result_card.dart';
import '../widgets/exercise_context_image.dart';

/// V18.1: Camera/gallery image picker. Injectable for widget tests so they
/// can simulate a learner picking a photo without touching the platform
/// channel. Defaults to the real ImagePicker.pickImage(camera).
typedef DictationImagePicker = Future<File?> Function();

Future<File?> _defaultPickImage() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return File(picked.path);
}

/// V18 — Stepper screen for psani_3_dictation.
///
/// Flow per sentence: audio auto-plays once, learner types, taps Next.
/// Last sentence's Next becomes Submit. Submit → createAttempt →
/// submitDictation → push DictationResultPoller (poll → DictationResultCard).
class DictationExerciseScreen extends StatefulWidget {
  const DictationExerciseScreen({
    super.key,
    required this.client,
    required this.detail,
    this.onAttemptCompleted,
    this.showResultOnCompletion = true,
    this.imagePicker,
  });

  final ApiClient client;
  final ExerciseDetail detail;
  final FutureOr<void> Function(String attemptId)? onAttemptCompleted;
  final bool showResultOnCompletion;

  /// V18.1: Override the default camera-based picker. Tests inject a stub
  /// that returns a fixture File without going through platform channels.
  final DictationImagePicker? imagePicker;

  @override
  State<DictationExerciseScreen> createState() =>
      _DictationExerciseScreenState();
}

// V18.1: per-sentence OCR submission state. `idle` means the learner has not
// taken a photo yet; `uploading` is the in-flight preview call;
// `previewing` shows the editable card; `confirmed` locks the sentence.
enum _OCRStage { idle, uploading, previewing, confirmed }

class _DictationExerciseScreenState extends State<DictationExerciseScreen> {
  late final List<TextEditingController> _controllers;
  late final List<int> _replayCounts;
  // V18.1 per-sentence state. Only used when the exercise opts into OCR.
  late List<_OCRStage> _ocrStage;
  late List<bool> _useOCR; // for `both` mode — per-sentence learner choice
  late List<String> _assetIds; // confirmed asset_id per sentence (OCR rows)
  late List<String> _photoUrls; // local preview URL or remote, used by card
  late List<String> _ocrPreviewText; // most recent OCR result for this sentence
  late List<String?> _ocrFailedBanner; // null when no banner needed
  int _currentIdx = 0;
  bool _submitting = false;
  String? _error;
  // V18.1: lazily-created attempt ID. The preview endpoint requires an
  // existing attempt, so OCR/Both modes provision one on first use rather
  // than at submit time (V18 type-only flow continues to create at submit).
  String? _attemptId;

  @override
  void initState() {
    super.initState();
    final n = widget.detail.dictationSentences.length;
    _controllers = List.generate(n, (_) => TextEditingController());
    _replayCounts = List.filled(n, 0);
    _ocrStage = List.filled(n, _OCRStage.idle);
    // For OCR-only mode, default every sentence to the OCR path. For Both
    // mode, default to type unless the learner toggles. Type-only ignores.
    _useOCR = List.filled(n, widget.detail.dictationIsOCRMode);
    _assetIds = List.filled(n, '');
    _photoUrls = List.filled(n, '');
    _ocrPreviewText = List.filled(n, '');
    _ocrFailedBanner = List.filled(n, null);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isOCRSentence(int i) {
    if (widget.detail.dictationIsOCRMode) return true;
    if (widget.detail.dictationIsBothMode) return _useOCR[i];
    return false;
  }

  bool _isSentenceReady(int i) {
    if (_isOCRSentence(i)) return _ocrStage[i] == _OCRStage.confirmed;
    return _controllers[i].text.trim().isNotEmpty;
  }

  bool get _canAdvance => _isSentenceReady(_currentIdx) && !_submitting;

  bool get _isLast => _currentIdx == widget.detail.dictationSentences.length - 1;

  // V18.1: kicks off the preview flow. Picks an image, posts to the preview
  // endpoint, fills the editable card. All errors flip the row back to idle
  // and surface a banner so the learner can retake or fall through to typing
  // (in `both` mode).
  Future<void> _startOCRPreview(int i) async {
    final picker = widget.imagePicker ?? _defaultPickImage;
    final file = await picker();
    if (file == null) return;
    setState(() {
      _ocrStage[i] = _OCRStage.uploading;
      _photoUrls[i] = file.path;
      _ocrFailedBanner[i] = null;
    });
    try {
      final attemptId = await _ensureAttempt();
      final preview = await widget.client.dictationOCRPreview(
        attemptId: attemptId,
        idx: i,
        image: file,
      );
      if (!mounted) return;
      setState(() {
        _ocrPreviewText[i] = preview.text;
        _assetIds[i] = preview.assetId;
        _ocrStage[i] = _OCRStage.previewing;
        if (preview.text.isEmpty) {
          _ocrFailedBanner[i] =
              AppLocalizations.of(context).dictationOCRFailedBanner;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocrStage[i] = _OCRStage.idle;
        _ocrFailedBanner[i] = e.toString();
      });
    }
  }

  void _confirmOCRPreview(int i, String text) {
    setState(() {
      _controllers[i].text = text.trim();
      _ocrStage[i] = _OCRStage.confirmed;
    });
  }

  void _retakeOCR(int i) {
    setState(() {
      _ocrStage[i] = _OCRStage.idle;
      _photoUrls[i] = '';
      _ocrPreviewText[i] = '';
      _assetIds[i] = '';
      _ocrFailedBanner[i] = null;
    });
  }

  void _toggleBothMode(int i, bool useOCR) {
    setState(() {
      _useOCR[i] = useOCR;
      // Reset progress when switching modes so we don't carry stale state.
      _ocrStage[i] = _OCRStage.idle;
      _photoUrls[i] = '';
      _ocrPreviewText[i] = '';
      _assetIds[i] = '';
      _ocrFailedBanner[i] = null;
      _controllers[i].clear();
    });
  }

  void _goPrev() {
    if (_currentIdx == 0) return;
    setState(() => _currentIdx -= 1);
  }

  void _goNext() {
    if (!_canAdvance) return;
    if (_isLast) {
      _submit();
    } else {
      setState(() => _currentIdx += 1);
    }
  }

  Future<String> _ensureAttempt() async {
    final existing = _attemptId;
    if (existing != null && existing.isNotEmpty) return existing;
    final locale = LocaleScope.of(context).code;
    final attempt = await widget.client.createAttempt(
      widget.detail.id,
      locale: locale,
    );
    _attemptId = attempt['id'] as String;
    return _attemptId!;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final attemptId = await _ensureAttempt();

      // V18.1: route to OCR endpoint when any sentence used the photo path
      // (OCR-only mode or any toggled `both` row). Otherwise stay on the
      // V18 JSON submit-text path so backward-compat tests keep passing.
      final anyOCR = List.generate(_controllers.length, (i) => _isOCRSentence(i))
          .any((v) => v);
      if (anyOCR) {
        final rows = <DictationOCRSentenceSubmission>[];
        for (int i = 0; i < _controllers.length; i++) {
          rows.add(DictationOCRSentenceSubmission(
            idx: i,
            text: _controllers[i].text.trim(),
            assetId: _isOCRSentence(i) ? _assetIds[i] : '',
            replayCount: _replayCounts[i],
          ));
        }
        await widget.client.submitDictationOCR(attemptId, sentences: rows);
      } else {
        final sentences = <DictationSentenceSubmission>[];
        for (int i = 0; i < _controllers.length; i++) {
          sentences.add(DictationSentenceSubmission(
            idx: i,
            text: _controllers[i].text.trim(),
            replayCount: _replayCounts[i],
          ));
        }
        await widget.client.submitDictation(attemptId, sentences: sentences);
      }

      if (!mounted) return;
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _DictationResultPoller(
            client: widget.client,
            attemptId: attemptId,
            showResultOnCompletion: widget.showResultOnCompletion,
          ),
        ),
      );
      if (mounted && (completed ?? widget.showResultOnCompletion)) {
        await widget.onAttemptCompleted?.call(attemptId);
      }
      if (mounted && !widget.showResultOnCompletion && (completed ?? false)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = widget.detail;
    final total = d.dictationSentences.length;
    if (total == 0) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text(d.title, style: AppTypography.titleMedium),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Text(
              'Bài này chưa có câu. Vui lòng quay lại sau.',
              style: AppTypography.bodyMedium,
            ),
          ),
        ),
      );
    }

    final sentence = d.dictationSentences[_currentIdx];
    final controller = _controllers[_currentIdx];
    final progress = (_currentIdx + 1) / total;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(d.title, style: AppTypography.titleMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            ExerciseContextImage(detail: d, client: widget.client),
            Row(
              children: [
                Text(
                  l.dictationSentenceLabel(_currentIdx + 1, total),
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          AppColors.onSurface.withValues(alpha: 0.08),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            DictationAudioCard(
              key: ValueKey('audio-$_currentIdx'),
              client: widget.client,
              audioAssetId: sentence.audioAssetId,
              maxReplays: d.dictationMaxReplaysPerSentence,
              sentenceIdx: _currentIdx,
              totalSentences: total,
              initialReplayCount: _replayCounts[_currentIdx],
              onReplayCountChanged: (n) {
                setState(() => _replayCounts[_currentIdx] = n);
              },
            ),
            const SizedBox(height: AppSpacing.x3),
            if (d.dictationIsBothMode) ...[
              _ModeTogglePill(
                useOCR: _useOCR[_currentIdx],
                onChanged: (v) => _toggleBothMode(_currentIdx, v),
              ),
              const SizedBox(height: AppSpacing.x2),
            ],
            if (_isOCRSentence(_currentIdx))
              _buildOCRInput(_currentIdx)
            else ...[
              _InputCard(
                controller: controller,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.x2),
              CzechKeyboardChips(controller: controller),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x3),
              Text(
                _error!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.x6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _currentIdx == 0 || _submitting ? null : _goPrev,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: AppColors.onSurface.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(l.dictationPrevBtn),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: FilledButton(
                    onPressed: _canAdvance ? _goNext : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLast ? l.dictationSubmitBtn : l.dictationNextBtn,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // V18.1: render the OCR-mode UI for sentence `i`. Idle → camera button.
  // Uploading → spinner card. Previewing → editable preview card. Confirmed
  // → compact summary with edit affordance.
  Widget _buildOCRInput(int i) {
    final l = AppLocalizations.of(context);
    switch (_ocrStage[i]) {
      case _OCRStage.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              key: const Key('ocr-take-photo'),
              onPressed: _submitting ? null : () => _startOCRPreview(i),
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(l.dictationModeOCRLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
            if (_ocrFailedBanner[i] != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                _ocrFailedBanner[i]!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
          ],
        );
      case _OCRStage.uploading:
      case _OCRStage.previewing:
        return DictationOCRPreviewCard(
          photoUrl: _photoUrls[i],
          ocrText: _ocrPreviewText[i],
          isUploading: _ocrStage[i] == _OCRStage.uploading,
          uploadingHint: l.dictationOCRUploadingHint,
          previewTitle: l.dictationOCRPreviewTitle,
          previewHint: l.dictationOCRPreviewHint,
          confirmLabel: l.dictationOCRConfirmBtn,
          retakeLabel: l.dictationOCRRetakeBtn,
          failedBanner: _ocrFailedBanner[i],
          onRetake: () => _retakeOCR(i),
          onConfirm: (text) => _confirmOCRPreview(i, text),
        );
      case _OCRStage.confirmed:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.x3),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _controllers[i].text,
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.x2),
              TextButton.icon(
                onPressed: () => _retakeOCR(i),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.dictationOCRRetakeBtn),
              ),
            ],
          ),
        );
    }
  }
}

class _ModeTogglePill extends StatelessWidget {
  const _ModeTogglePill({required this.useOCR, required this.onChanged});
  final bool useOCR;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      key: const Key('mode-toggle-pill'),
      children: [
        Expanded(
          child: ChoiceChip(
            label: Text(l.dictationModeTypeLabel),
            selected: !useOCR,
            onSelected: (_) => onChanged(false),
          ),
        ),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: ChoiceChip(
            label: Text(l.dictationModeOCRLabel),
            selected: useOCR,
            onSelected: (_) => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.dictationListenInstruction,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            maxLines: 3,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.onSurface),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _DictationResultPoller extends StatefulWidget {
  const _DictationResultPoller({
    required this.client,
    required this.attemptId,
    required this.showResultOnCompletion,
  });
  final ApiClient client;
  final String attemptId;
  final bool showResultOnCompletion;

  @override
  State<_DictationResultPoller> createState() => _DictationResultPollerState();
}

class _DictationResultPollerState extends State<_DictationResultPoller> {
  AttemptResult? _result;
  String? _error;
  Timer? _timer;
  int _retries = 0;
  static const _maxRetries = 60;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _poll() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (++_retries > _maxRetries) {
        _timer?.cancel();
        if (mounted) {
          setState(() => _error = AppLocalizations.of(context).scoringTimeout);
        }
        return;
      }
      try {
        final raw = await widget.client.getAttempt(widget.attemptId);
        final attempt = AttemptResult.fromJson(raw);
        if (!mounted) return;
        if (attempt.status == 'completed' || attempt.status == 'failed') {
          _timer?.cancel();
          if (!widget.showResultOnCompletion) {
            Navigator.of(context).pop(attempt.status == 'completed');
            return;
          }
          setState(() => _result = attempt);
        }
      } catch (e) {
        _timer?.cancel();
        if (mounted) setState(() => _error = e.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Text(
              _error!,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final dict = _result?.feedback?.dictationResult;
    if (_result != null && _result!.status == 'completed' && dict != null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(child: DictationResultCard(result: dict)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: AppSpacing.x4),
            Text(
              AppLocalizations.of(context).scoringInProgress,
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
