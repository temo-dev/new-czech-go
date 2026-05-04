import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

enum InterviewSessionState { connecting, ready, speaking, listening, thinking }

class SessionStatusPill extends StatelessWidget {
  const SessionStatusPill({super.key, required this.state});

  final InterviewSessionState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (text, color, blink) = _stateProps(state, l);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: color, blink: blink),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static (String, Color, bool) _stateProps(
    InterviewSessionState state,
    AppLocalizations? l,
  ) {
    switch (state) {
      case InterviewSessionState.connecting:
        return (
          l?.interviewStatusConnecting ?? 'Đang kết nối với examiner...',
          const Color(0xFFF59E0B),
          true,
        );
      case InterviewSessionState.ready:
        return (l?.interviewStatusReady ?? 'Sẵn sàng', Colors.white54, false);
      case InterviewSessionState.speaking:
        return (
          l?.interviewStatusSpeaking ?? 'Examiner đang nói',
          const Color(0xFFFF6A14),
          false,
        );
      case InterviewSessionState.listening:
        return (
          l?.interviewStatusListening ?? 'Đang lắng nghe bạn...',
          const Color(0xFF22C55E),
          true,
        );
      case InterviewSessionState.thinking:
        return (
          l?.interviewStatusThinking ?? 'Đang chờ examiner...',
          const Color(0xFF38BDF8),
          true,
        );
    }
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.blink});
  final Color color;
  final bool blink;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.blink) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    if (widget.blink && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.blink) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder:
          (_, __) => Opacity(
            opacity: _anim.value,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
    );
  }
}
