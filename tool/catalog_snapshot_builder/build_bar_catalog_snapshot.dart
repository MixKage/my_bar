import 'dart:io';

import 'package:my_bar/features/bar/data/bar_catalog_json_codec.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';

import 'src/catalog_import_source.dart';
import 'src/catalog_snapshot_builder.dart';
import 'src/catalog_snapshot_cli_options.dart';

Future<void> main(List<String> args) async {
  try {
    final options = CatalogSnapshotCliOptions.parse(args);
    if (options.showHelp) {
      stdout.write(kCatalogSnapshotCliHelp);
      return;
    }

    final templateCatalog = _loadTemplateCatalog(options.templatePath);
    final source = _buildSource(options);

    stdout.writeln('Fetching source data from "${source.sourceName}"...');
    final payload = await source.fetch();

    final builder = CatalogSnapshotBuilder();
    final result = builder.build(
      payload: payload,
      mappingTemplateCatalog: templateCatalog,
      options: CatalogSnapshotBuilderOptions(
        strict: options.strict,
        failOnUnresolvedMapping: options.failOnUnresolvedMapping,
        pretty: options.pretty,
      ),
    );

    if (options.printSummary || options.dryRun) {
      stdout.writeln(
        '\nSnapshot build summary:\n${result.summary.prettyPrint()}',
      );
    }

    if (options.dryRun) {
      stdout.writeln('\nDry run completed. Output file was not written.');
      return;
    }

    final outputFile = File(options.outputPath);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(result.snapshotJson, flush: true);
    stdout.writeln('\nSnapshot written to: ${outputFile.path}');
  } catch (error, stackTrace) {
    stderr.writeln('Snapshot build failed: $error');
    if (error is! FormatException && error is! StateError) {
      stderr.writeln(stackTrace);
    }
    exitCode = 2;
  }
}

CatalogImportSource _buildSource(CatalogSnapshotCliOptions options) {
  switch (options.source) {
    case 'thecocktaildb':
      return TheCocktailDbCatalogImportSource(
        baseUrl: options.baseUrl,
        apiKey: options.apiKey,
      );
    case 'seed':
      return SeedJsonCatalogImportSource(inputPath: options.seedInputPath);
    case 'http-json':
      final uri = Uri.tryParse(options.baseUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw const FormatException(
          'Option "--base-url" must be a valid URL for --source=http-json.',
        );
      }
      return HttpJsonCatalogImportSource(url: uri);
    default:
      throw FormatException(
        'Unsupported source "${options.source}". Supported: thecocktaildb, seed, http-json.',
      );
  }
}

BarCatalog _loadTemplateCatalog(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw FileSystemException(
      'Template catalog file does not exist',
      file.absolute.path,
    );
  }
  final codec = const BarCatalogJsonCodec();
  return codec.decode(file.readAsStringSync());
}
