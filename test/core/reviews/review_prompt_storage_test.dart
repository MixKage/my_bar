import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/reviews/review_prompt_policy.dart';
import 'package:my_bar/core/reviews/review_prompt_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final first = DateTime.utc(2026, 10, 1, 12);
  final latest = DateTime.utc(2026, 10, 20, 12);

  Map<String, Object?> validData() => {
    'version': 1,
    'firstUsedAt': first.millisecondsSinceEpoch,
    'lastObservedAt': latest.millisecondsSinceEpoch,
    'usageDays': [
      DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
      DateTime.utc(2026, 10, 2).millisecondsSinceEpoch,
      DateTime.utc(2026, 10, 3).millisecondsSinceEpoch,
    ],
    'successfulActionCount': 5,
    'attemptDates': [latest.millisecondsSinceEpoch],
  };

  Future<SharedPreferencesReviewPromptStorage> storageWith(Object? raw) async {
    final values = <String, Object>{};
    if (raw != null) {
      values[SharedPreferencesReviewPromptStorage.stateKey] = raw;
    }
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferencesReviewPromptStorage(
      await SharedPreferences.getInstance(),
    );
  }

  void expectEmpty(ReviewPromptState state) {
    expect(state.firstUsedAt, isNull);
    expect(state.lastObservedAt, isNull);
    expect(state.usageDays, isEmpty);
    expect(state.successfulActionCount, 0);
    expect(state.attemptDates, isEmpty);
  }

  test('missing storage starts without eligibility history', () async {
    expectEmpty((await storageWith(null)).read());
  });

  test(
    'persists usage, actions, and attempted requests across restarts',
    () async {
      final storage = await storageWith(null);
      final state = const ReviewPromptState.empty()
          .recordSuccessfulAction(first)
          .recordUsage(first.add(const Duration(days: 1)))
          .recordSuccessfulAction(latest)
          .recordAttempt(latest);
      await storage.write(state);
      final preferences = await SharedPreferences.getInstance();
      final restored = SharedPreferencesReviewPromptStorage(preferences).read();

      expect(restored.firstUsedAt, first);
      expect(restored.lastObservedAt, latest);
      expect(restored.usageDays, state.usageDays);
      expect(restored.successfulActionCount, 2);
      expect(restored.attemptDates, [latest]);
      expect(
        const ReviewPromptPolicy().isEligible(
          restored,
          now: latest,
          foregroundDuration: const Duration(minutes: 2),
        ),
        isFalse,
      );
    },
  );

  test('an empty state can be persisted and read safely', () async {
    final storage = await storageWith(null);
    await storage.write(const ReviewPromptState.empty());
    expectEmpty(storage.read());
  });

  test('accepts a valid bounded schema', () async {
    final state = (await storageWith(jsonEncode(validData()))).read();
    expect(state.firstUsedAt, first);
    expect(state.lastObservedAt, latest);
    expect(state.usageDays.length, 3);
    expect(state.successfulActionCount, 5);
    expect(state.attemptDates, [latest]);
  });

  final malformedValues = <Object>[
    true,
    42,
    <String>['not a json string'],
    '',
    '{broken json',
    'null',
    '[]',
    '{}',
    List.filled(4097, 'x').join(),
  ];
  for (final (index, raw) in malformedValues.indexed) {
    test(
      'ignores malformed stored value $index (${raw.runtimeType})',
      () async {
        expectEmpty((await storageWith(raw)).read());
      },
    );
  }

  final invalidFields = <String, Object?>{
    'version': 2,
    'firstUsedAt': 'yesterday',
    'lastObservedAt': -1,
    'usageDays': [null],
    'successfulActionCount': '5',
    'attemptDates': [8640000000000001],
  };
  for (final entry in invalidFields.entries) {
    test(
      'ignores invalid ${entry.key} instead of trusting partial history',
      () async {
        final data = validData()..[entry.key] = entry.value;
        expectEmpty((await storageWith(jsonEncode(data))).read());
      },
    );
  }

  test('rejects out-of-range counters and unbounded histories', () async {
    for (final count in [-1, 6, 1000000]) {
      final data = validData()..['successfulActionCount'] = count;
      expectEmpty((await storageWith(jsonEncode(data))).read());
    }
    for (final field in ['usageDays', 'attemptDates']) {
      final data = validData()
        ..[field] = List.filled(4, latest.millisecondsSinceEpoch);
      expectEmpty((await storageWith(jsonEncode(data))).read());
    }
  });

  test('persisted history remains bounded after extensive use', () async {
    final storage = await storageWith(null);
    var state = const ReviewPromptState.empty();
    for (var day = 0; day < 1000; day++) {
      final at = first.add(Duration(days: day));
      state = state.recordSuccessfulAction(at).recordAttempt(at);
    }
    await storage.write(state);
    final restored = storage.read();
    expect(restored.usageDays.length, 3);
    expect(restored.successfulActionCount, 5);
    expect(restored.attemptDates.length, 3);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences
          .getString(SharedPreferencesReviewPromptStorage.stateKey)!
          .length,
      lessThan(512),
    );
  });

  test('does not trust chronologically inconsistent history', () async {
    final variants = [
      validData()..['lastObservedAt'] = first.millisecondsSinceEpoch - 1,
      validData()..['usageDays'] = [first.millisecondsSinceEpoch - 86400000],
      validData()..['usageDays'] = [latest.millisecondsSinceEpoch + 86400000],
      validData()..['attemptDates'] = [first.millisecondsSinceEpoch - 1],
      validData()..['attemptDates'] = [latest.millisecondsSinceEpoch + 1],
    ];
    for (final data in variants) {
      expectEmpty((await storageWith(jsonEncode(data))).read());
    }
  });

  test('future observations survive storage but remain ineligible', () async {
    final storage = await storageWith(jsonEncode(validData()));
    final state = storage.read();
    expect(state.firstUsedAt, isNotNull);
    expect(
      const ReviewPromptPolicy().isEligible(
        state,
        now: latest.subtract(const Duration(days: 1)),
        foregroundDuration: const Duration(minutes: 2),
      ),
      isFalse,
    );
    expect(identical(state.recordUsage(first), state), isTrue);
  });

  test('in-memory implementation has the same read/write interface', () async {
    final storage = InMemoryReviewPromptStorage();
    expectEmpty(storage.read());
    final state = const ReviewPromptState.empty().recordUsage(first);
    await storage.write(state);
    expect(identical(storage.read(), state), isTrue);
    expect(
      identical(InMemoryReviewPromptStorage(initial: state).read(), state),
      isTrue,
    );
  });
}
