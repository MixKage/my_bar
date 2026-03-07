import 'dart:io';
import 'dart:typed_data';

class SnapshotImageLocalizerResult {
  const SnapshotImageLocalizerResult({
    required this.entriesWithRemoteImage,
    required this.downloadedFiles,
    required this.reusedFiles,
    required this.failedDownloads,
    required this.rewrittenEntries,
  });

  final int entriesWithRemoteImage;
  final int downloadedFiles;
  final int reusedFiles;
  final int failedDownloads;
  final int rewrittenEntries;

  Map<String, Object> toJson() {
    return <String, Object>{
      'entriesWithRemoteImage': entriesWithRemoteImage,
      'downloadedFiles': downloadedFiles,
      'reusedFiles': reusedFiles,
      'failedDownloads': failedDownloads,
      'rewrittenEntries': rewrittenEntries,
    };
  }

  String prettyPrint() {
    return <String>[
      'Images with remote URL: $entriesWithRemoteImage',
      'Downloaded files: $downloadedFiles',
      'Reused existing files: $reusedFiles',
      'Failed downloads: $failedDownloads',
      'Entries rewritten to local path: $rewrittenEntries',
    ].join('\n');
  }
}

class SnapshotImageLocalizer {
  const SnapshotImageLocalizer({
    this.timeout = const Duration(seconds: 18),
    this.maxConcurrentDownloads = 8,
  }) : assert(maxConcurrentDownloads > 0);

  final Duration timeout;
  final int maxConcurrentDownloads;

  Future<SnapshotImageLocalizerResult> localize({
    required Map<String, dynamic> snapshotMap,
    required Directory outputDirectory,
    required String publicPathPrefix,
    bool overwriteExisting = false,
  }) async {
    final targets = _collectTargets(snapshotMap);
    final jobsByUrl = <String, _ImageJob>{};
    for (final target in targets) {
      jobsByUrl
          .putIfAbsent(
            target.remoteImageUrl,
            () => _ImageJob(remoteImageUrl: target.remoteImageUrl),
          )
          .targets
          .add(target);
    }

    outputDirectory.createSync(recursive: true);
    final normalizedPrefix = _normalizePrefix(publicPathPrefix);

    var downloaded = 0;
    var reused = 0;
    var failed = 0;
    var rewritten = 0;

    final jobs = jobsByUrl.values.toList(growable: false);
    for (
      var offset = 0;
      offset < jobs.length;
      offset += maxConcurrentDownloads
    ) {
      final chunk = jobs.skip(offset).take(maxConcurrentDownloads);
      final chunkResults = await Future.wait<_JobResult>(
        chunk.map(
          (job) => _processJob(
            job,
            outputDirectory: outputDirectory,
            publicPathPrefix: normalizedPrefix,
            overwriteExisting: overwriteExisting,
          ),
        ),
      );

      for (final result in chunkResults) {
        switch (result.status) {
          case _JobStatus.downloaded:
            downloaded++;
          case _JobStatus.reused:
            reused++;
          case _JobStatus.failed:
            failed++;
        }
        if (result.localPublicPath == null) {
          continue;
        }
        for (final target in result.job.targets) {
          target.entry['remoteImageUrl'] = target.remoteImageUrl;
          target.entry['image'] = result.localPublicPath;
          target.entry['imageUrl'] = result.localPublicPath;
          rewritten++;
        }
      }
    }

    return SnapshotImageLocalizerResult(
      entriesWithRemoteImage: targets.length,
      downloadedFiles: downloaded,
      reusedFiles: reused,
      failedDownloads: failed,
      rewrittenEntries: rewritten,
    );
  }

  List<_ImageTarget> _collectTargets(Map<String, dynamic> snapshotMap) {
    final targets = <_ImageTarget>[];
    for (final section in const <String>['ingredients', 'cocktails']) {
      final rawList = snapshotMap[section];
      if (rawList is! List) {
        continue;
      }
      for (final item in rawList) {
        final entry = _asMutableMap(item);
        if (entry == null) {
          continue;
        }
        final remoteImageUrl = _firstRemoteImageUrl(entry);
        if (remoteImageUrl.isEmpty) {
          continue;
        }
        targets.add(_ImageTarget(entry: entry, remoteImageUrl: remoteImageUrl));
      }
    }
    return targets;
  }

