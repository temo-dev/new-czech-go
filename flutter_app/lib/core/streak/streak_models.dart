/// Client-side projection of the V17 `/v1/users/me` `streak` block.
class StreakSummary {
  const StreakSummary({
    required this.currentDays,
    required this.longestDays,
    this.lastCompletedDay,
    required this.gracePassesLeftThisWeek,
  });

  final int currentDays;
  final int longestDays;
  final DateTime? lastCompletedDay;
  final int gracePassesLeftThisWeek;

  static const empty = StreakSummary(
    currentDays: 0,
    longestDays: 0,
    gracePassesLeftThisWeek: 0,
  );

  factory StreakSummary.fromJson(Map<String, dynamic> json) {
    final last = json['last_completed_day'] as String?;
    return StreakSummary(
      currentDays: (json['current_days'] as num?)?.toInt() ?? 0,
      longestDays: (json['longest_days'] as num?)?.toInt() ?? 0,
      lastCompletedDay: (last == null || last.isEmpty) ? null : DateTime.tryParse(last),
      gracePassesLeftThisWeek:
          (json['grace_passes_left_this_week'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Free-tier daily-usage projection. Pro learners see this as the
/// quota-indicator placeholder; free learners see "3/7 attempts hôm nay".
class DailyUsageSummary {
  const DailyUsageSummary({
    required this.attempts,
    required this.attemptsLimit,
    required this.interviews,
    required this.interviewsLimit,
  });

  final int attempts;
  final int attemptsLimit;
  final int interviews;
  final int interviewsLimit;

  static const empty = DailyUsageSummary(
    attempts: 0,
    attemptsLimit: 7,
    interviews: 0,
    interviewsLimit: 1,
  );

  factory DailyUsageSummary.fromJson(Map<String, dynamic> json) {
    return DailyUsageSummary(
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      attemptsLimit: (json['attempts_limit'] as num?)?.toInt() ?? 7,
      interviews: (json['interviews_this_week'] as num?)?.toInt() ?? 0,
      interviewsLimit: (json['interviews_limit'] as num?)?.toInt() ?? 1,
    );
  }
}
