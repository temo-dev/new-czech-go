import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

const _simliApiOrigin = 'https://api.simli.ai';
const _simliWsOrigin = 'wss://api.simli.ai';

@visibleForTesting
Map<String, dynamic> buildSimliTokenPayload({
  required String faceId,
  int maxSessionLength = 900,
  int maxIdleTime = 300,
  String model = 'artalk',
  bool includeModel = true,
}) {
  final payload = <String, dynamic>{
    'faceId': faceId,
    'apiVersion': 'v2',
    'handleSilence': true,
    'maxSessionLength': maxSessionLength,
    'maxIdleTime': maxIdleTime,
    'startFrame': 0,
    'audioInputFormat': 'pcm16',
  };
  final trimmedModel = model.trim();
  if (includeModel && trimmedModel.isNotEmpty) {
    payload['model'] = trimmedModel;
  }
  return payload;
}

@visibleForTesting
List<Map<String, dynamic>> parseSimliIceServers(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw const FormatException('Simli ICE response is not a list');
  }

  final servers =
      decoded.whereType<Map>().map((raw) {
        final urls = raw['urls'];
        if (urls is! String && urls is! List) {
          throw const FormatException('Simli ICE server is missing urls');
        }

        final server = <String, dynamic>{'urls': urls};
        final username = raw['username'];
        final credential = raw['credential'];
        if (username is String && username.isNotEmpty) {
          server['username'] = username;
        }
        if (credential is String && credential.isNotEmpty) {
          server['credential'] = credential;
        }
        return server;
      }).toList();

  if (servers.isEmpty) {
    throw const FormatException('Simli ICE response is empty');
  }
  return servers;
}

@visibleForTesting
String parseSimliSessionToken(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('Simli token response is not an object');
  }
  final token = decoded['session_token'];
  if (token is! String || token.isEmpty) {
    throw const FormatException('Simli token response missing session_token');
  }
  return token;
}

@visibleForTesting
Uri buildSimliWebRtcUri(String sessionToken, {bool enableSfu = true}) {
  return Uri.parse('$_simliWsOrigin/compose/webrtc/p2p').replace(
    queryParameters: <String, String>{
      'session_token': sessionToken,
      'enableSFU': enableSfu.toString(),
    },
  );
}

@visibleForTesting
bool isSimliControlMessage(String message) {
  return switch (message.toUpperCase()) {
    'ACK' || 'START' || 'STOP' || 'SILENT' || 'SPEAK' || 'SPEAKING' => true,
    _ => message.startsWith('pong'),
  };
}

/// Lightweight Simli Compose client.
///
/// The published `simli_client` Flutter package still uses the deprecated
/// `/getIceServers`, `/startAudioToVideoSession`, and `/StartWebRTCSession`
/// endpoints. This class follows the current Compose API directly.
class SimliSessionManager {
  SimliSessionManager({
    required String apiKey,
    required String faceId,
    int maxSessionLength = 900,
    int maxIdleTime = 300,
    String model = 'artalk',
    Duration iceGatheringTimeout = const Duration(seconds: 10),
    Duration requestTimeout = const Duration(seconds: 30),
    Duration answerTimeout = const Duration(seconds: 30),
  }) : _apiKey = apiKey,
       _faceId = faceId,
       _maxSessionLength = maxSessionLength,
       _maxIdleTime = maxIdleTime,
       _model = model,
       _iceGatheringTimeout = iceGatheringTimeout,
       _requestTimeout = requestTimeout,
       _answerTimeout = answerTimeout;

  final String _apiKey;
  final String _faceId;
  final int _maxSessionLength;
  final int _maxIdleTime;
  final String _model;
  final Duration _iceGatheringTimeout;
  final Duration _requestTimeout;
  final Duration _answerTimeout;

  VoidCallback? onConnection;
  VoidCallback? onDisconnected;
  VoidCallback? onVideoReady;
  void Function(bool isSpeaking)? onSpeakingChanged;
  void Function(String error)? onFailed;

  final ValueNotifier<bool> _isSpeakingNotifier = ValueNotifier<bool>(false);

  RTCVideoRenderer? _videoRenderer;
  RTCPeerConnection? _peerConnection;
  WebSocket? _webSocket;
  StreamSubscription<dynamic>? _webSocketSubscription;
  Completer<void> _videoReadyCompleter = Completer<void>();
  int _candidateCount = 0;
  bool _connected = false;
  bool _videoReady = false;
  bool _disposed = false;

  bool get isConnected => _connected;
  bool get isVideoReady => _videoReady;
  RTCVideoRenderer? get videoRenderer => _videoRenderer;
  ValueNotifier<bool> get isSpeakingNotifier => _isSpeakingNotifier;

