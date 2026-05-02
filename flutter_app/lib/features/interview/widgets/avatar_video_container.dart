import 'package:flutter/material.dart';

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
  });

  final dynamic videoRenderer; // RTCVideoRenderer? at runtime
  final bool isConnected;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 180, height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A5C),
        borderRadius: BorderRadius.circular(20),
        border: isSpeaking
            ? Border.all(color: const Color(0x50FF6A14), width: 2)
            : null,
      ),
      child: isConnected && videoRenderer != null
          ? _buildVideoView()
          : const _AvatarPlaceholder(),
    );
  }

  Widget _buildVideoView() {
    // RTCVideoView from flutter_webrtc — only reached on real device.
    // We use dynamic to avoid importing flutter_webrtc in the widget file,
    // which would break unit tests. The actual RTCVideoView call happens
    // in interview_session_screen.dart which is never loaded in tests.
    //
    // Sprint 2: replace this placeholder with the live video when wired.
    return const _AvatarPlaceholder();
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('👩‍💼', style: TextStyle(fontSize: 48)),
        SizedBox(height: 8),
        Text(
          'Jana Nováková',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Text(
          'Czech Examiner',
          style: TextStyle(color: Colors.white30, fontSize: 10),
        ),
      ],
    );
  }
}
