import 'package:flutter/material.dart';

import '../../../core/locale/locale_scope.dart';
import '../../../core/locale/supported_locales.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
        _SectionLabel(l.profileAboutSection),
        const SizedBox(height: AppSpacing.x2),
        _AboutCard(l: l),
        const SizedBox(height: AppSpacing.x8),
      ],
    );
  }
}

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
