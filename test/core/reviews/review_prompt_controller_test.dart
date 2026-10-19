import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/reviews/native_review_gateway.dart';
import 'package:my_bar/core/reviews/review_prompt_controller.dart';
import 'package:my_bar/core/reviews/review_prompt_policy.dart';
import 'package:my_bar/core/reviews/review_prompt_storage.dart';

final _today = DateTime.utc(2026, 10, 20, 12);

ReviewPromptState _eligibleState({int actions = 5}) => ReviewPromptState(
  firstUsedAt: _today.subtract(const Duration(days: 7)),
  lastObservedAt: _today,
  usageDays: [
    _today.subtract(const Duration(days: 7)),
    _today.subtract(const Duration(days: 6)),
    _today,
  ],
  successfulActionCount: actions,
);

void main() {
  test(
    'does not request a review during first use, even after many actions',
    () async {
      final h = _Harness(initial: const ReviewPromptState.empty());

      await h.controller.startSession();
      for (var i = 0; i < 8; i++) {
        await h.controller.recordSuccessfulAction();
      }
      await h.maybeRequest();

      expect(h.storage.state.firstUsedAt, _today);
      expect(h.storage.state.usageDays, [DateTime.utc(2026, 10, 20)]);
      expect(h.storage.state.successfulActionCount, 5);
      expect(h.gateway.availabilityCalls, 0);
      expect(h.gateway.requestCalls, 0);
    },
  );

  test(
    'counts only recorded successful actions during an active session',
    () async {
      final h = _Harness(initial: const ReviewPromptState.empty());
      await h.controller.recordSuccessfulAction();
      expect(h.storage.state.successfulActionCount, 0);

      await h.controller.startSession();
      await h.controller.recordSuccessfulAction();
      await h.controller.recordSuccessfulAction();
      expect(h.storage.state.successfulActionCount, 2);

      h.controller.stopSession();
      await h.controller.recordSuccessfulAction();
      expect(h.storage.state.successfulActionCount, 2);
    },
  );

  test(
    'requests after seven days, three usage days, five actions and two minutes',
    () async {
      final h = _Harness();

      await h.controller.startSession();
      await h.maybeRequest();

      expect(h.gateway.availabilityCalls, 1);
      expect(h.gateway.requestCalls, 1);
      expect(h.storage.state.attemptDates, [_today]);
    },
  );

  test(
    'waits for two foreground minutes before checking availability',
    () async {
      final h = _Harness()
        ..foreground = const Duration(minutes: 1, seconds: 59);
      await h.controller.startSession();
      await h.maybeRequest();
      expect(h.gateway.availabilityCalls, 0);

      h.foreground = const Duration(minutes: 2);
      await h.maybeRequest();
      expect(h.gateway.requestCalls, 1);
    },
  );

  test('waits for the fifth successful action', () async {
    final h = _Harness(initial: _eligibleState(actions: 4));
    await h.controller.startSession();
    await h.maybeRequest();
    expect(h.gateway.availabilityCalls, 0);

    await h.controller.recordSuccessfulAction();
    await h.maybeRequest();
    expect(h.gateway.requestCalls, 1);
  });

  test(
    'unsupported platforms never record usage or call the native API',
    () async {
      final h = _Harness(supported: false);

      await h.controller.startSession();
      await h.controller.recordSuccessfulAction();
      await h.maybeRequest();

      expect(h.storage.writes, isEmpty);
      expect(h.gateway.availabilityCalls, 0);
      expect(h.gateway.requestCalls, 0);
    },
  );

  test('unavailable native API is checked only once per session', () async {
    final h = _Harness()..gateway.available = false;
    await h.controller.startSession();

    await h.maybeRequest();
    await h.maybeRequest();
    expect(h.gateway.availabilityCalls, 1);
    expect(h.gateway.requestCalls, 0);
    expect(h.storage.state.attemptDates, isEmpty);

    h.controller.stopSession();
    await h.controller.startSession();
    await h.maybeRequest();
    expect(h.gateway.availabilityCalls, 2);
  });

  test(
    'availability errors are swallowed without repeated checks that session',
    () async {
      final h = _Harness()..gateway.availabilityError = StateError('offline');
      await h.controller.startSession();

      await h.maybeRequest();
      await h.maybeRequest();

      expect(h.gateway.availabilityCalls, 1);
      expect(h.gateway.requestCalls, 0);
      expect(h.storage.state.attemptDates, isEmpty);
    },
  );

  test('native request failure still consumes the persisted attempt', () async {
    final h = _Harness()
      ..gateway.requestError = StateError('store unavailable');
    await h.controller.startSession();

    await h.maybeRequest();
    await h.maybeRequest();
    h.controller.stopSession();
    await h.controller.startSession();
    await h.maybeRequest();

    expect(h.gateway.requestCalls, 1);
    expect(h.storage.state.attemptDates, [_today]);
  });

  test(
    'failed session persistence disables further work for this controller',
    () async {
      final h = _Harness()..storage.failWrites = true;
      await h.controller.startSession();
      await h.controller.recordSuccessfulAction();
      await h.maybeRequest();

      h.storage.failWrites = false;
      h.controller.stopSession();
      await h.controller.startSession();
      await h.maybeRequest();

      expect(h.storage.writes, hasLength(1));
      expect(h.gateway.availabilityCalls, 0);
      expect(h.gateway.requestCalls, 0);
      expect(h.storage.state.attemptDates, isEmpty);
    },
  );

  test(
    'failed attempt persistence prevents a native request and future retries',
    () async {
      final h = _Harness();
      await h.controller.startSession();
      h.storage.failWrites = true;
      await h.maybeRequest();

      h.storage.failWrites = false;
      h.controller.stopSession();
      await h.controller.startSession();
      await h.maybeRequest();

      expect(h.storage.writes, hasLength(2));
      expect(h.gateway.availabilityCalls, 1);
      expect(h.gateway.requestCalls, 0);
      expect(h.storage.state.attemptDates, isEmpty);
    },
  );

  test('an attempt is persisted before calling the native API', () async {
    final h = _Harness();
    List<DateTime>? persistedAtRequest;
    h.gateway.onRequest = () {
      persistedAtRequest = List.of(h.storage.state.attemptDates);
    };

    await h.controller.startSession();
    await h.maybeRequest();

    expect(h.gateway.requestCalls, 1);
    expect(persistedAtRequest, [_today]);
  });

  test('concurrent checks result in just one native request', () async {
    final h = _Harness();
    final availability = Completer<bool>();
    h.gateway.availabilityResult = availability.future;
    await h.controller.startSession();

    final first = h.maybeRequest();
    final second = h.maybeRequest();
    final third = h.maybeRequest();
    await h.gateway.availabilityStarted.future;
    expect(h.gateway.availabilityCalls, 1);

    availability.complete(true);
    await Future.wait([first, second, third]);

    expect(h.gateway.availabilityCalls, 1);
    expect(h.gateway.requestCalls, 1);
    expect(h.storage.state.attemptDates, hasLength(1));
  });

  test('no request is made while the app is in the background', () async {
    final h = _Harness();
    await h.controller.startSession();
    h.controller.stopSession();

    await h.maybeRequest();

    expect(h.gateway.availabilityCalls, 0);
    expect(h.gateway.requestCalls, 0);
  });

  test('disposed controllers ignore queued review and action work', () async {
    final h = _Harness();
    await h.controller.startSession();
    final writesBeforeDisposal = h.storage.writes.length;
    h.dispose();

    await h.controller.startSession();
    await h.controller.recordSuccessfulAction();
    await h.maybeRequest();

    expect(h.storage.writes, hasLength(writesBeforeDisposal));
    expect(h.gateway.availabilityCalls, 0);
    expect(h.gateway.requestCalls, 0);
  });

  test(
    'backgrounding during availability cancels the pending request',
    () async {
      final h = _Harness();
      final availability = Completer<bool>();
      h.gateway.availabilityResult = availability.future;
      await h.controller.startSession();

      final pending = h.maybeRequest();
      await h.gateway.availabilityStarted.future;
      h.controller.stopSession();
      availability.complete(true);
      await pending;

      expect(h.gateway.requestCalls, 0);
      expect(h.storage.state.attemptDates, isEmpty);
    },
  );

  test(
    'background and resume cannot revive an old availability check',
    () async {
      final h = _Harness();
      final availability = Completer<bool>();
      h.gateway.availabilityResult = availability.future;
      await h.controller.startSession();

      final pending = h.maybeRequest();
      await h.gateway.availabilityStarted.future;
      h.controller.stopSession();
      final resumed = h.controller.startSession();
      availability.complete(true);
      await Future.wait([pending, resumed]);

      expect(h.gateway.requestCalls, 0);
      expect(h.storage.state.attemptDates, isEmpty);

      h.gateway.availabilityResult = null;
      await h.maybeRequest();
      expect(h.gateway.availabilityCalls, 2);
      expect(h.gateway.requestCalls, 1);
    },
  );

  test('disposal during availability cancels the pending request', () async {
    final h = _Harness();
    final availability = Completer<bool>();
    h.gateway.availabilityResult = availability.future;
    await h.controller.startSession();

    final pending = h.maybeRequest();
    await h.gateway.availabilityStarted.future;
    h.dispose();
    availability.complete(true);
    await pending;

    expect(h.gateway.requestCalls, 0);
    expect(h.storage.state.attemptDates, isEmpty);
  });

  test(
    'does not interrupt an unsafe UI, but can try at a later safe moment',
    () async {
      final h = _Harness();
      await h.controller.startSession();

      await h.controller.maybeRequest(canPresent: () => false);
      expect(h.gateway.availabilityCalls, 0);

      await h.maybeRequest();
      expect(h.gateway.requestCalls, 1);
    },
  );

  test('rechecks UI safety after asynchronous native availability', () async {
    final h = _Harness();
    final availability = Completer<bool>();
    h.gateway.availabilityResult = availability.future;
    var canPresent = true;
    await h.controller.startSession();

    final pending = h.controller.maybeRequest(canPresent: () => canPresent);
    await h.gateway.availabilityStarted.future;
    canPresent = false;
    availability.complete(true);
    await pending;

    expect(h.gateway.requestCalls, 0);
    expect(h.storage.state.attemptDates, isEmpty);
  });

  test('failed history reads disable prompting without crashing', () async {
    final h = _Harness(failReads: true);

    await h.controller.startSession();
    await h.controller.recordSuccessfulAction();
    await h.maybeRequest();

    expect(h.storage.writes, isEmpty);
    expect(h.gateway.availabilityCalls, 0);
    expect(h.gateway.requestCalls, 0);
  });
}

