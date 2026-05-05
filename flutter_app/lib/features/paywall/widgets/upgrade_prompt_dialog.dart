import 'package:flutter/material.dart';

import '../../../core/iap/iap_service.dart';
import '../../../core/theme/app_colors.dart';
import '../screens/paywall_screen.dart';

/// Modal that surfaces when the backend returns 429 on a quota-gated
/// endpoint (free tier hit attempts/day or interview/week cap). The
/// learner can dismiss to wait until tomorrow OR tap upgrade to open
/// the paywall.
class UpgradePromptDialog extends StatelessWidget {
  const UpgradePromptDialog({super.key, required this.iap, required this.title, required this.body});

  final IAPService iap;
  final String title;
  final String body;

  /// Convenience: fire on a 429 / quota-block surface. Returns the
  /// dialog future so callers can await dismissal.
  static Future<void> showForAttemptQuota(BuildContext context, IAPService iap) {
    return showDialog(
      context: context,
      builder: (ctx) => UpgradePromptDialog(
        iap: iap,
        title: 'Đã hết lượt luyện hôm nay',
        body:
            'Free tier giới hạn 7 lượt luyện mỗi ngày. Nâng cấp Pro để luyện không giới hạn + 1 grace pass mỗi tuần để giữ streak.',
      ),
    );
  }

  static Future<void> showForInterviewQuota(BuildContext context, IAPService iap) {
    return showDialog(
      context: context,
      builder: (ctx) => UpgradePromptDialog(
        iap: iap,
        title: 'Đã hết lượt phỏng vấn tuần này',
        body:
            'Free tier giới hạn 1 phỏng vấn mỗi tuần. Nâng cấp Pro để phỏng vấn không giới hạn.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Để mai'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PaywallScreen(iap: iap)),
            );
          },
          child: const Text('Nâng cấp Pro'),
        ),
      ],
    );
  }
}
