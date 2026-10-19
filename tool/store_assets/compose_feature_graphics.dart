// Offline Google Play feature graphics. Reuses the approved cocktail artwork;
// all lettering is shaped by Flutter with the pinned fonts, not image-generated.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _renderer = 'flutter-feature-graphic-compositor';
const _size = Size(1024, 500);

void main() {
  final configFile = File(
    Platform.environment['STORE_ASSET_CONFIG'] ??
        'tool/store_assets/config.json',
  ).absolute;
  final copyFile = File('${configFile.parent.path}/feature_graphic_copy.json');

  test('feature graphic copy covers every configured language', () {
    final config = _object(configFile);
    final copy = _object(copyFile);
    expect(copy['schemaVersion'], 1);
    final languages = copy['languages'] as Map;
    expect(languages.keys.toSet(), {
      for (final language in config['languages'] as List) language['code'],
    });
    for (final language in config['languages'] as List) {
      final code = language['code'] as String;
      final text = languages[code] as Map;
      expect(text['brand'], isNotEmpty);
      expect((text['headline'] as String).split('\n'), hasLength(2));
      expect((text['headline'] as String).runes.length, lessThanOrEqualTo(90));
      expect((text['altText'] as String).runes.length, lessThanOrEqualTo(140));
      expect(text['textDirection'], language['direction']);
      expect(text['fontFamily'], _family(code));
    }
  });

  testWidgets(
    'compose localized feature graphics with readable text and safe margins',
    (tester) async {
      await tester.runAsync(() async {
        final config = _object(configFile);
        final copy = _object(copyFile);
        final selected = Platform.environment['STORE_ASSET_LANGUAGES'];
        final codes = selected == null || selected.trim().isEmpty
            ? null
            : selected.split(',').map((value) => value.trim()).toSet();
        final languages = (config['languages'] as List)
            .map((raw) => Map<String, dynamic>.from(raw as Map))
            .where(
              (language) => codes == null || codes.contains(language['code']),
            )
            .toList();
        if (languages.isEmpty ||
            (codes != null && languages.length != codes.length)) {
          throw const FormatException('Unknown feature graphic languages.');
        }
        final families = await _loadFonts(config, configFile.parent);
        final sourceFile = File(
          '${configFile.parent.path}/artwork/cocktails-master.png',
        );
        final source = await _decode(sourceFile);
        final output = Directory(
          Platform.environment['STORE_ASSET_OUTPUT']!,
        ).absolute;
        final manifest = File(
          '${output.path}/google-play-feature-graphic-manifest.json',
        );
        final previous = manifest.existsSync() ? _object(manifest) : null;
        if (previous != null &&
            (previous['schemaVersion'] != 1 ||
                previous['renderer'] != _renderer)) {
          throw StateError(
            'Refusing to replace an unrelated graphic manifest.',
          );
        }
        final entries = <Map<String, dynamic>>[
          for (final raw in previous?['graphics'] as List? ?? const [])
            Map<String, dynamic>.from(raw as Map),
        ];
        final overwrite = [
          '1',
          'true',
        ].contains(Platform.environment['STORE_ASSET_OVERWRITE']);
        // Check all selected destinations before writing anything.
        for (final language in languages) {
          final locale = _segment(language['googlePlayLocale'] as String);
          final path = File(
            '${output.path}/google-play/$locale/feature-graphic.png',
          );
          if (path.existsSync() && !overwrite) {
            throw StateError('Feature graphic already exists: ${path.path}');
          }
        }
        try {
          for (final language in languages) {
            final code = language['code'] as String;
            final locale = _segment(language['googlePlayLocale'] as String);
            final text = Map<String, dynamic>.from(
              (copy['languages'] as Map)[code] as Map,
            );
            final layout = _FeatureLayout(
              text: text,
              code: code,
              families: families,
              rtl: language['direction'] == 'rtl',
            );
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            layout.paint(canvas, source);
            final picture = recorder.endRecording();
            ui.Image? graphic;
            final path = 'google-play/$locale/feature-graphic.png';
            try {
              graphic = await picture.toImage(1024, 500);
              final bytes = await graphic.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (bytes == null) {
                throw StateError('Feature graphic encoding failed.');
              }
              final file = File('${output.path}/$path');
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes.buffer.asUint8List());
              entries.removeWhere((entry) => entry['path'] == path);
              entries.add({
                'language': code,
                'locale': locale,
                'path': path,
                'width': 1024,
                'height': 500,
                'assetType': 'feature-graphic',
                'renderer': _renderer,
                'brand': text['brand'],
                'headline': text['headline'],
                'altText': text['altText'],
                'textDirection': layout.rtl ? 'rtl' : 'ltr',
                'fontFamily': _family(code),
                'sourceSha256': _hash(sourceFile),
                'copySha256': _hash(copyFile),
                'configSha256': _hash(configFile),
                'layout': layout.metadata,
                'kind': 'marketing-artwork',
                'deviceCapture': false,
              });
              entries.sort(
                (a, b) => (a['path'] as String).compareTo(b['path'] as String),
              );
              _atomicJson(manifest, {
                'schemaVersion': 1,
                'renderer': _renderer,
                'graphics': entries,
                'uploaded': false,
              });
              // ignore: avoid_print
              print('Composed $path (1024 × 500)');
            } finally {
              graphic?.dispose();
              picture.dispose();
              layout.dispose();
            }
          }
        } finally {
          source.dispose();
        }
      });
    },
    skip: Platform.environment['STORE_ASSET_OUTPUT'] == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _FeatureLayout {
  _FeatureLayout({
    required Map<String, dynamic> text,
    required String code,
    required List<String> families,
    required this.rtl,
  }) {
    final left = rtl ? 530.0 : 104.0;
    brandBox = Rect.fromLTWH(left, 125, 390, 54);
    headlineBox = Rect.fromLTWH(left, 207, 390, 145);
    brand = _fit(
      text['brand'] as String,
      box: brandBox,
      family: code == 'ru' ? 'Manrope' : 'Orbitron',
      fallbacks: families,
      direction: TextDirection.ltr,
      alignment: rtl ? TextAlign.right : TextAlign.left,
      locale: Locale(code),
      fontSize: 34,
      minFontSize: 32,
      color: const Color(0xFF97F6FF),
      height: 1.3,
    );
    headline = _fit(
      text['headline'] as String,
      box: headlineBox,
      family: _family(code),
      fallbacks: families,
      direction: rtl ? TextDirection.rtl : TextDirection.ltr,
      alignment: rtl ? TextAlign.right : TextAlign.left,
      locale: Locale(code),
      fontSize: 44,
      minFontSize: 34,
      color: const Color(0xFFF4EDFF),
      height: ['hi', 'ar'].contains(code) ? 1.4 : 1.25,
    );
    expect(headline.didExceedMaxLines, isFalse);
    expect(headline.computeLineMetrics(), hasLength(2));
    expect(headline.height, lessThanOrEqualTo(headlineBox.height));
    expect(brandBox.overlaps(headlineBox), isFalse);
    expect(brandBox.left, greaterThanOrEqualTo(100));
    expect(headlineBox.right, lessThanOrEqualTo(924));
  }

  final bool rtl;
  late final Rect brandBox;
  late final Rect headlineBox;
  late final TextPainter brand;
  late final TextPainter headline;

  void paint(Canvas canvas, ui.Image source) {
    final bounds = Offset.zero & _size;
    canvas.drawColor(const Color(0xFF100B29), BlendMode.src);
    // Shift the complete approved photograph, not individual glasses. Uniform
    // cropping/scale preserves the subjects and places them opposite the text.
    final scale = 1.1 * 1672 / source.width;
    final heroCenter = rtl ? 282.0 : 742.0;
    final sourceRect = Rect.fromLTWH(
      source.width * .5 - heroCenter / scale,
      source.height * .417 - 250 / scale,
      _size.width / scale,
      _size.height / scale,
    );
    expect(sourceRect.left, greaterThanOrEqualTo(0));
    expect(sourceRect.right, lessThanOrEqualTo(source.width));
    expect(sourceRect.top, greaterThanOrEqualTo(0));
    expect(sourceRect.bottom, lessThanOrEqualTo(source.height));
    canvas.drawImageRect(
      source,
      sourceRect,
      bounds,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
          end: rtl ? Alignment.centerLeft : Alignment.centerRight,
          colors: const [
            Color(0x550C0926),
            Color(0x22080B22),
            Color(0x00080B22),
          ],
          stops: const [0, .48, .70],
        ).createShader(bounds),
    );
    final accent = Rect.fromLTWH(rtl ? 866 : 104, 188, 54, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(accent, const Radius.circular(2)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF85EEFF), Color(0xFFAA75FF)],
        ).createShader(accent),
    );
    brand.paint(canvas, brandBox.topLeft);
    headline.paint(canvas, headlineBox.topLeft);
  }

  Map<String, dynamic> get metadata => {
    'brandRect': _rect(brandBox),
    'headlineRect': _rect(headlineBox),
    'headlineFontSize': headline.text!.style!.fontSize,
    'headlineLines': headline.computeLineMetrics().length,
    'mirroredLayout': rtl,
    'artworkMirrored': false,
    'opaqueCanvas': true,
    'deviceImagery': false,
    'sourceTransform': 'uniform photographic crop; no subject edits',
  };

  void dispose() {
    brand.dispose();
    headline.dispose();
  }
}

