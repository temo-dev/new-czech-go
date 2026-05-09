import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/exercise/screens/listening_exercise_screen.dart';
import 'package:flutter_app/models/models.dart';

ExerciseDetail _detailFromItems({
  required String exerciseType,
  required List<Map<String, dynamic>> rawItems,
}) {
  return ExerciseDetail.fromJson({
    'id': 'ex-fixture',
    'title': 'Fixture',
    'exercise_type': exerciseType,
    'detail': {
      'items': rawItems,
      'correct_answers': const {'1': 'A'},
    },
  });
}

void main() {
  group('PoslechItemView audio_source.asset_id (V26)', () {
    test('hydrates audioAssetId from audio_source.asset_id', () {
      final item = PoslechItemView.fromJson({
        'question_no': 1,
        'question': 'Kde je nádraží?',
        'audio_source': {
          'asset_id': 'exercise-audio/abc/item-1.mp3',
          'segments': [
            {'text': 'Kde je nádraží?'},
          ],
        },
        'options': [
          {'key': 'A', 'text': 'Vlevo'},
          {'key': 'B', 'text': 'Vpravo'},
        ],
      });
      expect(item.questionNo, 1);
      expect(item.audioAssetId, 'exercise-audio/abc/item-1.mp3');
      expect(item.options, hasLength(2));
    });

    test('audioAssetId defaults to empty when audio_source is absent', () {
      final item = PoslechItemView.fromJson({
        'question_no': 2,
        'options': [],
      });
      expect(item.audioAssetId, isEmpty);
    });

    test('audioAssetId defaults to empty when asset_id is missing', () {
      final item = PoslechItemView.fromJson({
        'question_no': 3,
        'audio_source': {
          'segments': [
            {'text': 'Kolik je hodin?'},
          ],
        },
      });
      expect(item.audioAssetId, isEmpty);
    });
  });

  group('itemsHavePerItemAudio (V26)', () {
    test('returns true when every poslech_1 item has asset_id', () {
      final detail = _detailFromItems(
        exerciseType: 'poslech_1',
        rawItems: [
          {
            'question_no': 1,
            'audio_source': {'asset_id': 'exercise-audio/x/item-1.mp3'},
          },
          {
            'question_no': 2,
            'audio_source': {'asset_id': 'exercise-audio/x/item-2.mp3'},
          },
        ],
      );
      expect(itemsHavePerItemAudio(detail), isTrue);
    });

    test('returns false when one item lacks asset_id (legacy fallback)', () {
      final detail = _detailFromItems(
        exerciseType: 'poslech_1',
        rawItems: [
          {
            'question_no': 1,
            'audio_source': {'asset_id': 'exercise-audio/x/item-1.mp3'},
          },
          {
            'question_no': 2,
            'audio_source': {},
          },
        ],
      );
      expect(itemsHavePerItemAudio(detail), isFalse);
    });

    test('returns false for poslech_2 even when items have asset_id', () {
      // V26 scope = poslech_1 only; poslech_2 keeps single-audio path.
      final detail = _detailFromItems(
        exerciseType: 'poslech_2',
        rawItems: [
          {
            'question_no': 1,
            'audio_source': {'asset_id': 'exercise-audio/x/item-1.mp3'},
          },
        ],
      );
      expect(itemsHavePerItemAudio(detail), isFalse);
    });

    test('returns false for poslech_1 with no items', () {
      final detail = _detailFromItems(
        exerciseType: 'poslech_1',
        rawItems: const [],
      );
      expect(itemsHavePerItemAudio(detail), isFalse);
    });
  });
}
