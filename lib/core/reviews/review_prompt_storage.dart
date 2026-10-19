import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'review_prompt_policy.dart';

abstract class ReviewPromptStorage {
  ReviewPromptState read();
  Future<void> write(ReviewPromptState state);
}

class SharedPreferencesReviewPromptStorage implements ReviewPromptStorage {
  const SharedPreferencesReviewPromptStorage(this._preferences);

  static const String stateKey = 'review_prompt_state_v1';

  final SharedPreferences _preferences;

  @override
  ReviewPromptState read() {
    final raw = _preferences.get(stateKey);
    if (raw is! String || raw.length > 4096) {
      return const ReviewPromptState.empty();
    }
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['version'] != 1) {
        return const ReviewPromptState.empty();
      }
      final firstUsedAt = _readDate(value['firstUsedAt']);
      final lastObservedAt = _readDate(value['lastObservedAt']);
      final days = _readDates(value['usageDays']);
      final attempts = _readDates(value['attemptDates']);
      final actions = value['successfulActionCount'];
      if (actions is! int || actions < 0 || actions > 5) {
        return const ReviewPromptState.empty();
      }
      if (firstUsedAt == null || lastObservedAt == null) {
        return const ReviewPromptState.empty();
      }
      if (lastObservedAt.isBefore(firstUsedAt) ||
          days.any(
            (date) =>
                _day(date).isBefore(_day(firstUsedAt)) ||
                _day(date).isAfter(_day(lastObservedAt)),
          ) ||
          attempts.any(
            (date) =>
                date.isBefore(firstUsedAt) || date.isAfter(lastObservedAt),
          )) {
        return const ReviewPromptState.empty();
      }
      return ReviewPromptState(
        firstUsedAt: firstUsedAt,
        lastObservedAt: lastObservedAt,
        usageDays: days,
        successfulActionCount: actions,
        attemptDates: attempts,
      );
    } on FormatException {
      return const ReviewPromptState.empty();
    } on ArgumentError {
      return const ReviewPromptState.empty();
    }
  }

  @override
  Future<void> write(ReviewPromptState state) async {
    final saved = await _preferences.setString(
      stateKey,
      jsonEncode({
        'version': 1,
        'firstUsedAt': state.firstUsedAt?.millisecondsSinceEpoch,
        'lastObservedAt': state.lastObservedAt?.millisecondsSinceEpoch,
        'usageDays': state.usageDays
            .map((date) => date.millisecondsSinceEpoch)
            .toList(),
        'successfulActionCount': state.successfulActionCount,
        'attemptDates': state.attemptDates
            .map((date) => date.millisecondsSinceEpoch)
            .toList(),
      }),
    );
    if (!saved) {
      throw StateError('Could not persist review prompt history.');
    }
  }

  static List<DateTime> _readDates(Object? value) {
    if (value is! List || value.length > 3) {
      throw const FormatException('Invalid review history list.');
    }
    return value.map((entry) {
      final date = _readDate(entry);
      if (date == null) {
        throw const FormatException('Invalid review history date.');
      }
      return date;
    }).toList();
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is! int || value < 0 || value > 8640000000000000) {
      throw const FormatException('Invalid review history timestamp.');
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  static DateTime _day(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}

class InMemoryReviewPromptStorage implements ReviewPromptStorage {
  InMemoryReviewPromptStorage({ReviewPromptState? initial})
    : _state = initial ?? const ReviewPromptState.empty();

  ReviewPromptState _state;

  @override
  ReviewPromptState read() => _state;

  @override
  Future<void> write(ReviewPromptState state) async {
    _state = state;
  }
}
