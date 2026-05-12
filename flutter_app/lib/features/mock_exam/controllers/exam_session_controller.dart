import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../models/models.dart';

/// V39 — owns the learner-visible state of a single mock exam session:
///   * the session snapshot (sections + timer fields),
///   * a 1-second ticker that exposes [remaining] for the app bar,
///   * the current `display_order` pointer,
///   * mutating actions: [skip], [advance], [jumpTo], [refresh].
///
/// The controller does not own UI — screens listen to it via
/// `ChangeNotifier`/`ListenableBuilder`. The 1-second ticker is purely
/// local; the source of truth is the server's `expires_at`.
class ExamSessionController extends ChangeNotifier {
  ExamSessionController({
    required this.client,
    required MockExamSessionView initial,
    DateTime Function()? clock,
  }) : _session = initial,
       _clock = clock ?? DateTime.now,
       _currentDisplayOrder = _firstActionableDisplayOrder(initial);

  final ApiClient client;
  final DateTime Function() _clock;

  MockExamSessionView _session;
  int _currentDisplayOrder;
  Timer? _ticker;
  bool _busy = false;

  MockExamSessionView get session => _session;
  int get currentDisplayOrder => _currentDisplayOrder;
  bool get busy => _busy;

  /// Time remaining until the server-anchored timer expires. Returns
  /// [Duration.zero] for pre-V39 sessions or once the timer has run out.
  Duration get remaining => _session.remainingAt(_clock());

  /// Number of sections the learner has resolved (done or skipped).
  int get resolvedCount =>
      _session.sections.where((s) => s.isCompleted || s.isSkipped).length;

  /// Section the learner is currently looking at. Falls back to the first
  /// section by display_order when the pointer drifts (defensive).
  MockExamSection get currentSection {
    for (final s in _session.sections) {
      if (s.displayOrder == _currentDisplayOrder) return s;
    }
    return _session.sections.first;
  }

  /// Start the 1-second ticker that drives [remaining] notifications.
  /// Called from the player screen's `initState`.
  void startTicker() {
    _ticker?.cancel();
    if (!_session.hasTimer) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Skip the currently-active section. Server flips it to 'skipped'
  /// and we advance the pointer to the next actionable section.
  Future<void> skipCurrent() async {
    if (_busy) return;
    final target = _currentDisplayOrder;
    _busy = true;
    notifyListeners();
    try {
      final json = await client.skipMockExamSection(
        _session.id,
        displayOrder: target,
      );
      _session = MockExamSessionView.fromJson(json);
      _currentDisplayOrder = _nextActionableAfter(target);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Advance to the next pending section. The server may already have
  /// the attempt linked (regular answer-submit path) — call this once the
  /// attempt is recorded server-side.
  Future<void> advanceAfterAttempt(String attemptId) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      final json = await client.advanceMockExam(
        _session.id,
        attemptId: attemptId,
      );
      _session = MockExamSessionView.fromJson(json);
      _currentDisplayOrder = _nextActionableAfter(_currentDisplayOrder);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Jump the cursor to a specific section. UI invokes this from the
  /// answer-sheet (S6/S7) without hitting the server.
  void jumpTo(int displayOrder) {
    if (displayOrder == _currentDisplayOrder) return;
    _currentDisplayOrder = displayOrder;
    notifyListeners();
  }

  /// Re-fetch the session from the server. Useful on app-resume to
  /// anchor against the server clock.
  Future<void> refresh() async {
    final json = await client.getMockExam(_session.id);
    _session = MockExamSessionView.fromJson(json);
    notifyListeners();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  int _nextActionableAfter(int after) {
    final sorted = [..._session.sections]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    for (final s in sorted) {
      if (s.displayOrder > after && (s.isPending || s.isSkipped)) {
        return s.displayOrder;
      }
    }
    // No actionable section past `after` — stay put.
    return after;
  }

  static int _firstActionableDisplayOrder(MockExamSessionView session) {
    final sorted = [...session.sections]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    for (final s in sorted) {
      if (s.isPending || s.isSkipped) return s.displayOrder;
    }
    return sorted.isNotEmpty ? sorted.first.displayOrder : 1;
  }
}
