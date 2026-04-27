import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/api/api_client.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/info_pill.dart';

/// Dispatches to the correct Uloha prompt widget based on exerciseType.
class UlohaPrompt extends StatelessWidget {
  const UlohaPrompt({super.key, required this.detail, required this.client});
  final ExerciseDetail detail;
  final ApiClient client;

  @override
  Widget build(BuildContext context) {
    return switch (detail.exerciseType) {
      'uloha_2_dialogue_questions' => _Uloha2Prompt(detail: detail),
      'uloha_3_story_narration'   => _Uloha3Prompt(detail: detail, client: client),
      'uloha_4_choice_reasoning'  => _Uloha4Prompt(detail: detail, client: client),
      _                           => _Uloha1Prompt(detail: detail),
    };
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

Widget _sectionCard({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.mdAll,
      ),
      child: child,
    );

Widget _hintCard(String text, {PillTone tone = PillTone.info}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: tone == PillTone.warning
            ? AppColors.warningContainer
            : AppColors.infoContainer,
        borderRadius: AppRadius.mdAll,
      ),
      child: Text(text, style: AppTypography.bodyMedium),
    );

// ── Uloha 1: Topic answers ─────────────────────────────────────────────────────

class _Uloha1Prompt extends StatelessWidget {
  const _Uloha1Prompt({required this.detail});
  final ExerciseDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final question in detail.questions) ...[
          _sectionCard(child: Text(question, style: AppTypography.bodyLarge)),
          const SizedBox(height: AppSpacing.x2),
        ],
      ],
    );
  }
}

// ── Uloha 2: Dialogue questions ────────────────────────────────────────────────

class _Uloha2Prompt extends StatelessWidget {
  const _Uloha2Prompt({required this.detail});
  final ExerciseDetail detail;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.scenarioTitle.isNotEmpty) ...[
          Text(detail.scenarioTitle, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (detail.scenarioPrompt.isNotEmpty) ...[
          _hintCard(detail.scenarioPrompt),
          const SizedBox(height: AppSpacing.x4),
        ],
        Text(l.promptRequiredInfoTitle, style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.x3),
        for (final slot in detail.requiredInfoSlots) ...[
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.label, style: AppTypography.titleSmall),
                if (slot.sampleQuestion.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    l.promptHintPrefix(slot.sampleQuestion),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
        ],
        if (detail.customQuestionHint.isNotEmpty) ...[
          _hintCard(l.promptCustomQuestion(detail.customQuestionHint),
              tone: PillTone.primary),
        ],
      ],
    );
  }
}

// ── Uloha 3: Story narration ───────────────────────────────────────────────────

class _Uloha3Prompt extends StatelessWidget {
  const _Uloha3Prompt({required this.detail, required this.client});
  final ExerciseDetail detail;
  final ApiClient client;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final images = detail.storyImageAssets;
    final missingCount = detail.imageAssetIds.length - images.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.storyTitle.isNotEmpty) ...[
          Text(detail.storyTitle, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.x3),
        ],
        if (images.isNotEmpty) ...[
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.x3),
              itemBuilder: (_, i) => _StoryImageCard(
                label: l.promptStoryImageLabel(i + 1),
                imageUrl: client
                    .exerciseAssetUri(detail.id, images[i].id)
                    .toString(),
                headers: client.authHeaders,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
        ],
        if (detail.imageAssetIds.isEmpty)
          _hintCard(l.promptStoryNoImages),
        if (missingCount > 0)
          _hintCard(
            l.promptStoryImagesLoaded(images.length, detail.imageAssetIds.length),
            tone: PillTone.warning,
          ),
        _hintCard(
          detail.imageAssetIds.isEmpty
              ? l.promptStoryHintOrder
              : l.promptStoryHintByImages(detail.imageAssetIds.length),
        ),
        const SizedBox(height: AppSpacing.x4),
        if (detail.narrativeCheckpoints.isNotEmpty) ...[
          Text(l.promptStoryCheckpointsTitle, style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.x3),
          for (final cp in detail.narrativeCheckpoints) ...[
            _sectionCard(child: Text(cp, style: AppTypography.bodyMedium)),
            const SizedBox(height: AppSpacing.x2),
          ],
        ],
        if (detail.grammarFocus.isNotEmpty)
          _hintCard(
            l.promptStoryGrammarFocus(detail.grammarFocus.join(', ')),
            tone: PillTone.primary,
          ),
      ],
    );
  }
}

class _StoryImageCard extends StatelessWidget {
  const _StoryImageCard({
    required this.label,
    required this.imageUrl,
    required this.headers,
  });
  final String label;
  final String imageUrl;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child: SizedBox(
        width: 132,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              headers: headers,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppColors.surfaceContainerLow,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceContainerLow,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xB3000000),
                  borderRadius: AppRadius.fullAll,
                ),
                child: Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Uloha 4: Choice & reasoning ───────────────────────────────────────────────

class _Uloha4Prompt extends StatelessWidget {
  const _Uloha4Prompt({required this.detail, required this.client});
  final ExerciseDetail detail;
  final ApiClient client;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.choiceScenarioPrompt.isNotEmpty) ...[
          _hintCard(detail.choiceScenarioPrompt),
          const SizedBox(height: AppSpacing.x4),
        ],
        Text(l.promptChoiceOptionsTitle, style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.x3),
        for (final option in detail.choiceOptions) ...[
          _ChoiceOptionCard(option: option, detail: detail, client: client),
          const SizedBox(height: AppSpacing.x2),
        ],
        if (detail.expectedReasoningAxes.isNotEmpty)
          _hintCard(
            l.promptChoiceReasoningHint(detail.expectedReasoningAxes.join(', ')),
            tone: PillTone.primary,
          ),
      ],
    );
  }
}

class _ChoiceOptionCard extends StatelessWidget {
  const _ChoiceOptionCard({
    required this.option,
    required this.detail,
    required this.client,
  });
  final ChoiceOptionView option;
  final ExerciseDetail detail;
  final ApiClient client;

  @override
  Widget build(BuildContext context) {
    final asset = option.imageAssetId.isEmpty
        ? null
        : detail.assetById(option.imageAssetId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (asset?.isImage == true) ...[
            ClipRRect(
              borderRadius: AppRadius.smAll,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  client.exerciseAssetUri(detail.id, option.imageAssetId).toString(),
                  headers: client.authHeaders,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surfaceContainerLow,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
          ],
          Text(option.label, style: AppTypography.titleSmall),
          if (option.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              option.description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
