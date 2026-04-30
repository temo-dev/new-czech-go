import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/locale/locale_scope.dart';
import '../../../core/locale/supported_locales.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/voice/voice_option.dart';
import '../../../core/voice/voice_preference_service.dart';
import '../../../l10n/generated/app_localizations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.client,
    required this.voiceService,
  });

  final ApiClient client;
  final VoicePreferenceService voiceService;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = AppSpacing.pagePaddingH(context);

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: h, vertical: AppSpacing.x5),
      children: [
        _Avatar(),
        const SizedBox(height: AppSpacing.x6),
        _SectionLabel(l.profileLanguageSection),
        const SizedBox(height: AppSpacing.x2),
        _LanguageTile(),
        const SizedBox(height: AppSpacing.x5),
        _VoicePickerSection(client: client, voiceService: voiceService),
        const SizedBox(height: AppSpacing.x5),
        _SectionLabel(l.profileAboutSection),
        const SizedBox(height: AppSpacing.x2),
        _AboutCard(l: l),
        const SizedBox(height: AppSpacing.x8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Voice picker
// ---------------------------------------------------------------------------

class _VoicePickerSection extends StatefulWidget {
  const _VoicePickerSection({
    required this.client,
    required this.voiceService,
  });

  final ApiClient client;
  final VoicePreferenceService voiceService;

  @override
  State<_VoicePickerSection> createState() => _VoicePickerSectionState();
}

class _VoicePickerSectionState extends State<_VoicePickerSection> {
  List<VoiceOption>? _voices;
  String _selectedId = '';
  String? _playingId;
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _selectedId = widget.voiceService.current;
    _loadVoices();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await widget.client.getVoices();
      if (mounted) setState(() => _voices = voices);
    } catch (_) {
      if (mounted) setState(() => _voices = []);
    }
  }

  Future<void> _select(String voiceId) async {
    await widget.voiceService.save(voiceId);
    if (mounted) setState(() => _selectedId = voiceId);
  }

  Future<void> _preview(String voiceId) async {
    setState(() => _playingId = voiceId);
    try {
      final url = await widget.client.getVoicePreviewUrl(voiceId);
      if (url == null || !mounted) return;
      await _player.setUrl(url);
      await _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).profileVoicePreviewError),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _playingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final voices = _voices;

    // Loading
    if (voices == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(l.profileVoiceSection),
          const SizedBox(height: AppSpacing.x2),
          const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      );
    }
    // Empty / error — hide section
    if (voices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(l.profileVoiceSection),
        const SizedBox(height: AppSpacing.x2),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: [
              for (int i = 0; i < voices.length; i++) ...[
                _VoiceCard(
                  voice: voices[i],
                  selected: voices[i].id == _selectedId,
                  playing: voices[i].id == _playingId,
                  onTap: () => _select(voices[i].id),
                  onPreview: () => _preview(voices[i].id),
                ),
                if (i < voices.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.outlineVariant.withValues(alpha: 0.5),
                    indent: AppSpacing.x4,
                    endIndent: AppSpacing.x4,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.voice,
    required this.selected,
    required this.playing,
    required this.onTap,
    required this.onPreview,
  });

  final VoiceOption voice;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final genderLabel = voice.gender == 'female' ? l.profileVoiceFemale : l.profileVoiceMale;
    final providerLabel = voice.provider == 'aws_polly'
        ? l.profileVoiceProviderPolly
        : l.profileVoiceProviderElevenLabs;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        decoration: selected
            ? BoxDecoration(
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.primary, width: 1.5),
              )
            : null,
        child: Row(
          children: [
            // Voice icon by gender
            Icon(
              voice.gender == 'female' ? Icons.record_voice_over_rounded : Icons.mic_rounded,
              size: 20,
              color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.x3),
            // Name + metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice.name,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.primary : AppColors.onSurface,
                    ),
                  ),
                  Text(
                    '$genderLabel · $providerLabel',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Preview button
            TextButton(
              onPressed: playing ? null : onPreview,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x1),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: playing
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      l.profileVoicePreview,
                      style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                    ),
            ),
            const SizedBox(width: AppSpacing.x1),
            // Selected check
            if (selected)
              const Icon(Icons.check_rounded, size: 20, color: AppColors.primary)
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar + supporting widgets
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, size: 40, color: AppColors.onPrimaryContainer),
        ),
        const SizedBox(height: AppSpacing.x3),
        Text(
          'Học viên',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          'learner@example.com',
          style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.labelUppercase.copyWith(
        color: AppColors.primary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = LocaleScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          for (final code in AppLocale.all) ...[
            _LangOption(
              code: code,
              label: AppLocale.label(code),
              selected: provider.code == code,
              onTap: () => provider.setLocale(code),
            ),
            if (code != AppLocale.all.last)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
                indent: AppSpacing.x4,
                endIndent: AppSpacing.x4,
              ),
          ],
        ],
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.code,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.primary : AppColors.onSurface,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_rounded, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, size: 22, color: AppColors.onPrimary),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.profileAppName,
                      style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      l.profileVersion('1.0.0'),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            l.profileAppTagline,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