  Future<void> start() async {
    _disposed = false;
    _videoReady = false;
    _videoReadyCompleter = Completer<void>();
    debugPrint(
      'Simli start: faceId=$_faceId model=$_model iceTimeout=$_iceGatheringTimeout',
    );

    try {
      _videoRenderer = RTCVideoRenderer();
      await _videoRenderer!.initialize();
      if (_disposed) return;

      final iceServers = await _fetchIceServers();
      if (_disposed) return;

      final sessionToken = await _fetchSessionToken();
      if (_disposed) return;

      _peerConnection = await createPeerConnection(<String, dynamic>{
        'sdpSemantics': 'unified-plan',
        'iceServers': iceServers,
        'iceTransportPolicy': 'all',
      });
      debugPrint(
        'Simli peer connection created with ${iceServers.length} ICE server(s)',
      );

      _wirePeerConnection();
      await _addReceiveOnlyTransceivers();

      final offer = await _peerConnection!.createOffer(<String, dynamic>{
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(offer);
      await _waitForStableIceCandidates();

      final localDescription = await _peerConnection!.getLocalDescription();
      if (localDescription == null) {
        throw StateError('Simli local SDP is missing');
      }

      await _connectWebSocket(sessionToken, localDescription);
    } catch (err) {
      _fail('Simli start failed: $err');
      rethrow;
    }
  }

  Future<void> waitUntilVideoReady({
    Duration timeout = const Duration(seconds: 12),
  }) {
    if (_videoReady) return Future<void>.value();
    return _videoReadyCompleter.future.timeout(timeout);
  }

  Future<void> _addReceiveOnlyTransceivers() async {
    await _peerConnection!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
    await _peerConnection!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchIceServers() async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse('$_simliApiOrigin/compose/ice'))
          .timeout(_requestTimeout);
      request.headers.set('x-simli-api-key', _apiKey);

      final response = await request.close().timeout(_requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Simli ICE ${response.statusCode}: $body');
      }

      final servers = parseSimliIceServers(body);
      debugPrint('Simli ICE servers loaded: ${servers.length}');
      return servers;
    } catch (err) {
      debugPrint('Simli ICE fallback STUN: $err');
      return const <Map<String, dynamic>>[
        <String, dynamic>{'urls': 'stun:stun.l.google.com:19302'},
      ];
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _fetchSessionToken() async {
    try {
      return await _fetchSessionTokenOnce(includeModel: true);
    } on HttpException catch (err) {
      if (_model.trim().isEmpty) rethrow;
      debugPrint(
        'Simli token with model=$_model failed; retrying without model: $err',
      );
      return _fetchSessionTokenOnce(includeModel: false);
    }
  }

  Future<String> _fetchSessionTokenOnce({required bool includeModel}) async {
    final client = HttpClient();
    try {
      final request = await client
          .postUrl(Uri.parse('$_simliApiOrigin/compose/token'))
          .timeout(_requestTimeout);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      request.headers.set('x-simli-api-key', _apiKey);

      final payload = buildSimliTokenPayload(
        faceId: _faceId,
        maxSessionLength: _maxSessionLength,
        maxIdleTime: _maxIdleTime,
        model: _model,
        includeModel: includeModel,
      );
      final body = utf8.encode(jsonEncode(payload));
      request.contentLength = body.length;
      request.add(body);

      final response = await request.close().timeout(_requestTimeout);
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Simli token ${response.statusCode}: $responseBody',
        );
      }

      final sessionToken = parseSimliSessionToken(responseBody);
      debugPrint('Simli session token received');
      return sessionToken;
    } finally {
      client.close(force: true);
    }
  }

