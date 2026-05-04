import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Displays the Simli avatar RTCVideoView or a placeholder when not connected.
///
/// Sprint 2: pass [videoRenderer] from SimliSessionManager; it renders the
/// live WebRTC video stream when [isConnected] is true.
///
/// [videoRenderer] is `dynamic` to avoid importing flutter_webrtc in tests —
/// the type is `RTCVideoRenderer?` at runtime.
class AvatarVideoContainer extends StatelessWidget {
  const AvatarVideoContainer({
    super.key,
    required this.videoRenderer,
    required this.isConnected,
    required this.isSpeaking,
    this.useAvatar = true,
    this.fullBleed = false,
  });

  final dynamic videoRenderer; // RTCVideoRenderer? from Simli at runtime
  final bool isConnected;
  final bool isSpeaking;
  final bool useAvatar;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    if (!useAvatar) {
      return _SoundWaveBackdrop(isSpeaking: isSpeaking, fullBleed: fullBleed);
    }

    if (fullBleed) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2137), Color(0xFF06101D)],
          ),
        ),
        child:
            videoRenderer is RTCVideoRenderer
                ? _buildFullBleedVideoView(videoRenderer as RTCVideoRenderer)
                : _AvatarPlaceholder(expanded: true, isSpeaking: isSpeaking),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 180,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A5C),
        borderRadius: BorderRadius.circular(20),
        border:
            isSpeaking
                ? Border.all(color: const Color(0x50FF6A14), width: 2)
                : null,
      ),
      child:
          videoRenderer is RTCVideoRenderer
              ? _buildVideoView(videoRenderer as RTCVideoRenderer)
              : const _AvatarPlaceholder(),
    );
  }

  Widget _buildVideoView(
    RTCVideoRenderer renderer, {
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(20)),
    RTCVideoViewObjectFit objectFit =
        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  }) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RTCVideoView(
            renderer,
            mirror: false,
            objectFit: objectFit,
            placeholderBuilder:
                (_) => const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                ),
          ),
          if (!isConnected)
            const ColoredBox(
              color: Color(0x551A3A5C),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullBleedVideoView(RTCVideoRenderer renderer) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // V16: enlarge the avatar card so it fills the available space
        // between the top status pill and the bottom panel. The previous
        // 0.62 / 520 caps left a barren strip above the avatar.
        final maxByWidth = constraints.maxWidth * 0.96;
        final maxByHeight = constraints.maxHeight * 0.78;
        final maxExtent = math.min(maxByWidth, maxByHeight);
        final minExtent = math.min(
          math.min(constraints.maxWidth, constraints.maxHeight),
          280.0,
        );
        final extent = math.max(minExtent, math.min(maxExtent, 640.0));

        return Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Align(
            alignment: Alignment.topCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF06101D),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 44,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: SizedBox.square(
                dimension: extent,
                child: _buildVideoView(
                  renderer,
                  borderRadius: BorderRadius.circular(28),
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SoundWaveBackdrop extends StatefulWidget {
  const _SoundWaveBackdrop({required this.isSpeaking, required this.fullBleed});

  final bool isSpeaking;
  final bool fullBleed;

  @override
  State<_SoundWaveBackdrop> createState() => _SoundWaveBackdropState();
}

class _SoundWaveBackdropState extends State<_SoundWaveBackdrop>
    with TickerProviderStateMixin {
  static const _barHeights = <double>[42, 74, 118, 86, 148, 104, 62, 132, 92];

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _barHeights.length,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 520 + i * 35),
      ),
    );
    _animations = List.generate(
      _barHeights.length,
      (i) => Tween<double>(begin: 0.34, end: 1).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
      ),
    );
    if (widget.isSpeaking) _start();
  }

  void _start() {
    for (final controller in _controllers) {
      controller.repeat(reverse: true);
    }
  }

  void _stop() {
    for (final controller in _controllers) {
      controller.stop();
      controller.value = 0.34;
    }
  }

  @override
  void didUpdateWidget(_SoundWaveBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !oldWidget.isSpeaking) _start();
    if (!widget.isSpeaking && oldWidget.isSpeaking) _stop();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 760;
        final waveSize =
            widget.fullBleed
                ? isCompact
                    ? 168.0
                    : 220.0
                : 150.0;
        final barWidth =
            widget.fullBleed
                ? isCompact
                    ? 6.0
                    : 8.0
                : 5.0;
        final barGap =
            widget.fullBleed
                ? isCompact
                    ? 3.0
                    : 4.0
                : 2.5;
        final nameSize =
            widget.fullBleed
                ? isCompact
                    ? 20.0
                    : 24.0
                : 12.0;
        final roleSize =
            widget.fullBleed
                ? isCompact
                    ? 12.0
                    : 14.0
                : 10.0;

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: waveSize,
              height: waveSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x221A3A5C),
                border: Border.all(
                  color:
                      widget.isSpeaking
                          ? const Color(0x66FF6A14)
                          : const Color(0x22FFFFFF),
                  width: widget.isSpeaking ? 3 : 1,
                ),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(_barHeights.length, (i) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: barGap),
                        child: AnimatedBuilder(
                          animation: _animations[i],
                          builder: (context, _) {
                            return Container(
                              width: barWidth,
                              height: (_barHeights[i] *
                                      (waveSize / 244) *
                                      _animations[i].value)
                                  .clamp(16.0, waveSize * 0.62),
                              decoration: BoxDecoration(
                                color:
                                    widget.isSpeaking
                                        ? const Color(0xFFFF6A14)
                                        : Colors.white30,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(height: widget.fullBleed ? (isCompact ? 14 : 20) : 12),
            Text(
              'Jana Nováková',
              style: TextStyle(
                color: Colors.white.withAlpha(230),
                fontSize: nameSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Audio mode',
              style: TextStyle(color: Colors.white38, fontSize: roleSize),
            ),
          ],
        );

        if (!widget.fullBleed) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 180,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A5C),
              borderRadius: BorderRadius.circular(20),
              border:
                  widget.isSpeaking
                      ? Border.all(color: const Color(0x50FF6A14), width: 2)
                      : null,
            ),
            child: Center(child: content),
          );
        }

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D2137), Color(0xFF06101D)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: isCompact ? 64 : 88),
              child: Align(alignment: Alignment.topCenter, child: content),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({this.expanded = false, this.isSpeaking = false});

  final bool expanded;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    final avatarSize = expanded ? 112.0 : 48.0;
    final nameSize = expanded ? 24.0 : 12.0;
    final roleSize = expanded ? 14.0 : 10.0;

    if (expanded) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 172,
              height: 172,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x331A3A5C),
                border:
                    isSpeaking
                        ? Border.all(color: const Color(0x66FF6A14), width: 3)
                        : Border.all(color: const Color(0x22FFFFFF), width: 1),
              ),
              child: Text('👩‍💼', style: TextStyle(fontSize: avatarSize)),
            ),
            const SizedBox(height: 20),
            Text(
              'Jana Nováková',
              style: TextStyle(
                color: Colors.white.withAlpha(230),
                fontSize: nameSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Czech Examiner',
              style: TextStyle(color: Colors.white38, fontSize: roleSize),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('👩‍💼', style: TextStyle(fontSize: avatarSize)),
          const SizedBox(height: 8),
          Text(
            'Jana Nováková',
            style: TextStyle(
              color: Colors.white.withAlpha(138),
              fontSize: nameSize,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Czech Examiner',
            style: TextStyle(color: Colors.white38, fontSize: roleSize),
          ),
        ],
      ),
    );
  }
}