TextPainter _fit(
  String text, {
  required Rect box,
  required String family,
  required List<String> fallbacks,
  required TextDirection direction,
  required TextAlign alignment,
  required Locale locale,
  required double fontSize,
  required double minFontSize,
  required Color color,
  required double height,
}) {
  for (var size = fontSize; size >= minFontSize; size -= .25) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontFamilyFallback: fallbacks,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: height,
          color: color,
        ),
      ),
      textDirection: direction,
      textAlign: alignment,
      locale: locale,
      maxLines: 2,
    )..layout(minWidth: box.width, maxWidth: box.width);
    if (!painter.didExceedMaxLines && painter.height <= box.height) {
      return painter;
    }
    painter.dispose();
  }
  throw StateError('Feature graphic text cannot fit readably: $text');
}

String _family(String code) => switch (code) {
  'zh' => 'NotoSansSC',
  'ja' => 'NotoSansJP',
  'ko' => 'NotoSansKR',
  'ar' => 'NotoSansArabic',
  'hi' => 'NotoSansDevanagari',
  _ => 'Manrope',
};

Future<List<String>> _loadFonts(
  Map<String, dynamic> config,
  Directory parent,
) async {
  final families = <String>[];
  for (final font in config['fonts'] as List) {
    final path = font['path'] as String;
    final file = File(path.startsWith('/') ? path : '${parent.path}/$path');
    if (_hash(file) != font['sha256']) {
      throw StateError('Offline font hash mismatch.');
    }
    final family = font['family'] as String;
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
    families.add(family);
  }
  return families;
}

Future<ui.Image> _decode(File file) async {
  final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

String _hash(File file) =>
    crypto.sha256.convert(file.readAsBytesSync()).toString();
Map<String, dynamic> _object(File file) =>
    Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
List<double> _rect(Rect rect) => [rect.left, rect.top, rect.width, rect.height];
String _segment(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw const FormatException('Unsafe locale path.');
  }
  return value;
}

void _atomicJson(File file, Map<String, dynamic> data) {
  file.parent.createSync(recursive: true);
  final temporary = File('${file.path}.tmp');
  try {
    temporary.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
      flush: true,
    );
    temporary.renameSync(file.path);
  } finally {
    if (temporary.existsSync()) temporary.deleteSync();
  }
}