  void _wirePeerConnection() {
    final peerConnection = _peerConnection!;
    peerConnection.onIceGatheringState = (state) {
      debugPrint('Simli ICE gathering: $state candidates=$_candidateCount');
    };
    peerConnection.onIceConnectionState = (state) {
      debugPrint('Simli ICE connection: $state');
    };
    peerConnection.onSignalingState = (state) {
      debugPrint('Simli signaling: $state');
    };
    peerConnection.onConnectionState = (state) {
      debugPrint('Simli peer state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _fail('Peer connection $state');
      }
    };
    peerConnection.onIceCandidate = (candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _candidateCount += 1;
      }
    };
    peerConnection.onTrack = (event) {
      debugPrint(
        'Simli track: ${event.track.kind} streams=${event.streams.length}',
      );
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        final renderer = _videoRenderer;
        renderer?.onFirstFrameRendered = () {
          debugPrint('Simli first video frame rendered');
          _markVideoReady();
        };
        renderer?.srcObject = event.streams.first;
      }
    };
    peerConnection.onAddStream = (stream) {
      final renderer = _videoRenderer;
      renderer?.onFirstFrameRendered = () {
        debugPrint('Simli first video frame rendered');
        _markVideoReady();
      };
      renderer?.srcObject = stream;
    };
  }

  Future<void> _waitForStableIceCandidates() async {
    final startedAt = DateTime.now();
    var previousCount = -1;

    while (!_disposed) {
      if (_peerConnection?.iceGatheringState ==
          RTCIceGatheringState.RTCIceGatheringStateComplete) {
        debugPrint('Simli ICE gathering complete candidates=$_candidateCount');
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= const Duration(milliseconds: 750) &&
          previousCount == _candidateCount) {
        debugPrint(
          'Simli ICE stable after ${elapsed.inMilliseconds}ms candidates=$_candidateCount',
        );
        return;
      }

      if (elapsed >= _iceGatheringTimeout) {
        debugPrint(
          'Simli ICE proceeding after timeout candidates=$_candidateCount',
        );
        return;
      }
      previousCount = _candidateCount;
    }
  }

  Future<void> _connectWebSocket(
    String sessionToken,
    RTCSessionDescription localDescription,
  ) async {
    final uri = buildSimliWebRtcUri(sessionToken);
    debugPrint('Simli connecting websocket');
    _webSocket = await WebSocket.connect(
      uri.toString(),
    ).timeout(_requestTimeout);

    final answerCompleter = Completer<void>();
    _webSocketSubscription = _webSocket!.listen(
      (message) async {
        if (message is List<int>) return;

        final text = message.toString();
        debugPrint('Simli WS message: $text');
        if (text == 'START') {
          _markConnected();
          sendAudio(Uint8List(6000));
          return;
        }
        if (text == 'STOP') {
          unawaited(dispose());
          return;
        }
        if (text.toUpperCase() == 'SILENT') {
          _setSpeaking(false);
          return;
        }
        if (text.toUpperCase() == 'SPEAK' || text.toUpperCase() == 'SPEAKING') {
          _setSpeaking(true);
          return;
        }
        if (text.startsWith('pong') || text == 'ACK') return;

        try {
          final decoded = jsonDecode(text);
          if (decoded is Map && decoded['type'] == 'answer') {
            await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(decoded['sdp'].toString(), 'answer'),
            );
            if (!answerCompleter.isCompleted) {
              answerCompleter.complete();
            }
            debugPrint('Simli remote answer applied');
          }
        } catch (err) {
          debugPrint('Simli WS parse ignored: $err');
        }
      },
      onError: (Object err) {
        if (!answerCompleter.isCompleted) {
          answerCompleter.completeError(err);
        }
        _fail('WebSocket error: $err');
      },
      onDone: () {
        if (!_disposed) {
          _fail('WebSocket closed');
        }
      },
      cancelOnError: true,
    );

    _webSocket!.add(jsonEncode(localDescription.toMap()));
    await answerCompleter.future.timeout(
      _answerTimeout,
      onTimeout: () {
        throw TimeoutException('Simli answer timeout');
      },
    );
  }

  void sendAudio(Uint8List pcm16) {
    if (!_connected || _disposed || _webSocket == null) return;
    _webSocket!.add(pcm16);
  }

  void clearBuffer() {
    if (_disposed || _webSocket == null) return;
    _webSocket!.add('SKIP');
  }

  Future<void> dispose({bool notify = true}) async {
    final wasDisposed = _disposed;
    _disposed = true;
    _connected = false;
    _videoReady = false;
    if (!_videoReadyCompleter.isCompleted) {
      _videoReadyCompleter.complete();
    }

    try {
      _webSocket?.add('DONE');
    } catch (err) {
      debugPrint('Simli DONE ignored: $err');
    }
    await _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    try {
      await _webSocket?.close();
    } catch (err) {
      debugPrint('Simli websocket close ignored: $err');
    }
    _webSocket = null;

    final peerConnection = _peerConnection;
    _peerConnection = null;
    final renderer = _videoRenderer;
    _videoRenderer = null;
    try {
      renderer?.srcObject = null;
    } catch (err) {
      debugPrint('Simli renderer detach ignored: $err');
    }

    try {
      final transceivers = await peerConnection?.getTransceivers();
      for (final transceiver in transceivers ?? <RTCRtpTransceiver>[]) {
        transceiver.stop();
      }

      final senders = await peerConnection?.senders;
      for (final sender in senders ?? <RTCRtpSender>[]) {
        sender.track?.stop();
      }
      await peerConnection?.close();
    } catch (err) {
      debugPrint('Simli peer close ignored: $err');
    }

    try {
      await renderer?.dispose();
    } catch (err) {
      debugPrint('Simli renderer dispose ignored: $err');
    }
    _candidateCount = 0;
    _setSpeaking(false);

    if (notify && !wasDisposed) {
      onDisconnected?.call();
    }
  }

  void _markConnected() {
    if (_connected || _disposed) return;
    _connected = true;
    onConnection?.call();
  }

  void _markVideoReady() {
    if (_videoReady || _disposed) return;
    _markConnected();
    _videoReady = true;
    if (!_videoReadyCompleter.isCompleted) {
      _videoReadyCompleter.complete();
    }
    onVideoReady?.call();
  }

  void _setSpeaking(bool isSpeaking) {
    if (_isSpeakingNotifier.value == isSpeaking) return;
    _isSpeakingNotifier.value = isSpeaking;
    onSpeakingChanged?.call(isSpeaking);
  }

  void _fail(String error) {
    if (_disposed) return;
    debugPrint('Simli failed: $error');
    _connected = false;
    if (!_videoReadyCompleter.isCompleted) {
      _videoReadyCompleter.completeError(StateError(error));
    }
    onFailed?.call(error);
    unawaited(dispose(notify: false));
  }
}
