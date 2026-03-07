class CatalogSnapshotCliOptions {
  const CatalogSnapshotCliOptions({
    required this.source,
    required this.outputPath,
    required this.templatePath,
    required this.seedInputPath,
    required this.baseUrl,
    required this.apiKey,
    required this.pretty,
    required this.dryRun,
    required this.strict,
    required this.failOnUnresolvedMapping,
    required this.printSummary,
    required this.showHelp,
  });

  factory CatalogSnapshotCliOptions.parse(List<String> args) {
    final values = <String, String>{};
    final flags = <String>{};

    for (final arg in args) {
      if (!arg.startsWith('--')) {
        throw FormatException('Unsupported argument: "$arg"');
      }
      final payload = arg.substring(2);
      if (payload.contains('=')) {
        final parts = payload.split('=');
        if (parts.length < 2 || parts.first.trim().isEmpty) {
          throw FormatException('Invalid argument format: "$arg"');
        }
        final key = parts.first.trim();
        final value = parts.sublist(1).join('=').trim();
        values[key] = value;
      } else {
        flags.add(payload.trim());
      }
    }

    const supportedValueKeys = <String>{
      'source',
      'output',
      'template',
      'seed-input',
      'base-url',
      'api-key',
    };
    const supportedFlags = <String>{
      'pretty',
      'dry-run',
      'strict',
      'fail-on-unresolved-mapping',
      'print-summary',
      'help',
    };

    for (final key in values.keys) {
      if (!supportedValueKeys.contains(key)) {
        throw FormatException('Unknown option: "--$key"');
      }
    }
    for (final flag in flags) {
      if (!supportedFlags.contains(flag)) {
        throw FormatException('Unknown flag: "--$flag"');
      }
    }

    return CatalogSnapshotCliOptions(
      source: (values['source'] ?? 'thecocktaildb').trim().toLowerCase(),
      outputPath: (values['output'] ?? 'assets/data/bar_template.json').trim(),
      templatePath: (values['template'] ?? 'assets/data/bar_template.json')
          .trim(),
      seedInputPath: (values['seed-input'] ?? 'assets/data/bar_template.json')
          .trim(),
      baseUrl: (values['base-url'] ?? '').trim(),
      apiKey: (values['api-key'] ?? '1').trim(),
      pretty: flags.contains('pretty'),
      dryRun: flags.contains('dry-run'),
      strict: flags.contains('strict'),
      failOnUnresolvedMapping: flags.contains('fail-on-unresolved-mapping'),
      printSummary: flags.contains('print-summary'),
      showHelp: flags.contains('help'),
    );
  }

  final String source;
  final String outputPath;
  final String templatePath;
  final String seedInputPath;
  final String baseUrl;
  final String apiKey;
  final bool pretty;
  final bool dryRun;
  final bool strict;
  final bool failOnUnresolvedMapping;
  final bool printSummary;
  final bool showHelp;
}

const String kCatalogSnapshotCliHelp = '''
Build bar catalog snapshot JSON for My Bar.

Usage:
  dart run tool/catalog_snapshot_builder/build_bar_catalog_snapshot.dart [options]

Options:
  --source=<thecocktaildb|seed|http-json>  Import source (default: thecocktaildb)
  --output=<path>                          Output snapshot path (default: assets/data/bar_template.json)
  --template=<path>                        Template JSON path for canonical mapping baseline
  --seed-input=<path>                      Input path for --source=seed
  --base-url=<url>                         Base URL for source (TheCocktailDB or http-json)
  --api-key=<key>                          API key for TheCocktailDB (default: 1)
  --pretty                                 Pretty-print output JSON
  --dry-run                                Run pipeline without writing output
  --strict                                 Drop cocktails with unresolved ingredient references
  --fail-on-unresolved-mapping             Exit with error if unresolved ingredient mappings exist
  --print-summary                          Print import/validation summary
  --help                                   Show this help message
''';
