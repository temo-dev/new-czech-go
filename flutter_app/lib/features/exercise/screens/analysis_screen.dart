import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/primary_button.dart';
import '../widgets/result_card.dart';

/// Full-screen analysis flow: uploads the recorded attempt, polls until the
/// backend finishes processing, then renders the final ResultCard.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.client,
    required this.attemptId,
    required this.audioPath,
    required this.fileSizeBytes,
    required this.durationMs,
    this.onOpenNext,
  });

  final ApiClient client;
  final String attemptId;
  final String audioPath;
  final int fileSizeBytes;
  final int durationMs;
  final VoidCallback? onOpenNext;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  String _status = 'uploading';
  String? _error;
  AttemptResult? _result;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      await widget.client.submitRecordedAudio(
        widget.attemptId,
        audioPath: widget.audioPath,
        mimeType: 'audio/m4a',
        fileSizeBytes: widget.fileSizeBytes,
        durationMs: widget.durationMs,
      );
      if (!mounted) return;
      setState(() => _status = 'processing');
      _poller = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final attempt = AttemptResult.fromJson(
            await widget.client.getAttempt(widget.attemptId),
          );
          if (!mounted) return;
          setState(() {
            _result = attempt;
            _status = attempt.status;
          });
          if (attempt.status == 'completed' || attempt.status == 'failed') {
            _poller?.cancel();
          }
        } catch (err) {
          if (!mounted) return;
          setState(() {
            _status = 'failed';
            _error = err.toString();
          });
          _poller?.cancel();
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _status = 'failed';
        _error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final result = _result;
    final showResult = result != null && result.status == 'completed';
    final showFailure = _status == 'failed';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.analysisScreenTitle),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH(context),
          vertical: AppSpacing.x5,
        ),
        children: [
          if (showResult)
            ResultCard(
              client: widget.client,
              result: result,
              onRetry: () => Navigator.of(context).pop(),
              onNext: widget.onOpenNext == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      widget.onOpenNext!();
                    },
            )
          else if (showFailure)
            _FailureBlock(
              title: l.analysisFailedTitle,
              body: _error ?? l.statusCopyFailed,
              retryLabel: l.analysisRetryCta,
              onRetry: () => Navigator.of(context).pop(),
            )
          else
            _ProgressBlock(
              label: _status == 'uploading'
                  ? l.analysisUploading
                  : l.analysisProcessing,
            ),
        ],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
      child: Column(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureBlock extends StatelessWidget {
  const _FailureBlock({
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
  });
  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.titleLarge.copyWith(color: AppColors.error),
        ),
        const SizedBox(height: AppSpacing.x3),
        Text(body, style: AppTypography.bodyMedium),
        const SizedBox(height: AppSpacing.x5),
        PrimaryButton(
          label: retryLabel,
          icon: Icons.arrow_back,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
