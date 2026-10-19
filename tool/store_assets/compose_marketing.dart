// Offline, localized store screenshot composition. The app interface comes
// exclusively from capture_ui.dart; this tool never recreates or edits that UI.
//
// Invoked by store_assets.py after validating the local inputs. Normal test runs
// skip this expensive tooling test; explicitly opt in with --run-skipped.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _renderer = 'flutter-marketing-compositor';
const _headlineColor = Color(0xFF97F6FF);
const _subtitleColor = Color(0xFFF4EDFF);

void main() {
  final outputPath = Platform.environment['STORE_ASSET_OUTPUT'];
  test('explicit marketing selection can opt into a disabled profile', () {
    const profiles = [
      {'id': 'default', 'enabled': true},
      {'id': 'optional', 'enabled': false},
    ];
    expect(_select(profiles, null, 'id').single['id'], 'default');
    expect(_select(profiles, '', 'id').single['id'], 'default');
    expect(_select(profiles, 'optional', 'id').single['id'], 'optional');
    expect(
      _select(profiles, 'default,optional', 'id').map((item) => item['id']),
      ['default', 'optional'],
    );
    expect(
      () => _select(profiles, 'missing', 'id'),
      throwsA(isA<FormatException>()),
    );
  });
  test('atomic metadata save replaces complete contents without leftovers', () {
    final directory = Directory.systemTemp.createTempSync('my-bar-atomic-');
    final target = File('${directory.path}/manifest.json');
    try {
      _atomicWriteString(target, '{"revision":1}\n');
      expect(target.readAsStringSync(), '{"revision":1}\n');
      _atomicWriteString(target, '{"revision":2,"complete":true}\n');
      expect(target.readAsStringSync(), '{"revision":2,"complete":true}\n');
      expect(directory.listSync().map((file) => file.path), [target.path]);
    } finally {
      if (target.existsSync()) target.deleteSync();
      directory.deleteSync();
    }
  });
  test(
    'failed atomic rename preserves the destination and cleans its temp',
    () {
      final directory = Directory.systemTemp.createTempSync('my-bar-atomic-');
      final occupied = Directory('${directory.path}/occupied')..createSync();
      final marker = File('${occupied.path}/keep.txt')
        ..writeAsStringSync('existing data');
      try {
        expect(
          () => _atomicWriteString(File(occupied.path), 'replacement'),
          throwsA(isA<FileSystemException>()),
        );
        expect(marker.readAsStringSync(), 'existing data');
        expect(directory.listSync().map((file) => file.path), [occupied.path]);
      } finally {
        marker.deleteSync();
        occupied.deleteSync();
        directory.deleteSync();
      }
    },
  );
  testWidgets(
    'all localized captions fit every target canvas without obscuring the UI',
    (tester) async {
      await tester.runAsync(() async {
        final configFile = File(
          Platform.environment['STORE_ASSET_CONFIG'] ??
              'tool/store_assets/config.json',
        ).absolute;
        final config = _readObject(configFile);
        final copyFile = File('${configFile.parent.path}/marketing_copy.json');
        final copy = _readObject(copyFile);
        final families = await _loadOfflineFonts(config, configFile.parent);
        var checked = 0;
        // Validate all locales and devices even when output is a small preview.
        // This helper-only test does not decode, draw or write any images.
        for (final language in config['languages'] as List) {
          if (language['enabled'] == false) continue;
          final code = language['code'] as String;
          for (final device in config['devices'] as List) {
            if (device['enabled'] == false) continue;
            final dpr = (device['pixelRatio'] as num).toDouble();
            final sourceSize = Size(
              (device['width'] as num).toDouble(),
              (device['height'] as num).toDouble(),
            );
            for (final scene in config['screenshots'] as List) {
              if (scene['enabled'] == false) continue;
              final sceneCopy =
                  (copy['languages'] as Map)[code][scene['id']] as Map;
              final layout = _MarketingLayout(
                size: sourceSize / dpr,
                sourceSize: sourceSize,
                headline: sceneCopy['headline'] as String,
                subtitle: sceneCopy['subtitle'] as String,
                family: _primaryFamily(code),
                fallbackFamilies: families,
                direction: language['direction'] == 'rtl'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                languageCode: code,
                showDeviceFrame: device['platform'] != 'android',
              );
              try {
                expect(layout.title.lineCount, inInclusiveRange(1, 2));
                expect(layout.detail.lineCount, inInclusiveRange(1, 2));
                expect(
                  layout.frameRect.height / layout.size.height,
                  inInclusiveRange(.70, .75),
                );
                expect(
                  layout.screenRect.width / layout.screenRect.height,
                  closeTo(sourceSize.width / sourceSize.height, .000001),
                );
                expect(layout.title.painter.didExceedMaxLines, isFalse);
                expect(layout.detail.painter.didExceedMaxLines, isFalse);
                checked++;
              } finally {
                layout.dispose();
              }
            }
          }
        }
        expect(checked, greaterThan(0));
      });
    },
    skip: outputPath == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  testWidgets(
    'compose localized marketing screenshots around real application captures',
    (tester) async {
      // Engine decoding/encoding and font installation must use real async time,
      // rather than the widget test's deliberately frozen fake clock.
      await tester.runAsync(() async {
        final configFile = File(
          Platform.environment['STORE_ASSET_CONFIG'] ??
              'tool/store_assets/config.json',
        ).absolute;
        final config = _readObject(configFile);
        final output = Directory(outputPath!).absolute;
        final copyFile = File('${configFile.parent.path}/marketing_copy.json');
        final copy = _readObject(copyFile);
        if (config['schemaVersion'] != 1 || copy['schemaVersion'] != 1) {
          throw const FormatException('Unsupported store marketing schema.');
        }
        final languages = _select(
          config['languages'] as List,
          Platform.environment['STORE_ASSET_LANGUAGES'],
          'code',
        );
        final devices = _select(
          config['devices'] as List,
          Platform.environment['STORE_ASSET_DEVICES'],
          'id',
        );
        final scenes = _select(
          config['screenshots'] as List,
          Platform.environment['STORE_ASSET_SCENES'],
          'id',
        );
        final fontFamilies = await _loadOfflineFonts(config, configFile.parent);
        final backgroundFile = File(
          '${configFile.parent.path}/artwork/screenshot-background.png',
        );
        final background = await _decodeImage(backgroundFile);
        final inputHashes = <String, String>{
          'backgroundSha256': _sha256(backgroundFile),
          'copySha256': _sha256(copyFile),
          'configSha256': _sha256(configFile),
        };
        final manifestFile = File('${output.path}/marketing-manifest.json');
        final previous = manifestFile.existsSync()
            ? _readObject(manifestFile)
            : <String, dynamic>{};
        if (previous.isNotEmpty &&
            (previous['schemaVersion'] != 1 ||
                previous['renderer'] != _renderer)) {
          throw StateError('Refusing to replace another marketing manifest.');
        }
        final captures = <Map<String, dynamic>>[
          for (final item in previous['screenshots'] as List? ?? const [])
            Map<String, dynamic>.from(item as Map),
        ];

        try {
          for (final language in languages) {
            final code = _safeSegment(language['code'] as String);
            final locale = _safeSegment(language['appStoreLocale'] as String);
            final direction = language['direction'] == 'rtl'
                ? TextDirection.rtl
                : TextDirection.ltr;
            final localizedCopy = Map<String, dynamic>.from(
              (copy['languages'] as Map)[code] as Map,
            );
            final family = _primaryFamily(code);
            if (!fontFamilies.contains(family)) {
              throw StateError('Missing offline caption font: $family.');
            }
            for (final device in devices) {
              final deviceId = _safeSegment(device['id'] as String);
              final width = (device['width'] as num).toInt();
              final height = (device['height'] as num).toInt();
              final dpr = (device['pixelRatio'] as num).toDouble();
              for (final scene in scenes) {
                final sceneId = _safeSegment(scene['id'] as String);
                final sourcePath = 'screenshots/$locale/$deviceId/$sceneId.png';
                final sourceFile = File('${output.path}/$sourcePath');
                final destination = 'marketing/$locale/$deviceId/$sceneId.png';
                final sceneCopy = Map<String, dynamic>.from(
                  localizedCopy[sceneId] as Map,
                );
                final headline = (sceneCopy['headline'] as String).trim();
                final subtitle = (sceneCopy['subtitle'] as String).trim();
                if (headline.isEmpty || subtitle.isEmpty) {
                  throw FormatException('Empty captions: $code/$sceneId.');
                }
                final source = await _decodeImage(sourceFile);
                try {
                  if (source.width != width || source.height != height) {
                    throw StateError(
                      'Capture dimensions differ from device: $sourcePath.',
                    );
                  }
                  final layout = _MarketingLayout(
                    size: Size(width / dpr, height / dpr),
                    sourceSize: Size(
                      source.width.toDouble(),
                      source.height.toDouble(),
                    ),
                    headline: headline,
                    subtitle: subtitle,
                    family: family,
                    fallbackFamilies: fontFamilies,
                    direction: direction,
                    languageCode: code,
                    showDeviceFrame: device['platform'] != 'android',
                  );
                  final recorder = ui.PictureRecorder();
                  final canvas = Canvas(recorder)..scale(dpr);
                  layout.paint(canvas, background: background, source: source);
                  final picture = recorder.endRecording();
                  ui.Image? image;
                  try {
                    image = await picture.toImage(width, height);
                    final bytes = await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    if (bytes == null) {
                      throw StateError('PNG encoding failed: $destination.');
                    }
                    final file = File('${output.path}/$destination');
                    file.parent.createSync(recursive: true);
                    file.writeAsBytesSync(bytes.buffer.asUint8List());
                  } finally {
                    image?.dispose();
                    picture.dispose();
                  }
                  captures.removeWhere((item) => item['path'] == destination);
                  captures.add({
                    'language': code,
                    'locale': locale,
                    'device': deviceId,
                    'platform': device['platform'],
                    'screen': sceneId,
                    'path': destination,
                    'width': width,
                    'height': height,
                    'pixelRatio': dpr,
                    'renderer': _renderer,
                    'sourcePath': sourcePath,
                    'sourceSha256': _sha256(sourceFile),
                    ...inputHashes,
                    'sourceUiEdited': false,
                    'sourceUiCropped': false,
                    'sourceUiRoundedCornerMask': layout.showDeviceFrame,
                    'sourceUiTransform': layout.showDeviceFrame
                        ? 'uniform scale of full source viewport; '
                              'rounded outer-corner mask only'
                        : 'uniform scale of full source viewport; no cropping or masking',
                    'nativeDeviceCapture': false,
                    'deviceFrame': layout.showDeviceFrame
                        ? 'generic rounded frame; no hardware claims'
                        : 'none',
                    'headline': headline,
                    'subtitle': subtitle,
                    if (copy['sequence'] is List)
                      'sequence':
                          (copy['sequence'] as List).indexOf(sceneId) + 1,
                    'textDirection': direction.name,
                    'fontFamily': family,
                    ...layout.metadata(dpr),
                    if (deviceId.startsWith('iphone-duo'))
                      'note':
                          'Responsive real-widget preview, not a physical Duo '
                          'capture. Frame does not depict Apple hardware.',
                  });
                  _saveManifest(
                    manifestFile,
                    captures,
                    backgroundFile,
                    inputHashes,
                  );
                  layout.dispose();
                  // ignore: avoid_print
                  print('Composed $destination ($width × $height)');
                } finally {
                  source.dispose();
                }
              }
            }
          }
        } finally {
          background.dispose();
        }
      });
    },
    skip: outputPath == null,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

/// Layout is computed in logical pixels and recorded in physical pixels. The
/// source has the same aspect ratio as its target canvas; scaling it uniformly
/// is the only transformation. No content is stretched, covered or zoomed in.
class _MarketingLayout {
  _MarketingLayout({
    required this.size,
    required Size sourceSize,
    required String headline,
    required String subtitle,
    required String family,
    required List<String> fallbackFamilies,
    required TextDirection direction,
    required String languageCode,
    this.showDeviceFrame = true,
  }) {
    final width = size.width;
    final height = size.height;
    final marginX = math.max(16.0, width * .045);
    final marginY = math.max(14.0, height * .021);
    headlineBox = Rect.fromLTWH(
      marginX,
      marginY,
      width - marginX * 2,
      height * .132,
    );
    final frameArea = Rect.fromLTRB(
      marginX,
      headlineBox.bottom + height * .012,
      width - marginX,
      height * .895,
    );
    bezel = showDeviceFrame ? math.max(2.8, math.min(width, height) * .008) : 0;
    final available = Size(
      frameArea.width - bezel * 2,
      frameArea.height - bezel * 2,
    );
    final scale = math.min(
      available.width / sourceSize.width,
      available.height / sourceSize.height,
    );
    final imageSize = sourceSize * scale;
    screenRect = Rect.fromCenter(
      center: frameArea.center,
      width: imageSize.width,
      height: imageSize.height,
    );
    frameRect = screenRect.inflate(bezel);
    cornerRadius = showDeviceFrame
        ? math.min(screenRect.width * .069, height * .031)
        : 0;
    subtitleBox = Rect.fromLTRB(
      marginX,
      frameArea.bottom + height * .014,
      width - marginX,
      height - marginY,
    );
    final headlineSize = math.min(width * .085, height * .043);
    final minHeadlineSize = math.min(width * .062, height * .034);
    final subtitleSize = math.min(width * .047, height * .024);
    final minSubtitleSize = math.min(width * .038, height * .021);
    final textHeight = ['ar', 'hi'].contains(languageCode) ? 1.24 : 1.15;
    title = _FittedText(
      text: headline,
      box: headlineBox,
      fontSize: headlineSize,
      minimumFontSize: minHeadlineSize,
      family: family,
      fallbacks: fallbackFamilies,
      direction: direction,
      languageCode: languageCode,
      weight: FontWeight.w800,
      height: textHeight,
      color: _headlineColor,
      glow: true,
    );
    detail = _FittedText(
      text: subtitle,
      box: subtitleBox,
      fontSize: subtitleSize,
      minimumFontSize: minSubtitleSize,
      family: family,
      fallbacks: fallbackFamilies,
      direction: direction,
      languageCode: languageCode,
      weight: FontWeight.w600,
      height: textHeight,
      color: _subtitleColor,
    );
    if (!showDeviceFrame &&
        (title.rect.height + detail.rect.height) / height > .20) {
      throw StateError('Google Play caption height exceeds 20% of the image.');
    }
    if (headlineBox.overlaps(frameRect) ||
        subtitleBox.overlaps(frameRect) ||
        headlineBox.overlaps(subtitleBox)) {
      throw StateError('Marketing caption and device frame overlap.');
    }
    for (final rect in [headlineBox, frameRect, subtitleBox]) {
      if (!(Offset.zero & size).contains(rect.topLeft) ||
          !(Offset.zero & size).contains(rect.bottomRight)) {
        throw StateError('Marketing content exceeds screenshot bounds.');
      }
    }
    if ((screenRect.width / screenRect.height -
                sourceSize.width / sourceSize.height)
            .abs() >
        .000001) {
      throw StateError('Marketing composition changed the UI aspect ratio.');
    }
  }

  final Size size;
  final bool showDeviceFrame;
  late final Rect headlineBox;
  late final Rect subtitleBox;
  late final Rect screenRect;
  late final Rect frameRect;
  late final double bezel;
  late final double cornerRadius;
  late final _FittedText title;
  late final _FittedText detail;

  void paint(
    Canvas canvas, {
    required ui.Image background,
    required ui.Image source,
  }) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF090317));
    paintImage(
      canvas: canvas,
      rect: bounds,
      image: background,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
    // The art remains visible at the sides, while subdued caption regions stay
    // readable in small App Store previews and on bright screens.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xD9080318),
            Color(0x88080318),
            Color(0x22080318),
            Color(0x44080318),
            Color(0xE6080318),
          ],
          stops: [0, .13, .4, .78, 1],
        ).createShader(bounds),
    );
    if (showDeviceFrame) {
      final outer = RRect.fromRectAndRadius(
        frameRect,
        Radius.circular(cornerRadius + bezel),
      );
      canvas.drawShadow(
        Path()..addRRect(outer),
        const Color(0xFF000000),
        size.height * .018,
        false,
      );
      canvas.drawRRect(
        outer,
        Paint()
          ..color = const Color(0x554FE8FF)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, bezel * 2),
      );
      canvas.drawRRect(
        outer,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9696A4),
              Color(0xFF34303F),
              Color(0xFF0C0B14),
              Color(0xFF6C647E),
            ],
            stops: [0, .19, .67, 1],
          ).createShader(frameRect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          screenRect.inflate(bezel * .34),
          Radius.circular(cornerRadius + bezel * .34),
        ),
        Paint()..color = const Color(0xFF030309),
      );
    }
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(screenRect, Radius.circular(cornerRadius)),
      doAntiAlias: true,
    );
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      screenRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
    title.paint(canvas);
    detail.paint(canvas);
  }

  Map<String, dynamic> metadata(double dpr) => {
    'headlineFontSize': _round(title.fontSize * dpr),
    'subtitleFontSize': _round(detail.fontSize * dpr),
    'headlineLines': title.lineCount,
    'subtitleLines': detail.lineCount,
    'headlineRect': _rectMetadata(title.rect, dpr),
    'subtitleRect': _rectMetadata(detail.rect, dpr),
    'frameRect': _rectMetadata(frameRect, dpr),
    'sourceUiRect': _rectMetadata(screenRect, dpr),
    'noOverlapVerified': true,
    'sourceAspectRatioPreserved': true,
    'opaqueCanvas': true,
    'captionHeightFraction': _round(
      (title.rect.height + detail.rect.height) / size.height,
    ),
  };

  void dispose() {
    title.painter.dispose();
    detail.painter.dispose();
  }
}

