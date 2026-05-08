import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/config/legal_urls.dart';
import '../../../core/iap/iap_models.dart';
import '../../../core/iap/iap_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/screens/signup_screen.dart' show AuthServiceProvider;
import 'pro_success_screen.dart';

/// Indirection for the platform `url_launcher` so the paywall test can
/// assert the right URI is dispatched without spawning an external
/// browser inside the harness.
typedef PaywallUrlLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLaunchUrl(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Paywall — the only place V17 sells Pro from. Two-tier toggle
/// (monthly / yearly with savings badge), a feature comparison
/// table, the buy CTA, and Apple's mandatory restore-purchase
/// button.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.iap,
    this.authServiceOverride,
    this.urlLauncher,
  });

  final IAPService iap;

  /// Optional override for tests. Production reaches AuthService via
  /// the AppShell-level provider.
  final AuthService? authServiceOverride;

  /// Optional launcher seam for tests; production code reaches
  /// `package:url_launcher`. The signature matches [launchUrl] so the
  /// default reference can pass through untouched.
  final PaywallUrlLauncher? urlLauncher;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<IAPProduct>? _products;
  String _selectedId = IAPProducts.yearly;
  bool _busy = false;
  String? _error;

  AuthService get _authService =>
      widget.authServiceOverride ?? AuthServiceProvider.of(context);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final list = await widget.iap.loadProducts();
      if (!mounted) return;
      setState(() {
        _products = list;
        if (list.isNotEmpty && !list.any((p) => p.id == _selectedId)) {
          _selectedId = list.first.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không tải được giá. Vui lòng thử lại.');
    }
  }

  Future<void> _buy() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final purchase = await widget.iap.buy(_selectedId);
      // Hand the receipt to the backend for entitlement validation.
      await _authService.apiClientForScreens.verifyAppleReceiptV17(
        receipt: purchase.receipt,
        productId: purchase.productId,
      );
      // Refresh the user payload so the UI flips to Pro everywhere.
      await _authService.refresh();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProSuccessScreen()),
      );
    } on IAPException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Mua không thành công. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final purchases = await widget.iap.restorePurchases();
      if (purchases.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'Không tìm thấy giao dịch trước đó.');
        return;
      }
      // Submit the freshest receipt to the backend; it dedupes by
      // transaction id so multiple submits are safe.
      for (final p in purchases) {
        await _authService.apiClientForScreens.verifyAppleReceiptV17(
          receipt: p.receipt, productId: p.productId,
        );
      }
      await _authService.refresh();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProSuccessScreen()),
      );
    } on IAPException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Khôi phục không thành công.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Nâng cấp Pro'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 16),
              _ComparisonTable(),
              const SizedBox(height: 16),
              if (_products == null)
                const Center(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ))
              else
                _ProductPicker(
                  products: _products!,
                  selectedId: _selectedId,
                  onSelect: (id) => setState(() => _selectedId = id),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.onErrorContainer),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _SubscriptionDisclosure(),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _products == null || _busy ? null : _buy,
                child: _busy
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                      )
                    : const Text('Nâng cấp Pro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: _busy ? null : _restore,
                child: const Text('Khôi phục giao dịch trước'),
              ),
              _LegalLinksRow(launcher: widget.urlLauncher ?? _defaultLaunchUrl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subscription auto-renewal disclosure required by App Store
/// guideline 3.1.2(a). Renders unconditionally — including while
/// loadProducts() is in flight — so reviewers see it on every paywall
/// state.
class _SubscriptionDisclosure extends StatelessWidget {
  const _SubscriptionDisclosure();

  @override
  Widget build(BuildContext context) {
    const lines = <String>[
      'Tự động gia hạn cho đến khi bạn hủy ≥24h trước hết kỳ.',
      'Thanh toán qua Apple ID khi xác nhận mua.',
      'Quản lý/hủy: Cài đặt → Apple ID → Đăng ký.',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(Icons.circle, size: 4, color: AppColors.onSurfaceVariant),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.4,
                      ),
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

/// Terms + Privacy text-button row required by App Store metadata
/// review. [Wrap] lets the buttons line-break on narrow phones (e.g.
/// 320pt iPhone SE) so neither falls below the safe area.
class _LegalLinksRow extends StatelessWidget {
  const _LegalLinksRow({required this.launcher});

  final PaywallUrlLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final compact = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          key: const Key('paywall_terms_button'),
          style: compact,
          onPressed: () => launcher(Uri.parse(LegalUrls.eula)),
          child: const Text('Điều khoản'),
        ),
        const Text(
          '·',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        TextButton(
          key: const Key('paywall_privacy_button'),
          style: compact,
          onPressed: () => launcher(Uri.parse(LegalUrls.privacy)),
          child: const Text('Chính sách bảo mật'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.workspace_premium_outlined, size: 56, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          'Mở khoá toàn bộ tính năng',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Luyện không giới hạn, mock test đầy đủ, và 1 grace pass mỗi tuần để giữ streak.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
        ),
      ],
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Lượt luyện / ngày', '7', '∞'),
      ('Phỏng vấn / tuần', '1', '∞'),
      ('Mock test đầy đủ', '—', '✓'),
      ('Streak grace pass', '—', '1/tuần'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: SizedBox()),
                SizedBox(width: 60, child: Text('Free', textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600))),
                SizedBox(width: 60, child: Text('Pro', textAlign: TextAlign.center, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Text(row.$1)),
                  SizedBox(width: 60, child: Text(row.$2, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.onSurfaceVariant))),
                  SizedBox(width: 60, child: Text(row.$3, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.products,
    required this.selectedId,
    required this.onSelect,
  });

  final List<IAPProduct> products;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final p in products) ...[
          _ProductTile(
            product: p,
            selected: p.id == selectedId,
            onTap: () => onSelect(p.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.selected, required this.onTap});

  final IAPProduct product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryContainer : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.priceLabel,
                      style: const TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (product.isYearly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Tiết kiệm 17%',
                    style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
