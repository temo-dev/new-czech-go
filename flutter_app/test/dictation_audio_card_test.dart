import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:flutter_app/features/exercise/widgets/dictation_audio_card.dart';

void main() {
  group('dictationAudioShowsPause', () {
    test('returns false after playback reaches completed state', () {
      final state = PlayerState(true, ProcessingState.completed);

      expect(dictationAudioShowsPause(state), isFalse);
    });

    test('returns true only while actively playing non-completed audio', () {
      expect(
        dictationAudioShowsPause(PlayerState(true, ProcessingState.ready)),
        isTrue,
      );
      expect(
        dictationAudioShowsPause(PlayerState(false, ProcessingState.ready)),
        isFalse,
      );
    });
  });
}
