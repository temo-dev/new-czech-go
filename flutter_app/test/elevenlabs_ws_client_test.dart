import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/interview/services/elevenlabs_ws_client.dart';

void main() {
  group('ElevenLabsWsClient message dispatch', () {
    test(
      'builds initiation message with prompt and first message overrides',
      () {
        final client =
            ElevenLabsWsClient()
              ..systemPrompt = 'You are Jana, a Czech A2 examiner.'
              ..firstMessage = 'Dobrý den! Jak se jmenujete?';

        final message = client.buildConversationInitiationMessage();
        final override =
            message['conversation_config_override'] as Map<String, dynamic>;
        final agent = override['agent'] as Map<String, dynamic>;
        final prompt = agent['prompt'] as Map<String, dynamic>;

        expect(message['type'], equals('conversation_initiation_client_data'));
        expect(prompt['prompt'], equals('You are Jana, a Czech A2 examiner.'));
        expect(agent['first_message'], equals('Dobrý den! Jak se jmenujete?'));
      },
    );

    test('builds bare initiation message when there are no overrides', () {
      final client = ElevenLabsWsClient();

      expect(client.buildConversationInitiationMessage(), {
        'type': 'conversation_initiation_client_data',
      });
    });

    test('conversation_initiation_metadata fires onReady', () {
      final client = ElevenLabsWsClient();
      var readyCalled = false;
      client.onReady = () => readyCalled = true;

      client.handleRawMessage(
        jsonEncode({
          'type': 'conversation_initiation_metadata',
          'conversation_initiation_metadata_event': {
            'conversation_id': 'test-conv-id',
          },
        }),
      );

      expect(readyCalled, isTrue);
    });

    test('conversation metadata exposes audio formats', () {
      final client = ElevenLabsWsClient();
      String? agentFormat;
      String? userFormat;
      client.onMetadata = ({
        String? agentOutputAudioFormat,
        String? userInputAudioFormat,
      }) {
        agentFormat = agentOutputAudioFormat;
        userFormat = userInputAudioFormat;
      };

      client.handleRawMessage(
        jsonEncode({
          'type': 'conversation_initiation_metadata',
          'conversation_initiation_metadata_event': {
            'conversation_id': 'test-conv-id',
            'agent_output_audio_format': 'pcm_44100',
            'user_input_audio_format': 'pcm_16000',
          },
        }),
      );

      expect(agentFormat, equals('pcm_44100'));
      expect(userFormat, equals('pcm_16000'));
    });

    test('audio event fires onAudioChunk with decoded PCM16 bytes', () {
      final client = ElevenLabsWsClient();
      Uint8List? received;
      client.onAudioChunk = (bytes) => received = bytes;

      final fakeAudio = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      final encoded = base64Encode(fakeAudio);

      client.handleRawMessage(
        jsonEncode({
          'type': 'audio',
          'audio_event': {'audio_base_64': encoded},
        }),
      );

      expect(received, isNotNull);
      expect(received, equals(fakeAudio));
    });

    test(
      'transcript agent message fires onTranscript with examiner speaker',
      () {
        final client = ElevenLabsWsClient();
        String? spk;
        String? txt;
        client.onTranscript = (speaker, text) {
          spk = speaker;
          txt = text;
        };

        client.handleRawMessage(
          jsonEncode({
            'type': 'transcript',
            'transcript_event': {
              'message_type': 'transcript',
              'role': 'agent',
              'message': 'Jak se jmenujete?',
            },
          }),
        );

        expect(spk, equals('examiner'));
        expect(txt, equals('Jak se jmenujete?'));
      },
    );

    test('transcript user message fires onTranscript with learner speaker', () {
      final client = ElevenLabsWsClient();
      String? spk;
      client.onTranscript = (speaker, _) => spk = speaker;

      client.handleRawMessage(
        jsonEncode({
          'type': 'transcript',
          'transcript_event': {
            'message_type': 'transcript',
            'role': 'user',
            'message': 'Jmenuji se Anna.',
          },
        }),
      );

      expect(spk, equals('learner'));
    });

    test(
      'current user_transcription_event format fires learner transcript',
      () {
        final client = ElevenLabsWsClient();
        String? spk;
        String? txt;
        client.onTranscript = (speaker, text) {
          spk = speaker;
          txt = text;
        };

        client.handleRawMessage(
          jsonEncode({
            'type': 'user_transcript',
            'user_transcription_event': {'user_transcript': 'Jmenuji se Anna.'},
          }),
        );

        expect(spk, equals('learner'));
        expect(txt, equals('Jmenuji se Anna.'));
      },
    );

    test('agent_response_complete fires callback', () {
      final client = ElevenLabsWsClient();
      var called = false;
      client.onAgentResponseComplete = () => called = true;

      client.handleRawMessage(
        jsonEncode({
          'type': 'agent_response_complete',
          'agent_response_complete_event': {},
        }),
      );

      expect(called, isTrue);
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
        () => client.handleRawMessage(
          jsonEncode({'type': 'unknown_future_type'}),
        ),
        returnsNormally,
      );
    });

    test('malformed JSON does not crash', () {
      final client = ElevenLabsWsClient();
      expect(() => client.handleRawMessage('not-json{{{'), returnsNormally);
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

      client.handleRawMessage(
        jsonEncode({
          'type': 'transcript',
          'transcript_event': {'role': 'agent', 'message': 'Turn 1'},
        }),
      );
      client.handleRawMessage(
        jsonEncode({
          'type': 'transcript',
          'transcript_event': {'role': 'user', 'message': 'Turn 2'},
        }),
      );
      client.handleRawMessage(
        jsonEncode({
          'type': 'transcript',
          'transcript_event': {'role': 'agent', 'message': 'Turn 3'},
        }),
      );

      expect(turns.length, equals(3));
      expect(turns[0].$1, equals('examiner'));
      expect(turns[1].$1, equals('learner'));
      expect(turns[2].$1, equals('examiner'));
      expect(turns[0].$2, equals('Turn 1'));
    });
  });
}