class _FittedText {
  _FittedText({
    required String text,
    required Rect box,
    required double fontSize,
    required double minimumFontSize,
    required String family,
    required List<String> fallbacks,
    required TextDirection direction,
    required String languageCode,
    required FontWeight weight,
    required double height,
    required Color color,
    bool glow = false,
  }) {
    TextPainter measure(double candidate) {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontFamily: family,
            fontFamilyFallback: fallbacks,
            fontSize: candidate,
            fontWeight: weight,
            height: height,
            // Script shaping must not be disrupted by forced letter spacing.
            letterSpacing: ['ar', 'hi'].contains(languageCode)
                ? 0
                : -candidate * .012,
            shadows: glow
                ? [
                    Shadow(
                      color: const Color(0x5549E6FF),
                      blurRadius: candidate * .24,
                    ),
                    const Shadow(color: Color(0xBB080318), blurRadius: 3),
                  ]
                : const [Shadow(color: Color(0xDD080318), blurRadius: 3)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: direction,
        locale: Locale(languageCode),
        maxLines: 2,
      )..layout(maxWidth: box.width);
    }

    bool fits(TextPainter candidate) =>
        !candidate.didExceedMaxLines && candidate.height <= box.height;

    var candidate = measure(fontSize);
    if (!fits(candidate)) {
      candidate.dispose();
      candidate = measure(minimumFontSize);
      if (!fits(candidate)) {
        candidate.dispose();
        throw StateError(
          'Caption cannot fit at a readable font size: "$text" ($languageCode).',
        );
      }
      var low = minimumFontSize;
      var high = fontSize;
      for (var attempt = 0; attempt < 12; attempt++) {
        final middle = (low + high) / 2;
        final probe = measure(middle);
        final probeFits = fits(probe);
        probe.dispose();
        if (probeFits) {
          low = middle;
        } else {
          high = middle;
        }
      }
      candidate.dispose();
      fontSize = low;
      candidate = measure(fontSize);
    }
    this.fontSize = fontSize;
    painter = candidate;
    rect = Rect.fromLTWH(
      box.center.dx - candidate.width / 2,
      box.center.dy - candidate.height / 2,
      candidate.width,
      candidate.height,
    );
    lineCount = candidate.computeLineMetrics().length;
  }

