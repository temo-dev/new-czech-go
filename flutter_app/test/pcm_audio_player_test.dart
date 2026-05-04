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

    test('applies PCM16 gain with clipping', () {
      final pcm = Uint8List(6);
      final input = ByteData.sublistView(pcm);
      input.setInt16(0, 1000, Endian.little);
      input.setInt16(2, 30000, Endian.little);
      input.setInt16(4, -30000, Endian.little);

      final boosted = PcmAudioPlayer.applyPcm16GainForTesting(pcm, 1.5);
      final output = ByteData.sublistView(boosted);

      expect(output.getInt16(0, Endian.little), 1500);
      expect(output.getInt16(2, Endian.little), 32767);
      expect(output.getInt16(4, Endian.little), -32768);
    });

    test('normalizes volume gain into playback-safe range', () {
      expect(PcmAudioPlayer.normalizeVolumeGain(-1), 0);
      expect(PcmAudioPlayer.normalizeVolumeGain(3), 2);
      expect(PcmAudioPlayer.normalizeVolumeGain(double.infinity), 1);
    });
  });
}
