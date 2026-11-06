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

    test('recognizes missing letters and transposed letters', () {
      expect(AppSearchQuery('ornage').matches('Orange'), isTrue);
      expect(AppSearchQuery('апелсин').matches('Апельсин'), isTrue);
      expect(AppSearchQuery('mojto').matches('Mojito'), isTrue);
    });

    test('folds accents without treating punctuation as part of words', () {
      expect(AppSearchQuery('pina colada').matches('Piña Colada'), isTrue);
      expect(AppSearchQuery("John's Collins").matches('John Collins'), isTrue);
      expect(AppSearchQuery('gluhwein').matches('Glühwein'), isTrue);
      expect(AppSearchQuery('creme brulee').matches('Crème brûlée'), isTrue);
      expect(AppSearchQuery('visne').matches('Vişne'), isTrue);
      expect(AppSearchQuery('олива').matches('Олива'), isTrue);
      expect(AppSearchQuery('трипл сек').matches('Трипл-сек'), isTrue);
    });

    for (final (query, name, unrelated) in [
      ('橙子', '鲜橙子', '柠檬'),
      ('モヒート', 'モヒート', 'ジントニック'),
      ('오렌지', '오렌지 주스', '사과 주스'),
      ('मोजिटो', 'मोजिटो', 'संतरा'),
      ('برتقال', 'بُرتُقال', 'تفاح'),
    ]) {
      test('searches native script for $query', () {
        final search = AppSearchQuery(query);
        expect(search.isEmpty, isFalse);
        expect(search.matches(name), isTrue);
        expect(search.matches(unrelated), isFalse);
      });
    }

    test('requires all words, including when a synonym is used', () {
      expect(
        AppSearchQuery('апельсиновый сок').matches('Яблочный сок'),
        isFalse,
      );
      expect(AppSearchQuery('whisky sour').matches('Whiskey Sour'), isTrue);
      expect(AppSearchQuery('whisky sour').matches('Whisky Mac'), isFalse);
      expect(AppSearchQuery('whisky sour').matches('Pisco Sour'), isFalse);
      expect(AppSearchQuery('gin ginger').matches('Ginger Ale'), isFalse);
      expect(AppSearchQuery('gin ginger').matches('Gin and Ginger'), isTrue);
    });

    test('can match terms across fields, but cannot drop one of them', () {
      const document = AppSearchDocument(
        name: 'Orange Highball',
        related: ['soda water', 'gin'],
        details: ['Collins glass'],
      );
      expect(AppSearchQuery('orange soda').score(document), greaterThan(0));
      expect(AppSearchQuery('orange apple').score(document), 0);
      expect(AppSearchQuery('orange collns').score(document), 0);
    });

    test('ranks exact name before alias, prefix and typo', () {
      const exact = AppSearchDocument(name: 'Апельсин');
      const alias = AppSearchDocument(name: 'Orange', aliases: ['Апельсин']);
      const prefix = AppSearchDocument(name: 'Апельсиновый сок');
      const typo = AppSearchDocument(name: 'Апелсин');
      final ranked = AppSearchQuery(
        'апельсин',
      ).rank([prefix, typo, alias, exact], (document) => document);
      expect(ranked, [exact, alias, prefix, typo]);
    });

    test('preserves source order on ties and an empty query', () {
      final documents = ['z Mojito', 'a Mojito', 'Negroni'];
      AppSearchDocument describe(String name) => AppSearchDocument(name: name);
      expect(
        AppSearchQuery('mojito').rank(documents, describe),
        documents.take(2),
      );
      expect(AppSearchQuery('  !  ').rank(documents, describe), documents);
    });
  });
}