  late final TextPainter painter;
  late final Rect rect;
  late final double fontSize;
  late final int lineCount;

  void paint(Canvas canvas) => painter.paint(canvas, rect.topLeft);
}

Future<List<String>> _loadOfflineFonts(
  Map<String, dynamic> config,
  Directory configDir,
) async {
  final families = <String>[];
  for (final raw in config['fonts'] as List) {
    final font = Map<String, dynamic>.from(raw as Map);
    final family = font['family'] as String;
    final path = font['path'] as String;
    final file = path.startsWith('/')
        ? File(path)
        : File('${configDir.path}/$path');
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
    families.add(family);
  }
  return families;
}

String _primaryFamily(String code) => switch (code) {
  'zh' => 'NotoSansSC',
  'ja' => 'NotoSansJP',
  'ko' => 'NotoSansKR',
  'ar' => 'NotoSansArabic',
  'hi' => 'NotoSansDevanagari',
  _ => 'Manrope',
};

Future<ui.Image> _decodeImage(File file) async {
  final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Map<String, dynamic> _readObject(File file) =>
    Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);

List<Map<String, dynamic>> _select(
  List<dynamic> items,
  String? selector,
  String key,
) {
  final requested = selector == null || selector.trim().isEmpty
      ? null
      : selector.split(',').map((value) => value.trim()).toSet();
  final selected = <Map<String, dynamic>>[];
  for (final raw in items) {
    final item = Map<String, dynamic>.from(raw as Map);
    // Disabled profiles are excluded by default, but an explicit selector is a
    // deliberate opt-in, consistent with capture_ui.dart and the Python CLI.
    if (requested == null && item['enabled'] == false) continue;
    if (requested == null || requested.contains(item[key])) selected.add(item);
  }
  if (selected.isEmpty ||
      (requested != null && selected.length != requested.length)) {
    throw FormatException('Unknown store asset selection: $selector');
  }
  return selected;
}

