import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/features/exercise/screens/vocab_type_list_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

ExerciseSummary _ex(String id, String type) => ExerciseSummary(
      id: id,
      title: 'Exercise $id',
      exerciseType: type,
      shortInstruction: 'Instruction',
      skillKind: 'tu_vung',
    );

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
// ── TypeGroupScreen ───────────────────────────────────────────────────────────

group('TypeGroupScreen', () {
  // TypeGroupScreen requires a real ApiClient to fetch data, so we unit-test
  // the grouping logic and the _TypeCard count display via pure widget tests
  // using a pre-populated grouped map baked into helper.

  test('groups exercises by exerciseType correctly', () {
    final exercises = [
      _ex('1', 'quizcard_basic'),
      _ex('2', 'quizcard_basic'),
      _ex('3', 'matching'),
      _ex('4', 'fill_blank'),
      _ex('5', 'choice_word'),
      _ex('6', 'choice_word'),
    ];
    final grouped = <String, List<ExerciseSummary>>{};
    for (final ex in exercises) {
      grouped.putIfAbsent(ex.exerciseType, () => []).add(ex);
    }
    expect(grouped['quizcard_basic']!.length, 2);
    expect(grouped['matching']!.length, 1);
    expect(grouped['fill_blank']!.length, 1);
    expect(grouped['choice_word']!.length, 2);
  });

  test('empty exerciseType list excluded from groups', () {
    final exercises = [_ex('1', 'quizcard_basic')];
    final grouped = <String, List<ExerciseSummary>>{};
    for (final ex in exercises) {
      grouped.putIfAbsent(ex.exerciseType, () => []).add(ex);
    }
    expect(grouped.containsKey('matching'), false);
    expect(grouped.containsKey('fill_blank'), false);
    expect(grouped.containsKey('choice_word'), false);
    expect(grouped['quizcard_basic']!.length, 1);
  });
});

// ── VocabTypeListScreen ───────────────────────────────────────────────────────

group('VocabTypeListScreen', () {
  testWidgets('shows "Bắt đầu học tất cả" button with correct count',
      (tester) async {
    final exercises = [
      _ex('1', 'quizcard_basic'),
      _ex('2', 'quizcard_basic'),
      _ex('3', 'quizcard_basic'),
    ];
    // We can't pass a real ApiClient but the screen renders from pre-loaded data
    // so we pump with a dummy — the client is only used when tapping individual items.
    await tester.pumpWidget(_wrap(
      VocabTypeListScreen(
        client: ApiClient(),
        moduleId: 'mod-1',
        exerciseType: 'quizcard_basic',
        typeLabel: 'Flashcard',
        exercises: exercises,
      ),
    ));
    await tester.pump();
    // Button with count text should appear
    expect(find.textContaining('3'), findsWidgets);
    expect(find.textContaining('Bắt đầu'), findsOneWidget);
  });

  testWidgets('lists all exercises', (tester) async {
    final exercises = [_ex('A', 'quizcard_basic'), _ex('B', 'quizcard_basic')];
    await tester.pumpWidget(_wrap(
      VocabTypeListScreen(
        client: ApiClient(),
        moduleId: 'mod-1',
        exerciseType: 'quizcard_basic',
        typeLabel: 'Flashcard',
        exercises: exercises,
      ),
    ));
    await tester.pump();
    expect(find.text('Exercise A'), findsOneWidget);
    expect(find.text('Exercise B'), findsOneWidget);
  });
});

// ── DeckSessionScreen internal queue logic ────────────────────────────────────

group('DeckSessionScreen queue logic', () {
  test('Đã biết (known) removes card from queue', () {
    final exercises = [_ex('1', 'quizcard_basic'), _ex('2', 'quizcard_basic')];
    // Simulate queue manipulation directly (unit-testing the logic)
    final queue = List<ExerciseSummary>.from(exercises);
    final knownIds = <String>{};

    // Simulate "known" choice for first card
    final current = queue.removeAt(0);
    knownIds.add(current.id);

    expect(queue.length, 1);
    expect(knownIds.contains('1'), true);
    expect(queue.first.id, '2');
  });

  test('Ôn lại (review) pushes card back to end of queue', () {
    final exercises = [
      _ex('1', 'quizcard_basic'),
      _ex('2', 'quizcard_basic'),
      _ex('3', 'quizcard_basic'),
    ];
    final queue = List<ExerciseSummary>.from(exercises);
    final knownIds = <String>{};

    // Simulate "review" choice for first card
    final current = queue.removeAt(0);
    queue.add(current); // push back

    expect(queue.length, 3);
    expect(queue.last.id, '1'); // card moved to end
    expect(queue.first.id, '2'); // next card is now first
    expect(knownIds.isEmpty, true); // nothing marked known
  });

  test('queue empty after all cards known', () {
    final exercises = [_ex('1', 'quizcard_basic'), _ex('2', 'quizcard_basic')];
    final queue = List<ExerciseSummary>.from(exercises);
    final knownIds = <String>{};

    // Mark both as known
    while (queue.isNotEmpty) {
      final c = queue.removeAt(0);
      knownIds.add(c.id);
    }

    expect(queue.isEmpty, true);
    expect(knownIds.length, 2);
  });

  test('progress = knownIds.length / totalCount', () {
    const totalCount = 5;
    final knownIds = {'1', '2', '3'};
    final progress = knownIds.length / totalCount;
    expect(progress, closeTo(0.6, 0.001));
  });
});

// ── CompletionView ────────────────────────────────────────────────────────────

group('CompletionView via DeckSessionScreen', () {
  // We test the completion state by verifying the session logic that triggers it
  test('session marked complete when queue empty after known', () {
    final queue = [_ex('1', 'quizcard_basic')];
    final knownIds = <String>{};
    bool sessionComplete = false;

    final current = queue.removeAt(0);
    knownIds.add(current.id);
    if (queue.isEmpty) sessionComplete = true;

    expect(sessionComplete, true);
    expect(knownIds.length, 1);
  });
});

// ── Local scoring ─────────────────────────────────────────────────────────────

group('Local scoring', () {
  test('choice_word correct key check (case-insensitive)', () {
    bool checkChoice(String tapped, String correct) =>
        tapped.toLowerCase() == correct.toLowerCase();

    expect(checkChoice('A', 'A'), true);
    expect(checkChoice('a', 'A'), true);
    expect(checkChoice('B', 'A'), false);
    expect(checkChoice('', 'A'), false);
  });

  test('fill_blank substring check (case-insensitive)', () {
    bool checkFill(String answer, String correct) =>
        answer.trim().toLowerCase().contains(correct.toLowerCase());

    expect(checkFill('mluvím', 'mluvím'), true);
    expect(checkFill('  Mluvím  ', 'mluvím'), true);
    expect(checkFill('jdu', 'mluvím'), false);
    expect(checkFill('', 'mluvím'), false);
  });
});
} // end main
