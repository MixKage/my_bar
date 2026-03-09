import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/search/app_search_query.dart';

void main() {
  group('AppSearchQuery', () {
    test('matches latin source by cyrillic query with hard mapping', () {
      final query = AppSearchQuery('Самбука');

      expect(query.matches('Sambuca'), isTrue);
    });

    test('matches cyrillic source by latin query', () {
      final query = AppSearchQuery('sambuca');

      expect(query.matches('Самбука'), isTrue);
    });

    test('matches transliterated source without dictionary word', () {
      final query = AppSearchQuery('Текила');

      expect(query.matches('tequila silver'), isTrue);
    });

    test('matches typo using fuzzy search', () {
      final query = AppSearchQuery('sambka');

      expect(query.matches('sambuca'), isTrue);
    });

    test('matches whiskey variants from hard mapping', () {
      final query = AppSearchQuery('виски');

      expect(query.matches('single malt whisky'), isTrue);
      expect(query.matches('bourbon whiskey'), isTrue);
    });

    test('does not match unrelated source', () {
      final query = AppSearchQuery('самбука');

      expect(query.matches('campari bitter'), isFalse);
    });
  });
}
