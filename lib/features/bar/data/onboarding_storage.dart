import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingStorage {
  bool get isCompleted;
  Future<void> complete();
}

class SharedPreferencesOnboardingStorage implements OnboardingStorage {
  const SharedPreferencesOnboardingStorage(this._preferences);
  static const completedKey = 'bar_onboarding_completed';
  final SharedPreferences _preferences;

  @override
  bool get isCompleted => _preferences.getBool(completedKey) ?? false;

  @override
  Future<void> complete() async {
    if (!await _preferences.setBool(completedKey, true)) {
      throw StateError('Unable to persist onboarding completion');
    }
  }
}

class InMemoryOnboardingStorage implements OnboardingStorage {
  InMemoryOnboardingStorage({bool completed = false}) : _completed = completed;
  bool _completed;
  @override
  bool get isCompleted => _completed;
  @override
  Future<void> complete() async => _completed = true;
}
