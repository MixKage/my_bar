import 'dart:ui';

enum AppLanguage { system, russian, english }

extension AppLanguageX on AppLanguage {
  String get storageValue {
    switch (this) {
      case AppLanguage.system:
        return 'system';
      case AppLanguage.russian:
        return 'ru';
      case AppLanguage.english:
        return 'en';
    }
  }

  Locale? get locale {
    switch (this) {
      case AppLanguage.system:
        return null;
      case AppLanguage.russian:
        return const Locale('ru');
      case AppLanguage.english:
        return const Locale('en');
    }
  }

  static AppLanguage fromStorage(String? rawValue) {
    final normalized = (rawValue ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'ru':
        return AppLanguage.russian;
      case 'en':
        return AppLanguage.english;
      case 'system':
      default:
        return AppLanguage.system;
    }
  }

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
  ];
}
