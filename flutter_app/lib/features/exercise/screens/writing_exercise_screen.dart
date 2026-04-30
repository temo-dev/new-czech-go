import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/locale/locale_scope.dart';
import '../../../core/voice/voice_preference_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../widgets/result_card.dart';

/// Text-input exercise screen for psani_1_formular and psani_2_email.
///
/// Flow: display prompts → learner types → client-side word count gate →
/// createAttempt → submitText → push AnalysisScreen (polls until completed).
class WritingExerciseScreen extends StatefulWidget {
  const WritingExerciseScreen({
    super.key,
    required this.client,
    required this.detail,
    this.onAttemptCompleted,
    this.showResultOnCompletion = true,
  });

  final ApiClient client;
  final ExerciseDetail detail;

  /// Called with the attempt_id after the attempt is submitted successfully.
  final FutureOr<void> Function(String attemptId)? onAttemptCompleted;
  final bool showResultOnCompletion;

  @override
  State<WritingExerciseScreen> createState() => _WritingExerciseScreenState();
}

class _WritingExerciseScreenState extends State<WritingExerciseScreen> {
  // psani_1: one controller per question (3 total)
  late final List<TextEditingController> _controllers;
  // psani_2: single controller
  late final TextEditingController _emailController;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.detail;
    if (d.isPsani1) {
      final count = d.writingQuestions.isEmpty ? 3 : d.writingQuestions.length;
      _controllers = List.generate(count, (_) => TextEditingController());
      _emailController = TextEditingController();
    } else {
      _controllers = [];
      _emailController = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _emailController.dispose();
    super.dispose();
  }

  int _wordCount(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  bool get _hasEnoughWords {
    final d = widget.detail;
    if (d.isPsani1) {
      final min = d.writingMinWords;
      return _controllers.every((c) => _wordCount(c.text) >= min);
    }
    return _wordCount(_emailController.text) >= d.writingMinWords;
  }

  Future<void> _submit() async {
    if (!_hasEnoughWords || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final locale = LocaleScope.of(context).code;
      final attempt = await widget.client.createAttempt(
        widget.detail.id,
        locale: locale,
      );
      final attemptId = attempt['id'] as String;

      final voiceId = await VoicePreferenceService.readCurrent();
      final voiceArg = voiceId.isNotEmpty ? voiceId : null;
      if (widget.detail.isPsani1) {
        await widget.client.submitText(
          attemptId,
          answers: _controllers.map((c) => c.text.trim()).toList(),
          preferredVoiceId: voiceArg,
        );
      } else {
        await widget.client.submitText(
          attemptId,
          text: _emailController.text.trim(),
          preferredVoiceId: voiceArg,
        );
      }

      if (!mounted) return;
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder:
              (_) => _WritingResultPoller(
                client: widget.client,
                attemptId: attemptId,
                showResultOnCompletion: widget.showResultOnCompletion,
              ),
        ),
      );
      // Fire after AnalysisScreen pops — writing attempt is completed by then.
      if (mounted && (completed ?? widget.showResultOnCompletion)) {
        await widget.onAttemptCompleted?.call(attemptId);
      }
      if (mounted && !widget.showResultOnCompletion && (completed ?? false)) {
        Navigator.of(context).pop();
      } else if (mounted &&
          !widget.showResultOnCompletion &&
          completed == false) {
        setState(() => _error = AppLocalizations.of(context).statusCopyFailed);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          d.isPsani1
              ? 'Psaní 1 — Formulář'
              : 'Psaní 2 — E-mail', // Czech exercise names, not translated
          style: AppTypography.titleMedium,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            if (d.learnerInstruction.isNotEmpty) ...[
              Text(d.learnerInstruction, style: AppTypography.bodyMedium),
              const SizedBox(height: AppSpacing.x4),
            ],
            if (d.isPsani1) ..._buildPsani1Fields(d),
            if (d.isPsani2) ..._buildPsani2Fields(d),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                _error!,
                style: AppTypography.bodySmall.copyWith(color: Colors.red),
              ),
            ],
            const SizedBox(height: AppSpacing.x6),
            FilledButton(
              onPressed: (_hasEnoughWords && !_submitting) ? _submit : null,
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
                        AppLocalizations.of(context).submitWritingCta,
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

  List<Widget> _buildPsani1Fields(ExerciseDetail d) {
    final questions =
        d.writingQuestions.isEmpty
            ? List.generate(
              3,
              (i) =>
                  AppLocalizations.of(context).writingQuestionFallback(i + 1),
            )
            : d.writingQuestions;
    return List.generate(questions.length, (i) {
      final words = _wordCount(_controllers[i].text);
      final enough = words >= d.writingMinWords;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${i + 1}. ${questions[i]}', style: AppTypography.labelLarge),
            const SizedBox(height: 6),
            ListenableBuilder(
              listenable: _controllers[i],
              builder:
                  (_, __) => TextField(
                    controller: _controllers[i],
                    maxLines: 4,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      suffixText: '$words/${d.writingMinWords} từ',
                      suffixStyle: TextStyle(
                        color: enough ? AppColors.secondary : Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
            ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildPsani2Fields(ExerciseDetail d) {
    final topics =
        d.emailTopics.isEmpty
            ? const [
              'KDE JSTE?',
              'JAK DLOUHO TAM JSTE?',
              'KDE BYDLÍTE?',
              'CO DĚLÁTE DOPOLEDNE?',
              'CO DĚLÁTE ODPOLEDNE?',
            ]
            : d.emailTopics;
    final words = _wordCount(_emailController.text);
    final enough = words >= d.writingMinWords;
    return [
      if (d.emailPrompt.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Text(d.emailPrompt, style: AppTypography.bodyMedium),
        ),
        const SizedBox(height: AppSpacing.x4),
      ],
      Text(
        AppLocalizations.of(context).writingTopicsLabel,
        style: AppTypography.labelMedium,
      ),
      const SizedBox(height: 8),
      ...topics.asMap().entries.map(
        (e) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${e.key + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                e.value,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.x4),
      ListenableBuilder(
        listenable: _emailController,
        builder:
            (_, __) => TextField(
              controller: _emailController,
              maxLines: 10,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: AppLocalizations.of(context).writingEmailHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixText: '$words/${d.writingMinWords} từ',
                suffixStyle: TextStyle(
                  color: enough ? AppColors.secondary : Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
      ),
    ];
  }
}

/// Polls backend until writing attempt is completed, then shows ResultCard.
class _WritingResultPoller extends StatefulWidget {
  const _WritingResultPoller({
    required this.client,
    required this.attemptId,
    required this.showResultOnCompletion,
  });
  final ApiClient client;
  final String attemptId;
  final bool showResultOnCompletion;

  @override
  State<_WritingResultPoller> createState() => _WritingResultPollerState();
}

class _WritingResultPollerState extends State<_WritingResultPoller> {
  AttemptResult? _result;
  String? _error;
  Timer? _timer;
  int _retries = 0;
  static const _maxRetries = 60; // 2 minutes at 2s interval

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
          child: Text(
            _error!,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
          ),
        ),
      );
    }
    if (_result != null && _result!.status == 'completed') {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: ResultCard(
              result: _result!,
              client: widget.client,
              onRetry: () => Navigator.of(context).pop(),
            ),
          ),
        ),
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
