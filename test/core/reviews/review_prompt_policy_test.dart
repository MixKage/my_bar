import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/reviews/review_prompt_policy.dart';

void main() {
  const policy = ReviewPromptPolicy();
  const foregroundDuration = Duration(minutes: 2);
  final now = DateTime.utc(2026, 10, 20, 12);

  ReviewPromptState ready({
    DateTime? firstUsedAt,
    DateTime? lastObservedAt,
    List<DateTime>? usageDays,
    int successfulActionCount = 5,
    List<DateTime> attemptDates = const [],
  }) => ReviewPromptState(
    firstUsedAt: firstUsedAt ?? now.subtract(const Duration(days: 8)),
    lastObservedAt: lastObservedAt ?? now,
    usageDays:
        usageDays ??
        [
          now.subtract(const Duration(days: 8)),
          now.subtract(const Duration(days: 4)),
          now,
        ],
    successfulActionCount: successfulActionCount,
    attemptDates: attemptDates,
  );

  bool eligible(ReviewPromptState state, {DateTime? at, Duration? activeFor}) =>
      policy.isEligible(
        state,
        now: at ?? now,
        foregroundDuration: activeFor ?? foregroundDuration,
      );

  test('a fresh install cannot request a review', () {
    expect(eligible(const ReviewPromptState.empty()), isFalse);
    expect(eligible(const ReviewPromptState.empty().recordUsage(now)), isFalse);
  });

  test('requires seven complete days of usage history', () {
    final first = now.subtract(const Duration(days: 7));
    final state = ready(
      firstUsedAt: first,
      usageDays: [first, first.add(const Duration(days: 1)), now],
    );
    expect(eligible(state), isTrue);
    expect(
      eligible(
        ready(
          firstUsedAt: first.add(const Duration(microseconds: 1)),
          usageDays: state.usageDays,
        ),
      ),
      isFalse,
    );
  });

  test('requires three distinct usage days and five successful actions', () {
    expect(eligible(ready()), isTrue);
    expect(
      eligible(ready(usageDays: [now.subtract(const Duration(days: 8)), now])),
      isFalse,
    );
    expect(eligible(ready(successfulActionCount: 4)), isFalse);
  });

  test('requires two foreground minutes in the current session', () {
    expect(eligible(ready(), activeFor: Duration.zero), isFalse);
    expect(
      eligible(
        ready(),
        activeFor: foregroundDuration - const Duration(microseconds: 1),
      ),
      isFalse,
    );
    expect(eligible(ready(), activeFor: foregroundDuration), isTrue);
  });

  test('records a single day for repeat usage within one UTC day', () {
    final first = DateTime.parse('2026-10-20T23:30:00-03:00');
    final second = DateTime.parse('2026-10-21T04:00:00Z');
    final state = const ReviewPromptState.empty()
        .recordUsage(first)
        .recordUsage(second);
    expect(state.usageDays, [DateTime.utc(2026, 10, 21)]);
    expect(state.firstUsedAt, first.toUtc());
    expect(state.lastObservedAt, second);
    expect(state.firstUsedAt!.isUtc, isTrue);
  });

  test('usage does not implicitly count successful actions or attempts', () {
    final state = const ReviewPromptState.empty().recordUsage(now);
    expect(state.successfulActionCount, 0);
    expect(state.attemptDates, isEmpty);
  });

  test('successful actions also record usage without recording an attempt', () {
    final state = const ReviewPromptState.empty().recordSuccessfulAction(now);
    expect(state.firstUsedAt, now);
    expect(state.usageDays, [DateTime.utc(2026, 10, 20)]);
    expect(state.successfulActionCount, 1);
    expect(state.attemptDates, isEmpty);
  });

  test('retains only the first three distinct days and five actions', () {
    var state = const ReviewPromptState.empty();
    final first = now.subtract(const Duration(days: 20));
    for (var day = 0; day < 20; day++) {
      state = state.recordSuccessfulAction(first.add(Duration(days: day)));
    }
    expect(state.usageDays, [
      DateTime.utc(2026, 9, 30),
      DateTime.utc(2026, 10, 1),
      DateTime.utc(2026, 10, 2),
    ]);
    expect(state.successfulActionCount, 5);
    expect(state.lastObservedAt, first.add(const Duration(days: 19)));
  });

  test('constructor protects and normalizes mutable input collections', () {
    final days = [now];
    final attempts = [now];
    final state = ready(usageDays: days, attemptDates: attempts);
    days.clear();
    attempts.clear();
    expect(state.usageDays, [DateTime.utc(2026, 10, 20)]);
    expect(state.attemptDates, [now]);
    expect(() => state.usageDays.add(now), throwsUnsupportedError);
    expect(() => state.attemptDates.clear(), throwsUnsupportedError);
  });

  test('clock rollback cannot manufacture a new usage day or action', () {
    final state = ready();
    final earlier = now.subtract(const Duration(days: 1));
    expect(eligible(state, at: earlier), isFalse);
    expect(identical(state.recordUsage(earlier), state), isTrue);
    expect(identical(state.recordSuccessfulAction(earlier), state), isTrue);
    expect(identical(state.recordAttempt(earlier), state), isTrue);
    expect(eligible(state, at: now), isTrue);
  });

  test('future first usage and inconsistent observations are ineligible', () {
    expect(
      eligible(
        ready(
          firstUsedAt: now.add(const Duration(days: 1)),
          lastObservedAt: now.add(const Duration(days: 1)),
        ),
      ),
      isFalse,
    );
    expect(
      eligible(ready(lastObservedAt: now.subtract(const Duration(days: 20)))),
      isFalse,
    );
  });

  test('rejects usage dates outside the observation range', () {
    expect(
      eligible(
        ready(
          usageDays: [
            now.subtract(const Duration(days: 9)),
            now.subtract(const Duration(days: 4)),
            now,
          ],
        ),
      ),
      isFalse,
    );
    expect(
      eligible(
        ready(
          usageDays: [
            now.subtract(const Duration(days: 8)),
            now.subtract(const Duration(days: 4)),
            now.add(const Duration(days: 1)),
          ],
        ),
      ),
      isFalse,
    );
  });

  test(
    'an attempted native request immediately suppresses another attempt',
    () {
      final state = ready();
      final attempted = state.recordAttempt(now);
      expect(eligible(state), isTrue);
      expect(eligible(attempted), isFalse);
      expect(attempted.attemptDates, [now]);
      expect(attempted.successfulActionCount, state.successfulActionCount);
      expect(state.attemptDates, isEmpty);
    },
  );

  test('waits at least 120 days between attempts', () {
    final state = ready(
      firstUsedAt: now.subtract(const Duration(days: 200)),
      attemptDates: [now.subtract(const Duration(days: 120))],
    );
    expect(eligible(state), isTrue);
    expect(
      eligible(
        ready(
          firstUsedAt: state.firstUsedAt,
          attemptDates: [
            state.attemptDates.single.add(const Duration(microseconds: 1)),
          ],
        ),
      ),
      isFalse,
    );
  });

  test('allows at most three attempts in a rolling 365-day window', () {
    final state = ready(
      firstUsedAt: now.subtract(const Duration(days: 500)),
      attemptDates: [
        now.subtract(const Duration(days: 364)),
        now.subtract(const Duration(days: 244)),
        now.subtract(const Duration(days: 124)),
      ],
    );
    expect(eligible(state), isFalse);
    expect(eligible(state, at: now.add(const Duration(days: 1))), isTrue);
  });

  test('only the most recent three attempts need to be retained', () {
    final state = ready(
      firstUsedAt: now.subtract(const Duration(days: 600)),
      attemptDates: [
        now.subtract(const Duration(days: 500)),
        now.subtract(const Duration(days: 364)),
        now.subtract(const Duration(days: 244)),
        now.subtract(const Duration(days: 124)),
      ],
    );
    expect(state.attemptDates.length, 3);
    expect(state.attemptDates.first, now.subtract(const Duration(days: 364)));
    expect(eligible(state), isFalse);
  });

  test('same-instant attempts still count as separate native requests', () {
    final state = ready(
      firstUsedAt: now.subtract(const Duration(days: 500)),
      attemptDates: List.filled(3, now.subtract(const Duration(days: 121))),
    );
    expect(state.attemptDates.length, 3);
    expect(eligible(state), isFalse);
  });

  test('future or pre-installation attempts cannot enable a request', () {
    expect(
      eligible(ready(attemptDates: [now.add(const Duration(days: 1))])),
      isFalse,
    );
    expect(
      eligible(ready(attemptDates: [now.subtract(const Duration(days: 200))])),
      isFalse,
    );
  });
}
