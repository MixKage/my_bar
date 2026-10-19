import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:my_bar/core/widgets/bar_network_image.dart';
import 'package:my_bar/core/widgets/bar_resize_image.dart';
import 'package:my_bar/core/widgets/stretched_dots_loader.dart';

const _fallback = SizedBox(key: ValueKey('image-error'));

Uint8List _png(int width, int height) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}

Future<ImageInfo> _resolve(ImageProvider<Object> provider) async {
  final result = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) => result.complete(info),
    onError: (Object error, StackTrace? stack) =>
        result.completeError(error, stack),
  );
  stream.addListener(listener);
  try {
    return await result.future;
  } finally {
    stream.removeListener(listener);
  }
}

Widget _image(String source) {
  return BarNetworkImage(
    imageUrl: source,
    loadingColor: Colors.white,
    loadingBackgroundColor: Colors.black,
    errorWidget: _fallback,
  );
}

Widget _host(
  String source, {
  Size? size = const Size(76, 76),
  double pixelRatio = 1,
  AssetBundle? bundle,
}) {
  Widget child = size == null
      ? UnconstrainedBox(child: _image(source))
      : Center(
          child: SizedBox.fromSize(size: size, child: _image(source)),
        );
  if (bundle != null) {
    child = DefaultAssetBundle(bundle: bundle, child: child);
  }
  return MediaQuery(
    data: MediaQueryData(devicePixelRatio: pixelRatio),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );
}