  Map<String, dynamic>? _asMutableMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }

  String _firstRemoteImageUrl(Map<String, dynamic> entry) {
    final candidates = <Object?>[
      entry['image'],
      entry['imageUrl'],
      entry['remoteImageUrl'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (_isRemoteHttpUrl(value)) {
        return value;
      }
    }
    return '';
  }

  bool _isRemoteHttpUrl(String value) {
    if (value.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<_JobResult> _processJob(
    _ImageJob job, {
    required Directory outputDirectory,
    required String publicPathPrefix,
    required bool overwriteExisting,
  }) async {
    final uri = Uri.tryParse(job.remoteImageUrl);
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      return _JobResult(job: job, status: _JobStatus.failed);
    }

    final hash = _fnv1a32(job.remoteImageUrl).toRadixString(16).padLeft(8, '0');
    if (!overwriteExisting) {
      final existingFileName = _findExistingFileName(hash, outputDirectory);
      if (existingFileName != null) {
        return _JobResult(
          job: job,
          status: _JobStatus.reused,
          localPublicPath: '$publicPathPrefix/$existingFileName',
        );
      }
    }

    final extensionFromPath = _extensionFromPath(uri.path);

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _JobResult(job: job, status: _JobStatus.failed);
      }
      final bytes = await _readResponseBytes(response).timeout(timeout);
      if (bytes.isEmpty) {
        return _JobResult(job: job, status: _JobStatus.failed);
      }

      final contentType = response.headers.contentType?.mimeType ?? '';
      final resolvedExtension = extensionFromPath.isNotEmpty
          ? extensionFromPath
          : _extensionFromContentType(contentType);
      final fileName = 'img_$hash$resolvedExtension';
      final file = File(
        '${outputDirectory.path}${Platform.pathSeparator}$fileName',
      );
      await file.writeAsBytes(bytes, flush: true);

      return _JobResult(
        job: job,
        status: _JobStatus.downloaded,
        localPublicPath: '$publicPathPrefix/$fileName',
      );
    } catch (_) {
      return _JobResult(job: job, status: _JobStatus.failed);
    } finally {
      client.close(force: true);
    }
  }
}

Future<Uint8List> _readResponseBytes(HttpClientResponse response) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

String _normalizePrefix(String value) {
  final normalized = value
      .trim()
      .replaceAll('\\', '/')
      .replaceAll(RegExp('/+'), '/')
      .replaceAll(RegExp(r'^/+'), '')
      .replaceAll(RegExp(r'/+$'), '');
  return normalized.isEmpty ? 'assets/data/catalog_images' : normalized;
}

String _extensionFromPath(String path) {
  final lower = path.toLowerCase();
  for (final extension in _knownImageExtensions) {
    if (lower.endsWith(extension)) {
      return extension;
    }
  }
  return '';
}

String _extensionFromContentType(String contentType) {
  final normalized = contentType.trim().toLowerCase();
  return _imageExtensionByContentType[normalized] ?? '.jpg';
}

int _fnv1a32(String source) {
  var hash = 0x811C9DC5;
  for (final codeUnit in source.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

String? _findExistingFileName(String hash, Directory outputDirectory) {
  final candidates = <String>[
    for (final extension in _knownImageExtensions) 'img_$hash$extension',
    'img_$hash',
  ];
  for (final fileName in candidates) {
    final file = File(
      '${outputDirectory.path}${Platform.pathSeparator}$fileName',
    );
    if (file.existsSync()) {
      return fileName;
    }
  }
  return null;
}

class _ImageTarget {
  const _ImageTarget({required this.entry, required this.remoteImageUrl});

  final Map<String, dynamic> entry;
  final String remoteImageUrl;
}

class _ImageJob {
  _ImageJob({required this.remoteImageUrl});

  final String remoteImageUrl;
  final List<_ImageTarget> targets = <_ImageTarget>[];
}

class _JobResult {
  const _JobResult({
    required this.job,
    required this.status,
    this.localPublicPath,
  });

  final _ImageJob job;
  final _JobStatus status;
  final String? localPublicPath;
}

enum _JobStatus { downloaded, reused, failed }

const List<String> _knownImageExtensions = <String>[
  '.png',
  '.jpg',
  '.jpeg',
  '.webp',
  '.gif',
];

const Map<String, String> _imageExtensionByContentType = <String, String>{
  'image/png': '.png',
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/webp': '.webp',
  'image/gif': '.gif',
};
