import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_models.dart';
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
            // Hero block: avatar 96pt centered + name + edit + email + chips
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AvatarTile(user: user, service: service, size: 96),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName.isEmpty ? _emailLocalPart(user.email) : user.displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _EditNicknameButton(user: user, service: service),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ProChip(isPro: user.isPro),
                    _VerifiedChip(verified: user.emailVerified),
                  ],
                ),
              ],
            ),
            if (!user.emailVerified) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Email chưa xác minh. Mở email để click link xác minh.',
                        style: TextStyle(fontSize: 13, color: AppColors.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

class _AvatarTile extends StatefulWidget {
  const _AvatarTile({required this.user, required this.service, this.size = 56});
  final AuthUser user;
  final AuthService service;
  final double size;

  @override
  State<_AvatarTile> createState() => _AvatarTileState();
}

class _AvatarTileState extends State<_AvatarTile> {
  bool _busy = false;

  Future<void> _openSheet() async {
    if (_busy) return;
    final hasAvatar = widget.user.avatarAssetId != null && widget.user.avatarAssetId!.isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Xoá ảnh đại diện', style: TextStyle(color: AppColors.error)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Huỷ'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'remove') {
      await _remove();
    } else {
      await _pick(action == 'camera' ? ImageSource.camera : ImageSource.gallery);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.service.apiClientForScreens.uploadAvatarV17(File(picked.path));
      await widget.service.refresh();
    } catch (e) {
      if (mounted) _showError('Không tải lên được: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await widget.service.apiClientForScreens.deleteAvatarV17();
      await widget.service.refresh();
    } catch (e) {
      if (mounted) _showError('Không xoá được: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final assetId = widget.user.avatarAssetId;
    final hasAvatar = assetId != null && assetId.isNotEmpty;
    final avatarUrl = hasAvatar
        ? widget.service.apiClientForScreens.mediaUri(assetId)
        : null;
    final initials = _initialsFor(widget.user);
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : _openSheet,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // Background circle (visible only behind initials fallback;
              // covered by image when avatar is set).
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              if (avatarUrl == null)
                Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: widget.size * 0.36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else
                ClipOval(
                  child: Image.network(
                    avatarUrl.toString(),
                    headers: {
                      if (widget.service.apiClientForScreens.currentToken != null)
                        'Authorization': 'Bearer ${widget.service.apiClientForScreens.currentToken}',
                    },
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: widget.size * 0.36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: widget.size * 0.32,
                  height: widget.size * 0.32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(color: AppColors.surfaceContainerLowest, width: 2),
                  ),
                  child: Icon(Icons.camera_alt, size: widget.size * 0.18, color: AppColors.onPrimary),
                ),
              ),
              if (_busy)
                ClipOval(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: widget.size * 0.4,
                      height: widget.size * 0.4,
                      child: const CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _emailLocalPart(String email) {
  final at = email.indexOf('@');
  return at <= 0 ? email : email.substring(0, at);
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip({required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.primary : AppColors.onSurfaceVariant;
    final bg = verified
        ? AppColors.primary.withValues(alpha: 0.12)
        : AppColors.surfaceContainerHigh;
    final label = verified ? 'Đã xác minh' : 'Chưa xác minh';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.error_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

String _initialsFor(AuthUser u) {
  final source = u.displayName.trim().isNotEmpty ? u.displayName.trim() : u.email;
  if (source.isEmpty) return '?';
  final parts = source.split(RegExp(r'\s+|@'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return source.substring(0, source.length >= 2 ? 2 : 1).toUpperCase();
}

class _EditNicknameButton extends StatelessWidget {
  const _EditNicknameButton({required this.user, required this.service});
  final AuthUser user;
  final AuthService service;

  Future<void> _open(BuildContext context) async {
    final controller = TextEditingController(text: user.displayName);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi biệt danh'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Tên hiển thị',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (saved == null || saved == user.displayName) return;
    try {
      await service.apiClientForScreens.patchMeV17({'display_name': saved});
      await service.refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: const Icon(Icons.edit_outlined, color: AppColors.onSurfaceVariant),
        tooltip: 'Đổi biệt danh',
        onPressed: () => _open(context),
      ),
    );
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