void main() {
  for (final scenario in [
    (
      name: 'landscape cover',
      source: const Size(1200, 600),
      fit: BoxFit.cover,
      expected: const Size(300, 150),
    ),
    (
      name: 'portrait cover',
      source: const Size(600, 1200),
      fit: BoxFit.cover,
      expected: const Size(150, 300),
    ),
    (
      name: 'landscape contain',
      source: const Size(1200, 600),
      fit: BoxFit.contain,
      expected: const Size(150, 75),
    ),
    (
      name: 'portrait contain',
      source: const Size(600, 1200),
      fit: BoxFit.contain,
      expected: const Size(75, 150),
    ),
    (
      name: 'small source is not upscaled',
      source: const Size(40, 20),
      fit: BoxFit.cover,
      expected: const Size(40, 20),
    ),
  ]) {
    testWidgets('decodes ${scenario.name} without changing aspect ratio', (
      tester,
    ) async {
      final info = await tester.runAsync(
        () => _resolve(
          BarResizeImage(
            MemoryImage(
              _png(
                scenario.source.width.toInt(),
                scenario.source.height.toInt(),
              ),
            ),
            width: 150,
            height: 150,
            fit: scenario.fit,
          ),
        ),
      );
      expect(info!.image.width, scenario.expected.width);
      expect(info.image.height, scenario.expected.height);
      info.dispose();
    });
  }

  testWidgets('an unbounded axis uses the remaining bounded dimension', (
    tester,
  ) async {
    final provider = MemoryImage(_png(1200, 600));
    final byWidth = await tester.runAsync(
      () => _resolve(BarResizeImage(provider, width: 150)),
    );
    final byHeight = await tester.runAsync(
      () => _resolve(BarResizeImage(provider, height: 150)),
    );
    expect(byWidth!.image.width, 150);
    expect(byWidth.image.height, 75);
    expect(byHeight!.image.width, 300);
    expect(byHeight.image.height, 150);
    byWidth.dispose();
    byHeight.dispose();
  });

  testWidgets(
    'asset thumbnails decode to physical pixels at each screen density',
    (tester) async {
      final bundle = _ImageAssetBundle(_png(700, 700));
      for (final ratio in [1.0, 2.0, 3.0]) {
        await tester.pumpWidget(
          _host('assets/test.png', pixelRatio: ratio, bundle: bundle),
        );
        final provider =
            tester.widget<Image>(find.byType(Image)).image as BarResizeImage;
        final key = await provider.obtainKey(
          ImageConfiguration(bundle: bundle),
        );
        expect(provider.width, (76 * ratio).ceil());
        expect(provider.height, (76 * ratio).ceil());
        expect(provider.imageProvider, isA<AssetImage>());
        final info = await tester.runAsync(() => _resolveKey(provider, key));
        expect(info!.image.width, (76 * ratio).ceil());
        expect(info.image.height, (76 * ratio).ceil());
        info.dispose();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fully unbounded layout keeps natural source dimensions', (
    tester,
  ) async {
    final bundle = _ImageAssetBundle(_png(120, 60));
    await tester.pumpWidget(
      _host('assets/test.png', size: null, bundle: bundle),
    );
    expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
    await tester.runAsync(() async {
      final provider = AssetImage('assets/test.png', bundle: bundle);
      final info = await _resolve(provider);
      expect(info.image.width, 120);
      expect(info.image.height, 60);
      info.dispose();
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('local files and file URIs share downsampled decoding', (
    tester,
  ) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('bar-image-test-'),
    );
    addTearDown(() => directory!.delete(recursive: true));
    final file = await tester.runAsync(
      () => File('${directory!.path}/large.png').writeAsBytes(_png(1200, 600)),
    );
    for (final source in [file!.path, file.uri.toString()]) {
      await tester.pumpWidget(
        _host(source, size: const Size(100, 100), pixelRatio: 2),
      );
      final provider =
          tester.widget<Image>(find.byType(Image)).image as BarResizeImage;
      expect(provider.imageProvider, isA<FileImage>());
      final info = await tester.runAsync(() async {
        final key = await provider.obtainKey(ImageConfiguration.empty);
        return _resolveKey(provider, key);
      });
      expect(info!.image.width, 400);
      expect(info.image.height, 200);
      info.dispose();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'network images retain loading progress and decode at display size',
    (tester) async {
      final bytes = _png(700, 700);
      debugNetworkImageHttpClientProvider = () => _ImageHttpClient(bytes);
      try {
        await tester.pumpWidget(
          _host('https://images.example.test/cocktail.png', pixelRatio: 2),
        );
        final image = tester.widget<Image>(find.byType(Image));
        final provider = image.image as BarResizeImage;
        expect(provider.imageProvider, isA<NetworkImage>());
        final context = tester.element(find.byType(Image));
        expect(
          image.loadingBuilder!(
            context,
            const SizedBox(),
            const ImageChunkEvent(
              cumulativeBytesLoaded: 50,
              expectedTotalBytes: 100,
            ),
          ),
          isA<StretchedDotsLoader>(),
        );
        final info = await tester.runAsync(() async {
          final key = await provider.obtainKey(ImageConfiguration.empty);
          return _resolveKey(provider, key);
        });
        expect(info!.image.width, 152);
        expect(info.image.height, 152);
        info.dispose();
        expect(tester.takeException(), isNull);
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );

  testWidgets(
    'invalid sources and failed image decodes retain the error placeholder',
    (tester) async {
      for (final source in ['', '/missing/cocktail.png']) {
        await tester.pumpWidget(_host(source));
        expect(find.byKey(const ValueKey('image-error')), findsOneWidget);
      }
      await tester.pumpWidget(
        _host('assets/broken.png', bundle: _ImageAssetBundle(Uint8List(0))),
      );
      await tester.runAsync(() async {
        // Await a failed resolution so the widget's error listener has run.
        final provider = tester.widget<Image>(find.byType(Image)).image;
        final key = await provider.obtainKey(
          ImageConfiguration(bundle: _ImageAssetBundle(Uint8List(0))),
        );
        try {
          await _resolveKey(provider, key);
        } catch (_) {
          // The image widget presents its errorBuilder instead of reporting it.
        }
      });
      await tester.pump();
      expect(find.byKey(const ValueKey('image-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<ImageInfo> _resolveKey(ImageProvider provider, Object key) async {
  return _resolve(_ImageDecoderHarness(provider, key));
}

/// Resolves a fresh stream in runAsync instead of reusing a widget-owned stream
/// whose I/O callbacks belong to the fake clock's zone.
class _ImageDecoderHarness extends ImageProvider<_ImageDecoderHarness> {
  const _ImageDecoderHarness(this.provider, this.providerKey);

  final ImageProvider<Object> provider;
  final Object providerKey;

  @override
  Future<_ImageDecoderHarness> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_ImageDecoderHarness>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _ImageDecoderHarness key,
    ImageDecoderCallback decode,
  ) => provider.loadImage(providerKey, decode);
}

class _ImageAssetBundle extends CachingAssetBundle {
  _ImageAssetBundle(this.bytes);
  final Uint8List bytes;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    return ByteData.sublistView(bytes);
  }
}

class _ImageHttpClient implements HttpClient {
  _ImageHttpClient(this.bytes);
  final Uint8List bytes;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _ImageHttpRequest(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageHttpRequest implements HttpClientRequest {
  _ImageHttpRequest(this.bytes);
  final Uint8List bytes;

  @override
  Future<HttpClientResponse> close() async => _ImageHttpResponse(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _ImageHttpResponse(this.bytes);
  final Uint8List bytes;

  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
