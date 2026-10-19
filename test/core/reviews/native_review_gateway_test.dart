import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/reviews/native_review_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.britannio.in_app_review');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'isAvailable' ? true : null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('uses only the native review API on ${platform.name}', () async {
      final gateway = NativeReviewGateway(platform: platform, isWeb: false);

      expect(gateway.isSupported, isTrue);
      expect(await gateway.isAvailable(), isTrue);
      await gateway.requestReview();

      expect(calls.map((call) => call.method), [
        'isAvailable',
        'requestReview',
      ]);
      expect(calls.every((call) => call.arguments == null), isTrue);
    });
  }

  for (final platform in [
    TargetPlatform.fuchsia,
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    test('does not call the plugin on ${platform.name}', () async {
      final gateway = NativeReviewGateway(platform: platform, isWeb: false);

      expect(gateway.isSupported, isFalse);
      expect(await gateway.isAvailable(), isFalse);
      await gateway.requestReview();

      expect(calls, isEmpty);
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('does not call the plugin on ${platform.name} web', () async {
      final gateway = NativeReviewGateway(platform: platform, isWeb: true);

      expect(gateway.isSupported, isFalse);
      expect(await gateway.isAvailable(), isFalse);
      await gateway.requestReview();

      expect(calls, isEmpty);
    });
  }

  test('uses the current platform by default', () {
    final gateway = NativeReviewGateway();

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(gateway.isSupported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(gateway.isSupported, isFalse);
  });

  for (final available in [false, null]) {
    test('handles an unavailable native API ($available)', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => available);
      final gateway = NativeReviewGateway(
        platform: TargetPlatform.iOS,
        isWeb: false,
      );

      expect(await gateway.isAvailable(), isFalse);
    });
  }

  test('availability fails closed when the native API fails', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(code: 'unavailable');
    });
    final gateway = NativeReviewGateway(
      platform: TargetPlatform.android,
      isWeb: false,
    );

    expect(await gateway.isAvailable(), isFalse);
    expect(calls.single.method, 'isAvailable');
  });

  test('request failures propagate without opening a store listing', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(code: 'unavailable');
    });
    final gateway = NativeReviewGateway(
      platform: TargetPlatform.android,
      isWeb: false,
    );

    await expectLater(
      gateway.requestReview(),
      throwsA(isA<PlatformException>()),
    );
    expect(calls.map((call) => call.method), ['requestReview']);
  });

  test(
    'a missing plugin is unavailable and request errors propagate',
    () async {
      messenger.setMockMethodCallHandler(channel, null);
      final gateway = NativeReviewGateway(
        platform: TargetPlatform.iOS,
        isWeb: false,
      );

      expect(await gateway.isAvailable(), isFalse);
      await expectLater(
        gateway.requestReview(),
        throwsA(isA<MissingPluginException>()),
      );
    },
  );
}
