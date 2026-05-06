import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/progress_api.dart';
import '../../../core/interview/interview_preference_service.dart';
import '../../../core/locale/locale_scope.dart';
import '../../../core/locale/supported_locales.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/voice/voice_option.dart';
import '../../../core/voice/voice_preference_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../progress/screens/progress_detail_screen.dart';
import '../widgets/v17_account_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.client,
    required this.voiceService,
    required this.interviewService,
  });

  final ApiClient client;
  final VoicePreferenceService voiceService;
  final InterviewPreferenceService interviewService;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final h = AppSpacing.pagePaddingH(context);

    final v17Section = V17AccountSection.maybe(context);
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: h, vertical: AppSpacing.x5),
      children: [
        if (v17Section != null) ...[
          v17Section,
        ] else ...[
          // Legacy build (no V17 auth wired): show generic placeholder.
          _LegacyAvatarPlaceholder(),
        ],
        const SizedBox(height: AppSpacing.x6),
        _ProgressEntryTile(client: client),
        const SizedBox(height: AppSpacing.x5),
        _SectionLabel(l.profileLanguageSection),
        const SizedBox(height: AppSpacing.x2),
        _LanguageTile(),
        const SizedBox(height: AppSpacing.x5),
        _VoicePickerSection(client: client, voiceService: voiceService),
        const SizedBox(height: AppSpacing.x5),
        _SectionLabel(l.profileInterviewSection),
        const SizedBox(height: AppSpacing.x2),
        _InterviewSettingsCard(interviewService: interviewService),
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
// Interview preferences
// ---------------------------------------------------------------------------

class _InterviewSettingsCard extends StatefulWidget {
  const _InterviewSettingsCard({required this.interviewService});

  final InterviewPreferenceService interviewService;

  @override
  State<_InterviewSettingsCard> createState() => _InterviewSettingsCardState();
}

class _InterviewSettingsCardState extends State<_InterviewSettingsCard> {
  late bool _avatarEnabled;
  late double _localAudioVolume;

  @override
  void initState() {
    super.initState();
    _avatarEnabled = widget.interviewService.avatarEnabled;
    _localAudioVolume = widget.interviewService.localAudioVolume;
  }

  Future<void> _setAvatarEnabled(bool enabled) async {
    await widget.interviewService.setAvatarEnabled(enabled);
    if (mounted) setState(() => _avatarEnabled = enabled);
  }

  Future<void> _setLocalAudioVolume(double volume) async {
    final normalized = InterviewPreferenceService.normalizeLocalAudioVolume(
      volume,
    );
    setState(() => _localAudioVolume = normalized);
    await widget.interviewService.setLocalAudioVolume(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            value: _avatarEnabled,
            onChanged: _setAvatarEnabled,
            activeColor: AppColors.primary,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x1,
            ),
            secondary: Icon(
              _avatarEnabled
                  ? Icons.face_retouching_natural_rounded
                  : Icons.graphic_eq_rounded,
              color:
                  _avatarEnabled
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
            ),
            title: Text(
              l.profileInterviewAvatarTitle,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            subtitle: Text(
              l.profileInterviewAvatarDescription,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
            indent: AppSpacing.x4,
            endIndent: AppSpacing.x4,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x3,
              AppSpacing.x4,
              AppSpacing.x3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.volume_up_rounded,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.profileInterviewVolumeTitle,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            l.profileInterviewVolumeValue(
                              (_localAudioVolume * 100).round(),
                            ),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        l.profileInterviewVolumeDescription,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      Slider(
                        value: _localAudioVolume,
                        min: InterviewPreferenceService.minLocalAudioVolume,
                        max: InterviewPreferenceService.maxLocalAudioVolume,
                        divisions: 4,
                        label: l.profileInterviewVolumeValue(
                          (_localAudioVolume * 100).round(),
                        ),
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.outlineVariant,
                        onChanged: _setLocalAudioVolume,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voice picker
// ---------------------------------------------------------------------------

class _VoicePickerSection extends StatefulWidget {
  const _VoicePickerSection({required this.client, required this.voiceService});

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
            content: Text(
              AppLocalizations.of(context).profileVoicePreviewError,
            ),
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
          const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
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
    final genderLabel =
        voice.gender == 'female' ? l.profileVoiceFemale : l.profileVoiceMale;
    final providerLabel =
        voice.provider == 'aws_polly'
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
        decoration:
            selected
                ? BoxDecoration(
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                )
                : null,
        child: Row(
          children: [
            // Voice icon by gender
            Icon(
              voice.gender == 'female'
                  ? Icons.record_voice_over_rounded
                  : Icons.mic_rounded,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3,
                  vertical: AppSpacing.x1,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child:
                  playing
                      ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        l.profileVoicePreview,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
            ),
            const SizedBox(width: AppSpacing.x1),
            // Selected check
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 20,
                color: AppColors.primary,
              )
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

/// Fallback header for legacy builds where V17 AuthService is not wired.
/// Production / V17 builds replace this with [V17AccountSection]'s hero.
class _LegacyAvatarPlaceholder extends StatelessWidget {
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
          child: const Icon(
            Icons.person,
            size: 40,
            color: AppColors.onPrimaryContainer,
          ),
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
              const Icon(
                Icons.check_rounded,
                size: 20,
                color: AppColors.primary,
              ),
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
                child: const Icon(
                  Icons.school_rounded,
                  size: 22,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.profileAppName,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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

// V20: profile entry that pushes the all-skills ProgressDetailScreen.
// Strings remain inline VI pending UI-6 ARB pass.
class _ProgressEntryTile extends StatelessWidget {
  const _ProgressEntryTile({required this.client});

  final ApiClient client;

  static const _labels = ProgressDetailLabels(
    titleAll: 'Tiến độ học tập',
    titleForSkill: _titleForSkill,
    moduleLabelFor: _moduleLabel,
    skillLabelFor: _skillLabel,
    attemptsCountLabel: _attemptsLabel,
    emptyTitle: 'Chưa có tiến độ',
    emptyMessage: 'Hoàn thành 1 bài để xem điểm mạnh/yếu của bạn.',
    emptyCtaLabel: 'Bắt đầu học',
    errorTitle: 'Không tải được tiến độ',
    errorMessage: 'Kiểm tra mạng và thử lại.',
    retryLabel: 'Thử lại',
    offlineLabel: 'Đang offline',
  );

  Future<void> _open(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    final api = ProgressApi(client: client, prefs: prefs);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProgressDetailScreen(
        fetcher: api.fetch,
        labels: _labels,
        skillKind: null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            children: const [
              Icon(Icons.bar_chart_rounded, size: 22),
              SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  'Tiến độ học tập',
                  style: AppTypography.titleSmall,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

String _titleForSkill(String kind) => 'Tiến độ ${_skillLabel(kind)}';
String _skillLabel(String kind) => switch (kind) {
      'noi' => 'Nói',
      'viet' => 'Viết',
      'nghe' => 'Nghe',
      'doc' => 'Đọc',
      'tu_vung' => 'Từ vựng',
      'ngu_phap' => 'Ngữ pháp',
      'interview' => 'Phỏng vấn',
      _ => kind,
    };
String _moduleLabel(String id) => id;
String _attemptsLabel(int n) => '$n lượt';
