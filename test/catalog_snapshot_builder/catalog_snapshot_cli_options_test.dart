import 'package:flutter_test/flutter_test.dart';

import '../../tool/catalog_snapshot_builder/src/catalog_snapshot_cli_options.dart';

void main() {
  test('parses defaults', () {
    final options = CatalogSnapshotCliOptions.parse(const <String>[]);

    expect(options.source, 'thecocktaildb');
    expect(options.outputPath, 'assets/data/bar_template.json');
    expect(options.templatePath, 'assets/data/bar_template.json');
    expect(options.seedInputPath, 'assets/data/bar_template.json');
    expect(options.imagesOutputDir, 'assets/data/catalog_images');
    expect(options.imagesPublicPrefix, 'assets/data/catalog_images');
    expect(options.pretty, isFalse);
    expect(options.dryRun, isFalse);
    expect(options.downloadImages, isFalse);
    expect(options.overwriteImages, isFalse);
    expect(options.strict, isFalse);
    expect(options.failOnUnresolvedMapping, isFalse);
  });

  test('parses values and flags', () {
    final options = CatalogSnapshotCliOptions.parse(<String>[
      '--source=seed',
      '--output=build/catalog.json',
      '--template=assets/data/bar_template.json',
      '--seed-input=assets/data/legacy.json',
      '--base-url=https://example.com/catalog.json',
      '--api-key=123',
      '--images-output-dir=build/catalog_images',
      '--images-public-prefix=assets/data/catalog_images',
      '--pretty',
      '--dry-run',
      '--download-images',
      '--overwrite-images',
      '--strict',
      '--fail-on-unresolved-mapping',
      '--print-summary',
    ]);

    expect(options.source, 'seed');
    expect(options.outputPath, 'build/catalog.json');
    expect(options.seedInputPath, 'assets/data/legacy.json');
    expect(options.baseUrl, 'https://example.com/catalog.json');
    expect(options.apiKey, '123');
    expect(options.imagesOutputDir, 'build/catalog_images');
    expect(options.imagesPublicPrefix, 'assets/data/catalog_images');
    expect(options.pretty, isTrue);
    expect(options.dryRun, isTrue);
    expect(options.downloadImages, isTrue);
    expect(options.overwriteImages, isTrue);
    expect(options.strict, isTrue);
    expect(options.failOnUnresolvedMapping, isTrue);
    expect(options.printSummary, isTrue);
  });

  test('throws on unknown option', () {
    expect(
      () => CatalogSnapshotCliOptions.parse(const <String>['--unknown=1']),
      throwsFormatException,
    );
  });
}
