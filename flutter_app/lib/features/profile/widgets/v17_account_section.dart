import 'package:flutter/material.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/signup_screen.dart' show AuthServiceProvider;
import '../screens/change_password_screen.dart';
import '../screens/email_change_screen.dart';

/// V17 account block at the top of the Profile tab. Renders only when
/// the AuthService is available in the widget tree (i.e. the V17 build
/// flag is on); legacy builds do not see this block at all.
///
/// The block lists the learner's display name + email + Pro chip, then
/// surfaces the four account actions: change password, change email,
/// delete account, log out.
class V17AccountSection extends StatelessWidget {
  const V17AccountSection({super.key});

  /// Returns null when the AuthService is not in the tree so the
  /// caller can skip rendering for legacy builds.
  static Widget? maybe(BuildContext context) {
    final hasService = context.dependOnInheritedWidgetOfExactType<AuthServiceProvider>() != null;
    if (!hasService) return null;
    return const V17AccountSection();
  }

  @override
  Widget build(BuildContext context) {
    final service = AuthServiceProvider.of(context);
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final user = service.currentUser;
        if (user == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName.isEmpty ? user.email : user.displayName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.secondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: const TextStyle(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      _ProChip(isPro: user.isPro),
                    ],
                  ),
                  if (!user.emailVerified) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Email chưa được xác minh. Mở email để click link xác minh.',
                              style: TextStyle(fontSize: 13, color: AppColors.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.lock_outline,
              label: 'Đổi mật khẩu',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              ),
            ),
            _ActionTile(
              icon: Icons.alternate_email_outlined,
              label: 'Đổi email',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EmailChangeScreen()),
              ),
            ),
            _ActionTile(
              icon: Icons.logout,
              label: 'Đăng xuất',
              onTap: () => _confirmLogout(context, service),
            ),
            _ActionTile(
              icon: Icons.delete_outline,
              label: 'Xoá tài khoản',
              danger: true,
              onTap: () => _confirmDelete(context, service),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context, AuthService service) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn cần đăng nhập lại để tiếp tục học.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await service.logout();
    }
  }

  Future<void> _confirmDelete(BuildContext context, AuthService service) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá tài khoản?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hành động này không thể hoàn tác. Email của bạn sẽ được giải phóng để có thể đăng ký lại sau.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text('Nhập "XOÁ" để xác nhận:'),
            TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, controller.text.trim().toUpperCase() == 'XOÁ'),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await service.apiClientForScreens.deleteMeV17();
      } catch (_) {
        // Best-effort: even if the delete call fails, log out so the
        // user can re-attempt from a clean state.
      }
      await service.logout();
    }
  }
}

class _ProChip extends StatelessWidget {
  const _ProChip({required this.isPro});
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPro ? AppColors.primary : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isPro ? 'PRO' : 'Free',
        style: TextStyle(
          color: isPro ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.onSurface;
    return Material(
      color: AppColors.surfaceContainerLowest,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 15))),
              const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
