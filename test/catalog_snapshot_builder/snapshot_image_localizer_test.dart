import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/catalog_snapshot_builder/src/snapshot_image_localizer.dart';

void main() {
  test('downloads remote images and rewrites snapshot paths', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
    });

    server.listen((request) async {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(_tinyPngBytes);
      await request.response.close();
    });

    final imageUrl = 'http://${server.address.host}:${server.port}/image.png';
    final snapshotMap = <String, dynamic>{
      'metadata': <String, dynamic>{},
      'ingredients': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'gin',
          'name': 'Gin',
          'image': imageUrl,
          'imageUrl': imageUrl,
        },
      ],
      'cocktails': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'gin_tonic',
          'name': 'Gin Tonic',
          'image': imageUrl,
          'imageUrl': imageUrl,
        },
      ],
    };

    final tempDir = await Directory.systemTemp.createTemp('catalog_localizer_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final result = await const SnapshotImageLocalizer().localize(
      snapshotMap: snapshotMap,
      outputDirectory: tempDir,
      publicPathPrefix: 'assets/data/catalog_images',
    );

    expect(result.entriesWithRemoteImage, 2);
    expect(result.downloadedFiles, 1);
    expect(result.rewrittenEntries, 2);
    expect(result.failedDownloads, 0);

    final ingredient = (snapshotMap['ingredients'] as List).single as Map;
    final cocktail = (snapshotMap['cocktails'] as List).single as Map;
    final ingredientImage = ingredient['image'] as String;
    final cocktailImage = cocktail['image'] as String;
    expect(ingredientImage.startsWith('assets/data/catalog_images/'), isTrue);
    expect(cocktailImage, ingredientImage);
    expect(ingredient['remoteImageUrl'], imageUrl);

    final localFileName = ingredientImage.split('/').last;
    final localFile = File(
      '${tempDir.path}${Platform.pathSeparator}$localFileName',
    );
    expect(localFile.existsSync(), isTrue);
  });

  test('keeps non-http image paths untouched', () async {
    final snapshotMap = <String, dynamic>{
      'metadata': <String, dynamic>{},
      'ingredients': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'gin',
          'name': 'Gin',
          'image': 'assets/gin.png',
        },
      ],
      'cocktails': <Map<String, dynamic>>[],
    };

    final tempDir = await Directory.systemTemp.createTemp('catalog_localizer_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final result = await const SnapshotImageLocalizer().localize(
      snapshotMap: snapshotMap,
      outputDirectory: tempDir,
      publicPathPrefix: 'assets/data/catalog_images',
    );

    expect(result.entriesWithRemoteImage, 0);
    expect(result.downloadedFiles, 0);
    expect(result.rewrittenEntries, 0);
    final ingredient = (snapshotMap['ingredients'] as List).single as Map;
    expect(ingredient['image'], 'assets/gin.png');
  });
}

final List<int> _tinyPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5L6m8AAAAASUVORK5CYII=',
);
