import 'dart:ui';

enum AppLanguage {
  system,
  russian,
  english,
  spanish,
  portuguese,
  german,
  french,
  italian,
  turkish,
  chinese,
  japanese,
  korean,
  hindi,
  arabic,
}

extension AppLanguageX on AppLanguage {
  String get storageValue => switch (this) {
    AppLanguage.system => 'system',
    AppLanguage.russian => 'ru',
    AppLanguage.english => 'en',
    AppLanguage.spanish => 'es',
    AppLanguage.portuguese => 'pt',
    AppLanguage.german => 'de',
    AppLanguage.french => 'fr',
    AppLanguage.italian => 'it',
    AppLanguage.turkish => 'tr',
    AppLanguage.chinese => 'zh',
    AppLanguage.japanese => 'ja',
    AppLanguage.korean => 'ko',
    AppLanguage.hindi => 'hi',
    AppLanguage.arabic => 'ar',
  };

  Locale? get locale =>
      this == AppLanguage.system ? null : Locale(storageValue);

  String get nativeName => switch (this) {
    AppLanguage.system => 'System',
    AppLanguage.russian => 'Русский',
    AppLanguage.english => 'English',
    AppLanguage.spanish => 'Español',
    AppLanguage.portuguese => 'Português',
    AppLanguage.german => 'Deutsch',
    AppLanguage.french => 'Français',
    AppLanguage.italian => 'Italiano',
    AppLanguage.turkish => 'Türkçe',
    AppLanguage.chinese => '简体中文',
    AppLanguage.japanese => '日本語',
    AppLanguage.korean => '한국어',
    AppLanguage.hindi => 'हिन्दी',
    AppLanguage.arabic => 'العربية',
  };

  String get englishName => switch (this) {
    AppLanguage.system => 'System',
    AppLanguage.russian => 'Russian',
    AppLanguage.english => 'English',
    AppLanguage.spanish => 'Spanish',
    AppLanguage.portuguese => 'Portuguese',
    AppLanguage.german => 'German',
    AppLanguage.french => 'French',
    AppLanguage.italian => 'Italian',
    AppLanguage.turkish => 'Turkish',
    AppLanguage.chinese => 'Chinese (Simplified)',
    AppLanguage.japanese => 'Japanese',
    AppLanguage.korean => 'Korean',
    AppLanguage.hindi => 'Hindi',
    AppLanguage.arabic => 'Arabic',
  };

  static AppLanguage fromStorage(String? rawValue) {
    final normalized = (rawValue ?? '')
        .trim()
        .toLowerCase()
        .split(RegExp('[-_]'))
        .first;
    return AppLanguage.values.firstWhere(
      (language) => language.storageValue == normalized,
      orElse: () => AppLanguage.system,
    );
  }

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('es'),
    Locale('pt'),
    Locale('de'),
    Locale('fr'),
    Locale('it'),
    Locale('tr'),
    Locale('zh'),
    Locale('ja'),
    Locale('ko'),
    Locale('hi'),
    Locale('ar'),
  ];

  /// Regional variants use their language; unsupported devices default to English.
  static Locale resolveLocale(Iterable<Locale>? preferredLocales) {
    for (final preferred in preferredLocales ?? const <Locale>[]) {
      for (final supported in supportedLocales) {
        if (preferred.languageCode.toLowerCase() == supported.languageCode) {
          return supported;
        }
      }
    }
    return const Locale('en');
  }
}
