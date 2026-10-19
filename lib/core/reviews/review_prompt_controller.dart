import 'package:flutter/foundation.dart';

import 'native_review_gateway.dart';
import 'review_prompt_policy.dart';
import 'review_prompt_storage.dart';

/// Local scheduling only: neither a completed request nor its return value
/// reveals whether a person saw the store dialog or left a review.
class ReviewPromptController extends ChangeNotifier {
  ReviewPromptController({
    required ReviewPromptStorage storage,
    required ReviewGateway gateway,
    DateTime Function()? now,
    Duration Function()? foregroundDuration,
    ReviewPromptPolicy policy = const ReviewPromptPolicy(),
  }) : _storage = storage,
       _gateway = gateway,
       _now = now ?? DateTime.now,
       _foregroundDuration = foregroundDuration,
       _policy = policy {
    try {
      _state = _storage.read();
    } catch (_) {
      _storageHealthy = false;
    }
  }

  final ReviewPromptStorage _storage;
  final ReviewGateway _gateway;
  final DateTime Function() _now;
  final Duration Function()? _foregroundDuration;
  final ReviewPromptPolicy _policy;
  final Stopwatch _foregroundClock = Stopwatch();
  ReviewPromptState _state = const ReviewPromptState.empty();
  Future<void> _pending = Future<void>.value();
  bool _active = false;
  bool _checkedThisSession = false;
  bool _storageHealthy = true;
  bool _disposed = false;
  int _session = 0;

  Future<void> startSession() {
    if (_disposed || _active || !_gateway.isSupported) {
      return Future<void>.value();
    }
    _active = true;
    final session = ++_session;
    _checkedThisSession = false;
    _foregroundClock
      ..reset()
      ..start();
    return _serialize(() async {
      if (_active && session == _session) {
        await _save(_state.recordUsage(_now()));
      }
    });
  }

  void stopSession() {
    _active = false;
    _session++;
    _foregroundClock
      ..stop()
      ..reset();
  }

  /// Call only after a meaningful action has actually been saved successfully.
  Future<void> recordSuccessfulAction() {
    final session = _session;
    return _serialize(() async {
      if (!_active || session != _session || !_gateway.isSupported) return;
      await _save(_state.recordSuccessfulAction(_now()));
      if (_active && session == _session && !_disposed && _storageHealthy) {
        notifyListeners();
      }
    });
  }

  Future<void> maybeRequest({required bool Function() canPresent}) {
    final session = _session;
    return _serialize(() async {
      if (_checkedThisSession ||
          session != _session ||
          !_canRequest(canPresent)) {
        return;
      }
      _checkedThisSession = true;
      if (!await _gateway.isAvailable() ||
          session != _session ||
          !_canRequest(canPresent)) {
        return;
      }

      // Persist BEFORE calling the store, even when it might suppress its UI.
      // A failed write must never result in an unthrottled native request.
      await _save(_state.recordAttempt(_now()));
      if (!_active || _disposed || session != _session || !canPresent()) return;
      await _gateway.requestReview();
    });
  }

  bool _canRequest(bool Function() canPresent) =>
      !_disposed &&
      _active &&
      _storageHealthy &&
      _gateway.isSupported &&
      canPresent() &&
      _policy.isEligible(
        _state,
        now: _now(),
        foregroundDuration:
            _foregroundDuration?.call() ?? _foregroundClock.elapsed,
      );

  Future<void> _save(ReviewPromptState state) async {
    try {
      await _storage.write(state);
      _state = state;
    } catch (_) {
      _storageHealthy = false;
      rethrow;
    }
  }

  Future<void> _serialize(Future<void> Function() operation) {
    _pending = _pending.then((_) async {
      if (_disposed || !_storageHealthy) return;
      try {
        await operation();
      } catch (_) {
        // Review integration must never interrupt ordinary application use.
        // Storage failures disable further attempts for this controller.
      }
    });
    return _pending;
  }

  @override
  void dispose() {
    _disposed = true;
    stopSession();
    super.dispose();
  }
}
