import 'app_translations.g.dart';

export 'app_translations.g.dart' show appTranslations;

/// All translations are bundled. No network or paid translation service is used
/// while the app is running. English is the fallback for unsupported locales.
String translateAppText(String languageCode, String english) {
  final dictionary = appTranslations[languageCode.toLowerCase()];
  if (dictionary == null) return english;
  final exact = dictionary[english];
  if (exact != null) return exact;
  for (final template in _templates) {
    final match = template.pattern.firstMatch(english);
    if (match == null) continue;
    final translated = dictionary[template.source];
    if (translated == null) continue;
    return translated.replaceAllMapped(_placeholder, (token) {
      final index = int.parse(token.group(1)!);
      return match.group(index + 1) ?? '';
    });
  }
  return english;
}

final _placeholder = RegExp(r'\{(\d+)\}');

final List<_TranslationTemplate> _templates =
    (appTranslations.values.first.keys
            .where((key) => _placeholder.hasMatch(key))
            .toList()
          ..sort(
            (a, b) => b
                .replaceAll(_placeholder, '')
                .length
                .compareTo(a.replaceAll(_placeholder, '').length),
          ))
        .map(_TranslationTemplate.new)
        .toList(growable: false);

class _TranslationTemplate {
  _TranslationTemplate(this.source)
    : pattern = RegExp(
        '^${source.split(_placeholder).map(RegExp.escape).join('(.*?)')}\$',
        dotAll: true,
      );

  final String source;
  final RegExp pattern;
}
