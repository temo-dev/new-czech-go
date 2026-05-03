import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/interview/services/pcm_audio_player.dart';

void main() {
  group('PcmAudioPlayer audio helpers', () {
    test('parses ElevenLabs PCM output format sample rates', () {
      expect(
        PcmAudioPlayer.sampleRateFromElevenLabsFormat('pcm_16000'),
        equals(16000),
      );
      expect(
        PcmAudioPlayer.sampleRateFromElevenLabsFormat('pcm_44100'),
        equals(44100),
      );
      expect(
        PcmAudioPlayer.sampleRateFromElevenLabsFormat(' PCM_24000 '),
        equals(24000),
      );
    });

    test('ignores unsupported or malformed output formats', () {
      expect(PcmAudioPlayer.sampleRateFromElevenLabsFormat(null), isNull);
      expect(
        PcmAudioPlayer.sampleRateFromElevenLabsFormat('mp3_44100'),
        isNull,
      );
      expect(PcmAudioPlayer.sampleRateFromElevenLabsFormat('pcm_fast'), isNull);
    });

    test('writes selected sample rate into WAV header', () {
      final wav = PcmAudioPlayer.wavBytesForTesting(
        Uint8List.fromList([1, 2, 3, 4]),
        sampleRate: 44100,
      );
      final header = ByteData.sublistView(wav);

      expect(wav.length, equals(48));
      expect(header.getUint32(24, Endian.little), equals(44100));
      expect(header.getUint32(28, Endian.little), equals(88200));
      expect(header.getUint32(40, Endian.little), equals(4));
    });
  });
}
