import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ProSuccessScreen extends StatelessWidget {
  const ProSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(),
              // reduced-motion -> static checkmark; default -> subtle scale-in.
              if (reduced)
                const Icon(Icons.check_circle, size: 96, color: AppColors.success)
              else
                _AnimatedCheck(),
              const SizedBox(height: 24),
              const Text(
                'Chào mừng bạn đến Pro!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.secondary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Đã mở khoá luyện không giới hạn, mock test đầy đủ và grace pass hằng tuần. Cùng đậu A2 nào.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
              ),
              const Spacer(flex: 2),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Bắt đầu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedCheck extends StatefulWidget {
  @override
  State<_AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<_AnimatedCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      child: const Icon(Icons.check_circle, size: 96, color: AppColors.success),
    );
  }
}
