import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// ElevenLabs Conversational AI WebSocket client.
///
/// Handles the real-time conversation protocol:
///   - Send mic audio: PCM16 as base64 JSON chunks
///   - Receive agent audio, transcript events, session metadata
///
/// Design note: [handleRawMessage] is exposed @visibleForTesting so unit
/// tests can exercise dispatch logic without a live WebSocket connection.
class ElevenLabsWsClient {
  // ── Callbacks ────────────────────────────────────────────────────────────

  /// Fired when the session is initialised and ready to receive audio.
  VoidCallback? onReady;

  /// Fired with a decoded PCM16 [Uint8List] chunk when the agent speaks.
  void Function(Uint8List pcm16)? onAudioChunk;

  /// Fired for each completed transcript turn.
  /// [speaker] is "examiner" (agent) or "learner" (user).
  void Function(String speaker, String text)? onTranscript;

  /// Fired on clean WebSocket close.
  VoidCallback? onDisconnected;

  /// Fired on unrecoverable connection error after all retries.
  void Function(String error)? onError;

  // ── Test injection ────────────────────────────────────────────────────────

  /// If set, [sendAudioChunk] writes to this sink instead of the real WS.
  /// @visibleForTesting
  void Function(String msg)? testSendSink;

  /// System prompt to inject via conversation_initiation_client_data.
  /// Set before calling [connect]. Sent as first WS message after connection.
  String? systemPrompt;

  // ── State ─────────────────────────────────────────────────────────────────

  WebSocket? _ws;
  StreamSubscription<dynamic>? _sub;
  bool _disposed = false;
  int _retryCount = 0;
  String? _signedUrl;

  static const _maxRetries = 3;
  static const _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Opens a WebSocket connection to the ElevenLabs Conversational AI.
  /// [signedUrl] is a short-lived URL from POST /v1/interview-sessions/token.
  Future<void> connect(String signedUrl) async {
    _signedUrl = signedUrl;
    _retryCount = 0;
    _disposed = false;
    await _connectOnce(signedUrl);
  }

  /// Sends a PCM16 audio chunk from the microphone to the agent.
  void sendAudioChunk(Uint8List pcm16) {
    final msg = jsonEncode({'user_audio_chunk': base64Encode(pcm16)});
    if (testSendSink != null) {
      testSendSink!(msg);
      return;
    }
    _ws?.add(msg);
  }

  /// Closes the WebSocket connection.
  Future<void> disconnect() async {
    _disposed = true;
    await _sub?.cancel();
    await _ws?.close();
    _ws = null;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _connectOnce(String url) async {
    try {
      _ws = await WebSocket.connect(url);
      // Send system_prompt override as first message (before any audio).
      // ElevenLabs ConvAI processes this before conversation_initiation_metadata.
      _sendInitMessage();
      _sub = _ws!.listen(
        _onData,
        onDone: _onDone,
        onError: _onNetworkError,
        cancelOnError: false,
      );
    } catch (e) {
      _onNetworkError(e);
    }
  }

  void _sendInitMessage() {
    final prompt = systemPrompt;
    if (prompt == null || prompt.isEmpty) return;
    _ws?.add(jsonEncode({
      'type': 'conversation_initiation_client_data',
      'conversation_config_override': {
        'agent': {
          'prompt': {'prompt': prompt},
          'language': 'cs',
        },
      },
    }));
  }

  void _onData(dynamic raw) {
    if (raw is String) handleRawMessage(raw);
  }

  void _onDone() {
    if (_disposed) {
      onDisconnected?.call();
      return;
    }
    // Unexpected close — attempt reconnect.
    _scheduleReconnect();
  }

  void _onNetworkError(dynamic error) {
    if (_disposed) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_retryCount >= _maxRetries) {
      onError?.call('connection_failed');
      return;
    }
    final delay = _retryDelays[_retryCount];
    _retryCount++;
    Future.delayed(delay, () async {
      if (_disposed || _signedUrl == null) return;
      await _connectOnce(_signedUrl!);
    });
  }

  // ── Message dispatch ──────────────────────────────────────────────────────

  /// Processes a raw JSON WebSocket message and dispatches to callbacks.
  /// Exposed for unit testing — do not call directly in production.
  @visibleForTesting
  void handleRawMessage(String raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return; // malformed JSON — silently ignore
    }

    final type = msg['type'] as String?;
    switch (type) {
      case 'conversation_initiation_metadata':
        onReady?.call();

      case 'audio':
        final event = msg['audio_event'] as Map<String, dynamic>?;
        final b64 = event?['audio_base_64'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          try {
            final bytes = base64Decode(b64);
            onAudioChunk?.call(Uint8List.fromList(bytes));
          } catch (_) {
            // bad base64 — ignore
          }
        }

      case 'transcript':
        final event = msg['transcript_event'] as Map<String, dynamic>?;
        final role = event?['role'] as String?;
        final text = event?['message'] as String? ?? '';
        if (role != null && text.isNotEmpty) {
          final speaker = role == 'agent' ? 'examiner' : 'learner';
          onTranscript?.call(speaker, text);
        }

      case 'interruption':
        // Simli handles visual interruption; no action needed here.
        break;

      default:
        // Unknown or future message type — silently ignore.
        break;
    }
  }
}
