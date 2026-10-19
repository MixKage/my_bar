/// Local, bounded usage history. This records review *attempts*, not whether a
/// store displayed its dialog or whether the person submitted a rating.
class ReviewPromptState {
  factory ReviewPromptState({
    DateTime? firstUsedAt,
    DateTime? lastObservedAt,
    Iterable<DateTime> usageDays = const [],
    int successfulActionCount = 0,
    Iterable<DateTime> attemptDates = const [],
  }) {
    final days = usageDays.map(_utcDay).toSet().toList()..sort();
    final attempts = attemptDates.map((date) => date.toUtc()).toList()..sort();
    return ReviewPromptState._(
      firstUsedAt: firstUsedAt?.toUtc(),
      lastObservedAt: lastObservedAt?.toUtc(),
      // Only the first three distinct usage days are needed for eligibility.
      usageDays: List.unmodifiable(days.take(3)),
      successfulActionCount: successfulActionCount.clamp(0, 5),
      // The three most recent attempts suffice for the rolling annual limit.
      attemptDates: List.unmodifiable(
        attempts.skip(attempts.length > 3 ? attempts.length - 3 : 0),
      ),
    );
  }

  const ReviewPromptState.empty()
    : firstUsedAt = null,
      lastObservedAt = null,
      usageDays = const [],
      successfulActionCount = 0,
      attemptDates = const [];

  const ReviewPromptState._({
    required this.firstUsedAt,
    required this.lastObservedAt,
    required this.usageDays,
    required this.successfulActionCount,
    required this.attemptDates,
  });

  final DateTime? firstUsedAt;
  final DateTime? lastObservedAt;
  final List<DateTime> usageDays;
  final int successfulActionCount;
  final List<DateTime> attemptDates;

  ReviewPromptState recordUsage(DateTime now) {
    final utcNow = now.toUtc();
    if (_isClockRollback(utcNow)) return this;
    return ReviewPromptState(
      firstUsedAt: firstUsedAt ?? utcNow,
      lastObservedAt: utcNow,
      usageDays: [...usageDays, utcNow],
      successfulActionCount: successfulActionCount,
      attemptDates: attemptDates,
    );
  }

  ReviewPromptState recordSuccessfulAction(DateTime now) {
    if (_isClockRollback(now.toUtc())) return this;
    final used = recordUsage(now);
    return ReviewPromptState(
      firstUsedAt: used.firstUsedAt,
      lastObservedAt: used.lastObservedAt,
      usageDays: used.usageDays,
      successfulActionCount: successfulActionCount + 1,
      attemptDates: attemptDates,
    );
  }

  ReviewPromptState recordAttempt(DateTime now) {
    if (_isClockRollback(now.toUtc())) return this;
    final used = recordUsage(now);
    return ReviewPromptState(
      firstUsedAt: used.firstUsedAt,
      lastObservedAt: used.lastObservedAt,
      usageDays: used.usageDays,
      successfulActionCount: successfulActionCount,
      attemptDates: [...attemptDates, now.toUtc()],
    );
  }

  bool _isClockRollback(DateTime now) {
    final latestObservation = lastObservedAt ?? firstUsedAt;
    return latestObservation != null && now.isBefore(latestObservation);
  }
}

class ReviewPromptPolicy {
  const ReviewPromptPolicy();

  static const minimumUsageAge = Duration(days: 7);
  static const minimumForegroundDuration = Duration(minutes: 2);
  static const minimumAttemptInterval = Duration(days: 120);
  static const attemptWindow = Duration(days: 365);
  static const minimumUsageDays = 3;
  static const minimumSuccessfulActions = 5;
  static const maximumAttemptsPerWindow = 3;

  bool isEligible(
    ReviewPromptState state, {
    required DateTime now,
    required Duration foregroundDuration,
  }) {
    final utcNow = now.toUtc();
    final firstUsedAt = state.firstUsedAt;
    final lastObservedAt = state.lastObservedAt;
    if (firstUsedAt == null ||
        lastObservedAt == null ||
        lastObservedAt.isBefore(firstUsedAt) ||
        utcNow.isBefore(lastObservedAt) ||
        utcNow.difference(firstUsedAt) < minimumUsageAge ||
        foregroundDuration < minimumForegroundDuration ||
        state.usageDays.length < minimumUsageDays ||
        state.successfulActionCount < minimumSuccessfulActions) {
      return false;
    }

    final firstDay = _utcDay(firstUsedAt);
    final lastDay = _utcDay(lastObservedAt);
    if (state.usageDays.any(
      (day) => day.isBefore(firstDay) || day.isAfter(lastDay),
    )) {
      return false;
    }

    if (state.attemptDates.any(
      (date) => date.isBefore(firstUsedAt) || date.isAfter(lastObservedAt),
    )) {
      return false;
    }
    if (state.attemptDates.isNotEmpty &&
        utcNow.difference(state.attemptDates.last) < minimumAttemptInterval) {
      return false;
    }
    return state.attemptDates
            .where((date) => utcNow.difference(date) < attemptWindow)
            .length <
        maximumAttemptsPerWindow;
  }
}

DateTime _utcDay(DateTime date) {
  final utc = date.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}
