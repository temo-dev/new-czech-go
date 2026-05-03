import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/interview/services/simli_config.dart';
import 'package:flutter_app/features/interview/services/simli_session_manager.dart';

void main() {
  group('SimliSessionManager helpers', () {
    test('SimliConfig constants exist (compile check)', () {
      expect(SimliConfig.apiKey, isA<String>());
      expect(SimliConfig.faceId, isA<String>());
    });

    test('builds current Compose token payload', () {
      final payload = buildSimliTokenPayload(
        faceId: 'face-1',
        maxSessionLength: 120,
        maxIdleTime: 30,
      );

      expect(payload['faceId'], equals('face-1'));
      expect(payload['apiVersion'], equals('v2'));
      expect(payload['handleSilence'], isTrue);
      expect(payload['maxSessionLength'], equals(120));
      expect(payload['maxIdleTime'], equals(30));
      expect(payload['audioInputFormat'], equals('pcm16'));
      expect(payload['model'], equals('artalk'));
    });

    test('can omit optional Simli model for API fallback', () {
      final payload = buildSimliTokenPayload(
        faceId: 'face-1',
        includeModel: false,
      );

      expect(payload.containsKey('model'), isFalse);
    });

    test('parses temporary ICE servers', () {
      final servers = parseSimliIceServers(
        '[{"urls":"turn:ice.example","username":"u","credential":"c"}]',
      );

      expect(servers, hasLength(1));
      expect(servers.first['urls'], equals('turn:ice.example'));
      expect(servers.first['username'], equals('u'));
      expect(servers.first['credential'], equals('c'));
    });

    test('parses Compose session token', () {
      expect(
        parseSimliSessionToken('{"session_token":"session-123"}'),
        equals('session-123'),
      );
    });

    test('builds current Compose WebRTC URL', () {
      final uri = buildSimliWebRtcUri('session-123');

      expect(uri.scheme, equals('wss'));
      expect(uri.host, equals('api.simli.ai'));
      expect(uri.path, equals('/compose/webrtc/p2p'));
      expect(uri.queryParameters['session_token'], equals('session-123'));
      expect(uri.queryParameters['enableSFU'], equals('true'));
    });

    test('recognizes plain Simli websocket control events', () {
      expect(isSimliControlMessage('ACK'), isTrue);
      expect(isSimliControlMessage('SILENT'), isTrue);
      expect(isSimliControlMessage('SPEAK'), isTrue);
      expect(isSimliControlMessage('SPEAKING'), isTrue);
      expect(isSimliControlMessage('pong123'), isTrue);
      expect(isSimliControlMessage('{"type":"answer"}'), isFalse);
    });
  });

  // Manual checklist (Sprint 0 — validate on iPhone before merging):
  // [ ] SimliSessionManager(apiKey: k, faceId: f) creates without throw
  // [ ] start() connects to Simli WebRTC within 3s
  // [ ] sendAudio(pcm16Chunk) triggers lip-sync animation visible on screen
  // [ ] dispose() cleanly closes the connection
}
