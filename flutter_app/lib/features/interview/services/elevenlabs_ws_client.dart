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

  /// Fired when ElevenLabs interrupts the agent mid-speech.
  VoidCallback? onInterruption;

  /// Fired when ElevenLabs reports that the current agent response is complete.
  VoidCallback? onAgentResponseComplete;

  /// Fired with metadata such as audio formats once a conversation starts.
  void Function({String? agentOutputAudioFormat, String? userInputAudioFormat})?
  onMetadata;

  /// Fired when ElevenLabs reports a Voice Activity Detection confidence
  /// score for the incoming user audio stream.
  void Function(double score)? onVadScore;

  // ── Test injection ────────────────────────────────────────────────────────

  /// If set, outbound messages write to this sink instead of the real WS.
  /// @visibleForTesting
  void Function(String msg)? testSendSink;

  /// System prompt to inject via conversation_initiation_client_data.
  /// Set before calling [connect]. Sent as first WS message after connection.
  String? systemPrompt;

  /// ElevenLabs voice ID override. When non-empty, sent as
  /// conversation_config_override.tts.voice_id so the agent uses this voice
  /// instead of the one configured in the ElevenLabs dashboard.
  String? voiceId;

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

  @visibleForTesting
  static const int pcm16InputSampleRate = 16000;

  @visibleForTesting
  static const int pcm16BytesPerSample = 2;

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
    _sendJson({'user_audio_chunk': base64Encode(pcm16)});
  }

  /// Sends a short PCM16 silence tail to let server-side VAD endpoint the
  /// learner turn after push-to-talk stops.
  void sendSilence({
    Duration duration = const Duration(milliseconds: 1200),
    Duration chunkDuration = const Duration(milliseconds: 100),
  }) {
    if (duration <= Duration.zero || chunkDuration <= Duration.zero) return;

    var remainingMicros = duration.inMicroseconds;
    final chunkMicros = chunkDuration.inMicroseconds;
    while (remainingMicros > 0) {
      final currentMicros =
          remainingMicros < chunkMicros ? remainingMicros : chunkMicros;
      final byteLength = pcm16SilenceByteLength(
        Duration(microseconds: currentMicros),
      );
      if (byteLength > 0) {
        sendAudioChunk(Uint8List(byteLength));
      }
      remainingMicros -= currentMicros;
    }
  }

  static int pcm16SilenceByteLength(Duration duration) {
    if (duration <= Duration.zero) return 0;
    final samples =
        (pcm16InputSampleRate *
                duration.inMicroseconds /
                Duration.microsecondsPerSecond)
            .round();
    return samples * pcm16BytesPerSample;
  }

  /// Closes the WebSocket connection.
  Future<void> disconnect({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    _disposed = true;
    final sub = _sub;
    _sub = null;
    final ws = _ws;
    _ws = null;
    try {
      await sub?.cancel().timeout(timeout);
    } catch (_) {
      // Cleanup is best-effort; callers should not get stuck ending a session.
    }
    try {
      await ws?.close().timeout(timeout);
    } catch (_) {
      // The remote service may not complete the close handshake promptly.
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _connectOnce(String url) async {
    try {
      _ws = await WebSocket.connect(url);
      // Set up listener FIRST — if we send initMessage before listening,
      // ElevenLabs may respond before we attach the listener and we miss events.
      _sub = _ws!.listen(
        _onData,
        onDone: _onDone,
        onError: _onNetworkError,
        cancelOnError: false,
      );
      _sendInitMessage();
    } catch (e) {
      _onNetworkError(e);
    }
  }

  /// Optional first message — if set, the agent speaks this immediately
  /// after session init (so learner doesn't have to speak first).
  String? firstMessage;

  @visibleForTesting
  Map<String, dynamic> buildConversationInitiationMessage() {
    final prompt = systemPrompt;
    final first = firstMessage;
    final agent = <String, dynamic>{};

    // Omit empty fields: ElevenLabs rejects override fields that are not
    // enabled in the agent security settings.
    if (prompt != null && prompt.trim().isNotEmpty) {
      agent['prompt'] = {'prompt': prompt.trim()};
    }
    if (first != null && first.trim().isNotEmpty) {
      agent['first_message'] = first.trim();
    }

    final configOverride = <String, dynamic>{};
    if (agent.isNotEmpty) {
      configOverride['agent'] = agent;
    }
    final vid = voiceId;
    if (vid != null && vid.trim().isNotEmpty) {
      configOverride['tts'] = {'voice_id': vid.trim()};
    }

    final message = <String, dynamic>{
      'type': 'conversation_initiation_client_data',
    };
    if (configOverride.isNotEmpty) {
      message['conversation_config_override'] = configOverride;
    }
    return message;
  }

  void _sendJson(Map<String, dynamic> msg) {
    if (_disposed) return;
    final encoded = jsonEncode(msg);
    if (testSendSink != null) {
      testSendSink!(encoded);
      return;
    }
    try {
      _ws?.add(encoded);
    } catch (err) {
      _onNetworkError(err);
    }
  }

  void _sendInitMessage() {
    _sendJson(buildConversationInitiationMessage());
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
        final event =
            msg['conversation_initiation_metadata_event']
                as Map<String, dynamic>?;
        onMetadata?.call(
          agentOutputAudioFormat:
              event?['agent_output_audio_format'] as String?,
          userInputAudioFormat: event?['user_input_audio_format'] as String?,
        );
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

      // Format v1: {"type":"transcript","transcript_event":{"role":"agent","message":"..."}}
      case 'transcript':
        final event = msg['transcript_event'] as Map<String, dynamic>?;
        final role = event?['role'] as String?;
        final text = (event?['message'] ?? event?['text']) as String? ?? '';
        if (role != null && text.isNotEmpty) {
          final speaker = role == 'agent' ? 'examiner' : 'learner';
          onTranscript?.call(speaker, text);
        }

      // Format v2: {"type":"agent_response","agent_response_event":{"agent_response":"..."}}
      case 'agent_response':
        final event = msg['agent_response_event'] as Map<String, dynamic>?;
        final text = event?['agent_response'] as String? ?? '';
        if (text.isNotEmpty) onTranscript?.call('examiner', text);

      // Format v2: {"type":"user_transcript","user_transcription_event":{"user_transcript":"..."}}
      case 'user_transcript':
        final event =
            (msg['user_transcription_event'] ?? msg['user_transcript_event'])
                as Map<String, dynamic>?;
        final text = event?['user_transcript'] as String? ?? '';
        if (text.isNotEmpty) onTranscript?.call('learner', text);

      case 'vad_score':
        final event = msg['vad_score_event'] as Map<String, dynamic>?;
        final score = (event?['vad_score'] as num?)?.toDouble();
        if (score != null) onVadScore?.call(score);

      case 'agent_response_complete':
        onAgentResponseComplete?.call();

      // Ping — must respond with pong or ElevenLabs closes the connection.
      case 'ping':
        final event = msg['ping_event'] as Map<String, dynamic>?;
        final eventId = event?['event_id'];
        if (eventId != null) {
          _sendJson({'type': 'pong', 'event_id': eventId});
        }

      case 'interruption':
        onInterruption?.call();
        break;

      default:
        // Unknown or future message type — silently ignore.
        break;
    }
  }
}