String _safeSegment(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw FormatException('Unsafe store asset path segment: $value');
  }
  return value;
}

void _saveManifest(
  File file,
  List<Map<String, dynamic>> captures,
  File background,
  Map<String, String> inputHashes,
) {
  captures.sort((a, b) => (a['path'] as String).compareTo(b['path'] as String));
  final manifest = <String, dynamic>{
    'schemaVersion': 1,
    'renderer': _renderer,
    'kind': 'localized-app-store-marketing-screenshots',
    'networkAccess': false,
    'personalData': false,
    'background': background.uri.pathSegments.last,
    'latestCompositionInputs': inputHashes,
    'screenshots': captures,
  };
  _atomicWriteString(
    file,
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
}

/// A sibling lives on the destination filesystem, so POSIX rename publishes the
/// entire manifest atomically. Failure before rename leaves the old index intact.
void _atomicWriteString(File destination, String contents) {
  destination.parent.createSync(recursive: true);
  final unique =
      '$pid-${DateTime.now().microsecondsSinceEpoch}-'
      '${math.Random.secure().nextInt(0x7FFFFFFF).toRadixString(16)}';
  final temporary = File('${destination.path}.tmp-$unique');
  // Exclusive creation establishes ownership. Never truncate or clean up a
  // pre-existing file if an extraordinarily unlikely name collision occurs.
  temporary.createSync(exclusive: true);
  try {
    temporary.writeAsStringSync(contents, flush: true);
    temporary.renameSync(destination.path);
  } finally {
    // rename removes this exact owned path. On any earlier failure remove only
    // our temporary file, never the old manifest, siblings, or a whole directory.
    if (temporary.existsSync()) temporary.deleteSync();
  }
}

Map<String, double> _rectMetadata(Rect rect, double dpr) => {
  'x': _round(rect.left * dpr),
  'y': _round(rect.top * dpr),
  'width': _round(rect.width * dpr),
  'height': _round(rect.height * dpr),
};

double _round(double value) => (value * 100).round() / 100;

String _sha256(File file) =>
    crypto.sha256.convert(file.readAsBytesSync()).toString();
