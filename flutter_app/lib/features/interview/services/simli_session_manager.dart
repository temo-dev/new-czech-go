import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:simli_client/simli_client.dart';
import 'package:simli_client/models/simli_client_config.dart';

/// Wraps `simli_client` lifecycle for use in InterviewSessionScreen.
///
/// Sprint 1: the session screen uses [InterviewSessionScreen] without Simli
/// (audio-only mode). Sprint 2: wire [sendAudio] into `ElevenLabsWsClient.onAudioChunk`
/// and render [videoRenderer] in an `RTCVideoView`.
///
/// [apiKey] and [faceId] come from build-time `--dart-define` constants:
///   SIMLI_API_KEY, SIMLI_FACE_ID
class SimliSessionManager {
  SimliSessionManager({
    required String apiKey,
    required String faceId,
    int maxSessionLength = 900,
    int maxIdleTime = 300,
  })  : _apiKey = apiKey,
        _faceId = faceId,
        _maxSessionLength = maxSessionLength,
        _maxIdleTime = maxIdleTime;

  final String _apiKey;
  final String _faceId;
  final int _maxSessionLength;
  final int _maxIdleTime;

  SimliClient? _client;
  bool _connected = false;

  /// Callbacks wired by the session screen.
  VoidCallback? onConnection;
  VoidCallback? onDisconnected;
  void Function(String error)? onFailed;

  // ── State ─────────────────────────────────────────────────────────────────

  bool get isConnected => _connected;

  /// The WebRTC video renderer to pass to `RTCVideoView`.
  /// Null before [start] completes successfully.
  dynamic get videoRenderer => _client?.videoRenderer;

  /// Notifies when the avatar is lip-syncing (speaking).
  ValueNotifier<bool>? get isSpeakingNotifier => _client?.isSpeakingNotifier;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialises the Simli WebRTC session and starts streaming.
  /// Safe to await — completes when the underlying WebSocket handshake starts.
  Future<void> start() async {
    final config = SimliClientConfig(
      apiKey: _apiKey,
      faceId: _faceId,
      handleSilence: true,
      maxSessionLength: _maxSessionLength,
      maxIdleTime: _maxIdleTime,
      syncAudio: true,
    );

    _client = SimliClient(
      clientConfig: config,
      log: Logger('SimliClient'),
    );

    _client!.onConnection = () {
      _connected = true;
      onConnection?.call();
    };
    _client!.onDisconnected = () {
      _connected = false;
      onDisconnected?.call();
    };
    _client!.onFailed = (err) {
      _connected = false;
      onFailed?.call(err.message);
    };

    await _client!.start();
  }

  /// Sends a PCM16 audio chunk to the Simli avatar for lip-sync animation.
  /// No-op if not connected.
  void sendAudio(Uint8List pcm16) {
    if (!_connected || _client == null) return;
    _client!.sendAudioData(pcm16);
  }

  Future<void> dispose() async {
    _connected = false;
    // SimliClient doesn't expose a close method; set to null and let GC clean up.
    _client = null;
  }
}

// SimliConfig constants moved to simli_config.dart (no native deps, safe for tests).
