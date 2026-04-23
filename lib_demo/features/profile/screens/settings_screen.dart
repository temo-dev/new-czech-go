import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/storage/prefs_storage.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/providers/auth_provider.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/app_top_bar.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppTopBar(
        title: 'Cài đặt',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.profile),
      ),
      body: SingleChildScrollView(
        child: ResponsivePageContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Notifications ────────────────────────────────────────────
                _SectionHeader(label: 'Thông báo'),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  label: 'Nhắc nhở học hàng ngày',
                  onTap: () => context.push(AppRoutes.notifications),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                ),

                const SizedBox(height: AppSpacing.x4),

                // ── Language ─────────────────────────────────────────────────
                _SectionHeader(label: 'Ngôn ngữ ứng dụng'),
                _LanguageTile(),

                const SizedBox(height: AppSpacing.x4),

                // ── About ────────────────────────────────────────────────────
                _SectionHeader(label: 'Thông tin'),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  label: 'Phiên bản',
                  trailing: Text('1.0.0',
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant)),
                  onTap: null,
                ),

                const SizedBox(height: AppSpacing.x6),
                const Divider(),
                const SizedBox(height: AppSpacing.x4),

                // Logout
                AppButton(
                  label: 'Đăng xuất',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.logout_rounded,
                  onPressed: () async {
                    await ref.read(currentUserProvider.notifier).signOut();
                    if (context.mounted) context.go(AppRoutes.landing);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Language tile ─────────────────────────────────────────────────────────────

class _LanguageTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = PrefsStorage.instance.locale;

    return _SettingsTile(
      icon: Icons.language_rounded,
      label: 'Ngôn ngữ',
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentLocale,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
            DropdownMenuItem(value: 'cs', child: Text('Čeština')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (v) async {
            if (v == null) return;
            await PrefsStorage.instance.setLocale(v);
          },
        ),
      ),
      onTap: null,
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2, top: AppSpacing.x1),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x1),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon, color: cs.onSurface, size: 22),
        title: Text(label, style: AppTypography.bodyMedium),
        trailing: trailing,
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
