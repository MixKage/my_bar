import 'dart:convert';
import 'dart:io';

import 'package:my_bar/features/bar/data/bar_catalog_json_codec.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';

import 'src/catalog_import_source.dart';
import 'src/catalog_snapshot_builder.dart';
import 'src/catalog_snapshot_cli_options.dart';
import 'src/snapshot_image_localizer.dart';

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
    final result = await builder.build(
      payload: payload,
      mappingTemplateCatalog: templateCatalog,
      options: CatalogSnapshotBuilderOptions(
        strict: options.strict,
        failOnUnresolvedMapping: options.failOnUnresolvedMapping,
        pretty: options.pretty,
      ),
    );

    final snapshotMap = Map<String, dynamic>.from(result.snapshotMap);
    String? imageSummary;
    if (options.downloadImages) {
      if (options.dryRun) {
        imageSummary = 'Image download skipped in dry-run mode.';
      } else {
        final localizer = SnapshotImageLocalizer();
        final localizeResult = await localizer.localize(
          snapshotMap: snapshotMap,
          outputDirectory: Directory(options.imagesOutputDir),
          publicPathPrefix: options.imagesPublicPrefix,
          overwriteExisting: options.overwriteImages,
        );
        final metadata = _ensureMetadataMap(snapshotMap);
        metadata['imageLocalization'] = localizeResult.toJson();
        imageSummary = localizeResult.prettyPrint();
      }
    }

    if (options.printSummary || options.dryRun || imageSummary != null) {
      stdout.writeln(
        '\nSnapshot build summary:\n${result.summary.prettyPrint()}',
      );
      if (imageSummary != null && imageSummary.isNotEmpty) {
        stdout.writeln('\nImage localization:\n$imageSummary');
      }
    }

    if (options.dryRun) {
      stdout.writeln('\nDry run completed. Output file was not written.');
      return;
    }

    final snapshotJson = options.pretty
        ? const JsonEncoder.withIndent('  ').convert(snapshotMap)
        : jsonEncode(snapshotMap);

    final outputFile = File(options.outputPath);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(snapshotJson, flush: true);
    stdout.writeln('\nSnapshot written to: ${outputFile.path}');
  } catch (error, stackTrace) {
    stderr.writeln('Snapshot build failed: $error');
    if (error is! FormatException && error is! StateError) {
      stderr.writeln(stackTrace);
    }
    exitCode = 2;
  }
}

Map<String, dynamic> _ensureMetadataMap(Map<String, dynamic> snapshotMap) {
  final rawMetadata = snapshotMap['metadata'];
  if (rawMetadata is Map<String, dynamic>) {
    return rawMetadata;
  }
  if (rawMetadata is Map) {
    final casted = rawMetadata.cast<String, dynamic>();
    snapshotMap['metadata'] = casted;
    return casted;
  }
  final created = <String, dynamic>{};
  snapshotMap['metadata'] = created;
  return created;
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