class _Harness {
  _Harness({
    ReviewPromptState? initial,
    bool supported = true,
    bool failReads = false,
  }) {
    storage = _FakeStorage(initial ?? _eligibleState(), failReads: failReads);
    gateway = _FakeGateway(supported: supported);
    controller = ReviewPromptController(
      storage: storage,
      gateway: gateway,
      now: () => now,
      foregroundDuration: () => foreground,
    );
    addTearDown(dispose);
  }

  late final _FakeStorage storage;
  late final _FakeGateway gateway;
  late final ReviewPromptController controller;
  DateTime now = _today;
  Duration foreground = const Duration(minutes: 2);
  bool _disposed = false;

  Future<void> maybeRequest() =>
      controller.maybeRequest(canPresent: () => true);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.dispose();
  }
}

class _FakeStorage implements ReviewPromptStorage {
  _FakeStorage(this.state, {this.failReads = false});

  ReviewPromptState state;
  final bool failReads;
  bool failWrites = false;
  final List<ReviewPromptState> writes = [];

  @override
  ReviewPromptState read() {
    if (failReads) throw StateError('Cannot read local storage');
    return state;
  }

  @override
  Future<void> write(ReviewPromptState value) async {
    writes.add(value);
    if (failWrites) throw StateError('Cannot write local storage');
    state = value;
  }
}

class _FakeGateway implements ReviewGateway {
  _FakeGateway({required this.supported});

  final bool supported;
  bool available = true;
  Object? availabilityError;
  Object? requestError;
  Future<bool>? availabilityResult;
  final availabilityStarted = Completer<void>();
  void Function()? onRequest;
  int availabilityCalls = 0;
  int requestCalls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<bool> isAvailable() async {
    availabilityCalls++;
    if (!availabilityStarted.isCompleted) availabilityStarted.complete();
    final error = availabilityError;
    if (error != null) throw error;
    return availabilityResult == null ? available : await availabilityResult!;
  }

  @override
  Future<void> requestReview() async {
    requestCalls++;
    onRequest?.call();
    final error = requestError;
    if (error != null) throw error;
  }
}
