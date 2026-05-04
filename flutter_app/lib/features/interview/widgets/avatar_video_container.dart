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
    this.fullBleed = false,
  });

  final dynamic videoRenderer; // RTCVideoRenderer? from Simli at runtime
  final bool isConnected;
  final bool isSpeaking;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
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
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
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
