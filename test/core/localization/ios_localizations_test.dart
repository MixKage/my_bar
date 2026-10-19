import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/localization/app_language.dart';

void main() {
  final languageCodes = AppLanguageX.supportedLocales
      .map(
        (locale) =>
            locale.languageCode == 'zh' ? 'zh-Hans' : locale.languageCode,
      )
      .toSet();

  test('iOS declares every language supported by the Flutter interface', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final localizations = RegExp(
      r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(localizations, isNotNull);
    final declared = RegExp(r'<string>([^<]+)</string>')
        .allMatches(localizations!.group(1)!)
        .map((match) => match.group(1)!)
        .toSet();
    expect(declared, languageCodes);
  });

  for (final code in languageCodes) {
    test('iOS $code includes localized app name and photo permission', () {
      final strings = File('ios/Runner/$code.lproj/InfoPlist.strings');
      expect(strings.existsSync(), isTrue);
      final entries = {
        for (final match in RegExp(
          r'"([^"]+)"\s*=\s*"([^"]+)";',
        ).allMatches(strings.readAsStringSync()))
          match.group(1)!: match.group(2)!,
      };
      expect(entries['CFBundleDisplayName'], isNotEmpty);
      expect(entries['NSPhotoLibraryUsageDescription'], isNotEmpty);
    });
  }
}
