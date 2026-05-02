import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/interview/services/elevenlabs_ws_client.dart';

void main() {
  group('ElevenLabsWsClient message dispatch', () {
    test('conversation_initiation_metadata fires onReady', () {
      final client = ElevenLabsWsClient();
      var readyCalled = false;
      client.onReady = () => readyCalled = true;

      client.handleRawMessage(jsonEncode({
        'type': 'conversation_initiation_metadata',
        'conversation_initiation_metadata_event': {
          'conversation_id': 'test-conv-id',
        },
      }));

      expect(readyCalled, isTrue);
    });

    test('audio event fires onAudioChunk with decoded PCM16 bytes', () {
      final client = ElevenLabsWsClient();
      Uint8List? received;
      client.onAudioChunk = (bytes) => received = bytes;

      final fakeAudio = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      final encoded = base64Encode(fakeAudio);

      client.handleRawMessage(jsonEncode({
        'type': 'audio',
        'audio_event': {'audio_base_64': encoded},
      }));

      expect(received, isNotNull);
      expect(received, equals(fakeAudio));
    });

    test('transcript agent message fires onTranscript with examiner speaker', () {
      final client = ElevenLabsWsClient();
      String? spk;
      String? txt;
      client.onTranscript = (speaker, text) {
        spk = speaker;
        txt = text;
      };

      client.handleRawMessage(jsonEncode({
        'type': 'transcript',
        'transcript_event': {
          'message_type': 'transcript',
          'role': 'agent',
          'message': 'Jak se jmenujete?',
        },
      }));

      expect(spk, equals('examiner'));
      expect(txt, equals('Jak se jmenujete?'));
    });

    test('transcript user message fires onTranscript with learner speaker', () {
      final client = ElevenLabsWsClient();
      String? spk;
      client.onTranscript = (speaker, _) => spk = speaker;

      client.handleRawMessage(jsonEncode({
        'type': 'transcript',
        'transcript_event': {
          'message_type': 'transcript',
          'role': 'user',
          'message': 'Jmenuji se Anna.',
        },
      }));

      expect(spk, equals('learner'));
    });

    test('interruption message does not crash', () {
      final client = ElevenLabsWsClient();
      // Should silently ignore — no callbacks needed
      expect(
        () => client.handleRawMessage(
          jsonEncode({'type': 'interruption', 'interruption_event': {}}),
        ),
        returnsNormally,
      );
    });

    test('unknown message type does not crash', () {
      final client = ElevenLabsWsClient();
      expect(
        () => client.handleRawMessage(jsonEncode({'type': 'unknown_future_type'})),
        returnsNormally,
      );
    });

    test('malformed JSON does not crash', () {
      final client = ElevenLabsWsClient();
      expect(
        () => client.handleRawMessage('not-json{{{'),
        returnsNormally,
      );
    });

    test('sendAudioChunk encodes PCM16 as base64 user_audio_chunk', () {
      final client = ElevenLabsWsClient();
      final List<String> sent = [];
      client.testSendSink = (msg) => sent.add(msg);

      final audio = Uint8List.fromList([10, 20, 30]);
      client.sendAudioChunk(audio);

      expect(sent.length, equals(1));
      final decoded = jsonDecode(sent.first) as Map<String, dynamic>;
      expect(decoded['user_audio_chunk'], equals(base64Encode(audio)));
    });

    test('transcript accumulation preserves order', () {
      final client = ElevenLabsWsClient();
      final turns = <(String, String)>[];
      client.onTranscript = (spk, txt) => turns.add((spk, txt));

      client.handleRawMessage(jsonEncode({
        'type': 'transcript',
        'transcript_event': {'role': 'agent', 'message': 'Turn 1'},
      }));
      client.handleRawMessage(jsonEncode({
        'type': 'transcript',
        'transcript_event': {'role': 'user', 'message': 'Turn 2'},
      }));
      client.handleRawMessage(jsonEncode({
        'type': 'transcript',
        'transcript_event': {'role': 'agent', 'message': 'Turn 3'},
      }));

      expect(turns.length, equals(3));
      expect(turns[0].$1, equals('examiner'));
      expect(turns[1].$1, equals('learner'));
      expect(turns[2].$1, equals('examiner'));
      expect(turns[0].$2, equals('Turn 1'));
    });
  });
}
