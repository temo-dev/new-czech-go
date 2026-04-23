import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/notifications/providers/notification_prefs_provider.dart';
import 'package:app_czech/shared/widgets/app_top_bar.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationPrefsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: 'Nhắc nhở học tập'),
      body: async.when(
        loading: () => const ShimmerCardList(count: 3),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 16),
              Text('Không tải được cài đặt.', style: AppTypography.bodyMedium),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.refresh(notificationPrefsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (prefs) => _NotificationBody(prefs: prefs),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _NotificationBody extends ConsumerStatefulWidget {
  const _NotificationBody({required this.prefs});
  final NotificationPrefs prefs;

  @override
  ConsumerState<_NotificationBody> createState() => _NotificationBodyState();
}

class _NotificationBodyState extends ConsumerState<_NotificationBody> {
  late bool _enabled;
  late int _hour;
  late int _minute;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.prefs.enabled;
    _hour = widget.prefs.reminderHour;
    _minute = widget.prefs.reminderMinute;
  }

  String get _timeLabel {
    final h = _hour.toString().padLeft(2, '0');
    final m = _minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(notificationPrefsProvider.notifier).update(
            NotificationPrefs(
              enabled: _enabled,
              reminderHour: _hour,
              reminderMinute: _minute,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu cài đặt thông báo')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null && mounted) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main toggle
            _ToggleCard(
              enabled: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const SizedBox(height: 32),

            // Time picker
            _TimePickerSection(
              selectedTime: _timeLabel,
              onQuick: (h, m) => setState(() {
                _hour = h;
                _minute = m;
              }),
              onCustom: _pickCustomTime,
            ),
            const SizedBox(height: 32),

            // Habit card
            _HabitCard(),
            const SizedBox(height: 32),

            // Preview card
            _PreviewCard(time: _timeLabel),
            const SizedBox(height: 32),

            // Save button
            GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Lưu cài đặt',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toggle Card ───────────────────────────────────────────────────────────────

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({required this.enabled, required this.onChanged});
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhắc nhở học tập',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nhận thông báo luyện tập hàng ngày',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primaryFixed,
          ),
        ],
      ),
    );
  }
}

// ── Time Picker Section ───────────────────────────────────────────────────────

class _TimePickerSection extends StatelessWidget {
  const _TimePickerSection({
    required this.selectedTime,
    required this.onQuick,
    required this.onCustom,
  });
  final String selectedTime;
  final void Function(int h, int m) onQuick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Thời gian nhắc nhở',
              style: AppTypography.bodyMedium
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Large time display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.onBackground.withOpacity(0.04),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                selectedTime,
                style: AppTypography.headlineLarge.copyWith(
                  color: AppColors.primary,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'THỜI GIAN ĐÃ CHỌN',
                style: AppTypography.labelUppercase.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Quick time chips
        Row(
          children: [
            Expanded(
              child: _QuickTimeChip(
                label: '08:00',
                onTap: () => onQuick(8, 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickTimeChip(
                label: '12:30',
                onTap: () => onQuick(12, 30),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickTimeChip(
                label: 'Tùy chỉnh',
                isPrimary: true,
                onTap: onCustom,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickTimeChip extends StatelessWidget {
  const _QuickTimeChip({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: isPrimary
              ? Border.all(color: AppColors.primary.withOpacity(0.2))
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isPrimary ? AppColors.primary : AppColors.onBackground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Habit Card ────────────────────────────────────────────────────────────────

class _HabitCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: -48,
            right: -48,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                'Tại sao nên nhận thông báo?',
                style: AppTypography.headlineSmall.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Xây dựng thói quen hàng ngày là chìa khóa vàng giúp bạn ghi nhớ kiến thức lâu hơn và vượt qua kỳ thi Trvalý nhanh gấp 2 lần.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primaryFixed.withOpacity(0.9),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Preview Card ──────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.time});
  final String time;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'XEM TRƯỚC NỘI DUNG',
          style: AppTypography.labelUppercase.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border:
                Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Trvalý Exam',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Bây giờ',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.outline,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ahoj! Đã đến lúc dành 10 phút luyện tập cho kỳ thi Trvalý rồi.',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
