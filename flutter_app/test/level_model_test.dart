import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/models/models.dart';

void main() {
  group('CefrLevel parsing + ladder', () {
    test('parseLevel accepts the four canonical strings', () {
      expect(parseLevel('a0'), CefrLevel.a0);
      expect(parseLevel('a1'), CefrLevel.a1);
      expect(parseLevel('a2'), CefrLevel.a2);
      expect(parseLevel('b1'), CefrLevel.b1);
    });

    test('parseLevel falls back to a0 for unknown / empty', () {
      expect(parseLevel(''), CefrLevel.a0);
      expect(parseLevel('A2'), CefrLevel.a0); // case-sensitive
      expect(parseLevel('c1'), CefrLevel.a0);
      expect(parseLevel(null), CefrLevel.a0);
    });

    test('cefrLevelCode round-trips', () {
      for (final lvl in CefrLevel.values) {
        expect(parseLevel(cefrLevelCode(lvl)), lvl);
      }
    });

    test('nextCefrLevel walks the ladder a0→a1→a2→b1→null', () {
      expect(nextCefrLevel(CefrLevel.a0), CefrLevel.a1);
      expect(nextCefrLevel(CefrLevel.a1), CefrLevel.a2);
      expect(nextCefrLevel(CefrLevel.a2), CefrLevel.b1);
      expect(nextCefrLevel(CefrLevel.b1), isNull);
    });

    test('cefrLevelOrder is monotonic', () {
      expect(cefrLevelOrder(CefrLevel.a0), 0);
      expect(cefrLevelOrder(CefrLevel.a1), 1);
      expect(cefrLevelOrder(CefrLevel.a2), 2);
      expect(cefrLevelOrder(CefrLevel.b1), 3);
    });
  });

  group('LevelProgressResponse.fromJson', () {
    test('parses the full server payload incl. nested skill_mastery', () {
      final json = {
        'user_id': 'u_1',
        'current_level': 'a2',
        'unlocked_levels': ['a0', 'a1', 'a2'],
        'next_level': 'b1',
        'placement_taken_at': '2026-05-01T08:12:00Z',
        'skill_mastery': {
          'noi':      {'pct': 78.0, 'threshold_pct': 70.0, 'passes': true},
          'viet':     {'pct': 65.0, 'threshold_pct': 70.0, 'passes': false},
          'nghe':     {'pct': 80.0, 'threshold_pct': 70.0, 'passes': true},
          'doc':      {'pct': 74.0, 'threshold_pct': 70.0, 'passes': true},
          'tu_vung':  {'pct': 71.0, 'threshold_pct': 70.0, 'passes': true},
          'ngu_phap': {'pct': 70.0, 'threshold_pct': 70.0, 'passes': true},
        },
        'coverage_pct': 82.0,
        'coverage_threshold_pct': 80.0,
        'all_skills_pass': false,
        'promotion_unlocked': false,
        'promotion_test_id': 'mt_b1_promote_v1',
        'promotion_cooldown_until': null,
      };

      final progress = LevelProgressResponse.fromJson(json);
      expect(progress.userID, 'u_1');
      expect(progress.currentLevel, CefrLevel.a2);
      expect(progress.unlockedLevels,
          {CefrLevel.a0, CefrLevel.a1, CefrLevel.a2});
      expect(progress.nextLevel, CefrLevel.b1);
      expect(progress.placementTakenAt, isNotNull);
      expect(progress.coveragePct, closeTo(82.0, 1e-6));
      expect(progress.coverageThresholdPct, closeTo(80.0, 1e-6));
      expect(progress.allSkillsPass, isFalse);
      expect(progress.promotionUnlocked, isFalse);
      expect(progress.promotionTestID, 'mt_b1_promote_v1');
      expect(progress.promotionCooldownUntil, isNull);

      final viet = progress.skillMastery['viet'];
      expect(viet, isNotNull);
      expect(viet!.pct, closeTo(65.0, 1e-6));
      expect(viet.passes, isFalse);
    });

    test('tolerates missing optional fields with safe defaults', () {
      final progress = LevelProgressResponse.fromJson({});
      expect(progress.userID, '');
      expect(progress.currentLevel, CefrLevel.a0);
      expect(progress.unlockedLevels, isEmpty);
      expect(progress.nextLevel, CefrLevel.a1);
      expect(progress.skillMastery, isEmpty);
      expect(progress.allSkillsPass, isFalse);
      expect(progress.promotionUnlocked, isFalse);
    });
  });

  group('Course.fromJson with V21 level fields', () {
    test('parses unlocked state', () {
      final c = Course.fromJson({
        'id': 'c1', 'slug': 'a2', 'title': 'A2 Sprint',
        'description': '', 'status': 'published', 'sequence_no': 1,
        'level': 'a2', 'unlock_state': 'unlocked',
      });
      expect(c.level, CefrLevel.a2);
      expect(c.unlockState, CourseUnlockState.unlocked);
      expect(c.demoExerciseId, '');
    });

    test('parses demo state with demo_exercise_id', () {
      final c = Course.fromJson({
        'id': 'c2', 'slug': 'b1', 'title': 'B1 Občanství',
        'description': '', 'status': 'published', 'sequence_no': 2,
        'level': 'b1',
        'unlock_state': 'demo',
        'demo_exercise_id': 'ex_demo_b1',
      });
      expect(c.level, CefrLevel.b1);
      expect(c.unlockState, CourseUnlockState.demo);
      expect(c.demoExerciseId, 'ex_demo_b1');
    });

    test('parses locked state with no demo', () {
      final c = Course.fromJson({
        'id': 'c3', 'slug': 'b1-pro', 'title': 'B1 Pro',
        'description': '', 'status': 'published', 'sequence_no': 3,
        'level': 'b1',
        'unlock_state': 'locked',
      });
      expect(c.unlockState, CourseUnlockState.locked);
      expect(c.demoExerciseId, '');
    });

    test('legacy course missing level falls back without crashing', () {
      final c = Course.fromJson({
        'id': 'old', 'slug': '', 'title': 'Legacy',
        'description': '', 'status': 'published', 'sequence_no': 0,
      });
      expect(c.level, CefrLevel.a2); // matches backend migration default
      expect(c.unlockState, CourseUnlockState.unknown);
    });
  });
}
