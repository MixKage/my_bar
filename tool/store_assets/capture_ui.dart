// Offline App Store screenshot capture. This is a tooling-only Flutter test,
// never an application entry point and never an upload command.
//
// Invoke through tool/store_assets/store_assets.py so config, fonts and output
// are validated first. The explicit test skip keeps normal `flutter test` runs
// from creating hundreds of large PNGs.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_bar/core/localization/app_language.dart';
import 'package:my_bar/core/localization/app_localization.dart';
import 'package:my_bar/core/theme/app_theme.dart';
import 'package:my_bar/core/widgets/bar_network_image.dart';
import 'package:my_bar/core/widgets/stretched_dots_loader.dart';
import 'package:my_bar/features/bar/cubit/bar_cubit.dart';
import 'package:my_bar/features/bar/data/bar_ui_settings_storage.dart';
import 'package:my_bar/features/bar/data/catalog_overrides_storage.dart';
import 'package:my_bar/features/bar/data/external_catalog_cache_storage.dart';
import 'package:my_bar/features/bar/data/ingredient_selection_storage.dart';
import 'package:my_bar/features/bar/data/local_catalog_storage.dart';
import 'package:my_bar/features/bar/data/providers/external_bar_data_provider.dart';
import 'package:my_bar/features/bar/data/repositories/bar_catalog_repository.dart';
import 'package:my_bar/features/bar/data/shopping_list_storage.dart';
import 'package:my_bar/features/bar/domain/models/bar_catalog.dart';
import 'package:my_bar/features/bar/domain/models/catalog_data_source.dart';
import 'package:my_bar/features/bar/domain/models/cocktail.dart';
import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/features/bar/domain/models/measurement_system.dart';
import 'package:my_bar/features/bar/presentation/bar_home_shell.dart';
import 'package:my_bar/features/bar/presentation/pages/cocktail_details_page.dart';
import 'package:my_bar/features/bar/presentation/pages/party_mode_page.dart';
import 'package:my_bar/features/bar/presentation/pages/raw_bar_page.dart';
import 'package:my_bar/features/bar/presentation/pages/surprise_cocktail_page.dart';

const _sceneNames = <String>[
  '01-ingredients',
  '02-cocktails',
  '03-recipe',
  '04-party',
  '05-shopping',
  '06-surprise',
  '07-almost-ready',
];

// A fictional, reproducible home bar. No device preferences or user files are
// read. These are real seed IDs, not a miniature substitute catalogue.
const _ownedIds = <String>{
  'gin',
  'vodka',
  'rum_light',
  'tequila',
  'bourbon',
  'triple_sec',
  'lime',
  'lemon',
  'sugar',
  'mint',
  'soda_water',
  'water',
  'angostura_bitter',
  'juice_orange',
  'juice_cranberry',
  'salt',
};
const _shoppingIds = <String>{'campari', 'rosso_vermouth', 'cointreau'};

void main() {
  test('atomic capture manifest replaces complete JSON without leftovers', () {
    final directory = Directory.systemTemp.createTempSync(
      'my-bar-capture-test-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final destination = File('${directory.path}/capture-manifest.json')
      ..writeAsStringSync('{"old":true}');
    _atomicWriteManifest(destination, '{"complete":true}');
    expect(jsonDecode(destination.readAsStringSync()), {'complete': true});
    expect(directory.listSync().length, 1);
  });
  test('atomic capture manifest failure cleans only its owned temporary', () {
    final directory = Directory.systemTemp.createTempSync(
      'my-bar-capture-test-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final destination = Directory('${directory.path}/capture-manifest.json')
      ..createSync();
    final retained = File('${destination.path}/keep.txt')
      ..writeAsStringSync('keep');
    expect(
      () => _atomicWriteManifest(File(destination.path), '{}'),
      throwsA(isA<FileSystemException>()),
    );
    expect(retained.readAsStringSync(), 'keep');
    expect(directory.listSync().length, 1);
  });
  final outputPath = Platform.environment['STORE_ASSET_OUTPUT'];
  testWidgets(
    'capture localized store screenshots with the real Flutter renderer',
    (tester) async {
      final configFile = File(
        Platform.environment['STORE_ASSET_CONFIG'] ??
            'tool/store_assets/config.json',
      ).absolute;
      final config =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final output = Directory(outputPath!).absolute;
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
        [
          for (final scene in _sceneNames) {'id': scene},
        ],
        Platform.environment['STORE_ASSET_SCENES'],
        'id',
      ).map((scene) => scene['id'] as String).toSet();
      final fonts = _readFonts(config, configFile.parent);
      await _installOfflineAssets(tester, fonts);
      await tester.runAsync(() => _loadFonts(fonts));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/charging'),
        (_) async => null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/battery'),
        (call) async => call.method == 'isInBatterySaveMode' ? false : 100,
      );
      GoogleFonts.config.allowRuntimeFetching = false;
      final oldHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = _OfflineOnlyHttpOverrides();
      addTearDown(() => HttpOverrides.global = oldHttpOverrides);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.view.reset);

      final manifestFile = File('${output.path}/capture-manifest.json');
      final manifest = manifestFile.existsSync()
          ? jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>
          : <String, dynamic>{};
      final captures = <Map<String, dynamic>>[
        for (final item in (manifest['screenshots'] as List? ?? const []))
          Map<String, dynamic>.from(item as Map),
      ];

      final oldDisableShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        for (final language in languages) {
          final code = language['code'] as String;
          final appLanguage = AppLanguageX.fromStorage(code);
          if (appLanguage == AppLanguage.system) {
            throw FormatException('Unsupported application language: $code');
          }
          final localizedProvider = LocalizedJsonAssetExternalBarDataProvider(
            defaultAssetPath: 'assets/data/bar_template.json',
            russianAssetPath: 'assets/data/bar_template_ru.json',
            useRussianCatalogResolver: () => code == 'ru',
            languageCodeResolver: () => code,
          );
          final payload = (await tester.runAsync(
            localizedProvider.fetchCatalogSnapshot,
          ))!;
          final catalog = BarCatalog(
            ingredients: payload.ingredients.map(Ingredient.fromJson).toList(),
            cocktails: payload.cocktails.map(Cocktail.fromJson).toList(),
          );
          expect(catalog.ingredients.length, greaterThanOrEqualTo(297));
          expect(catalog.cocktails.length, greaterThanOrEqualTo(384));
          for (final image in [
            ...catalog.ingredients.map((item) => item.image),
            ...catalog.cocktails.map((item) => item.image),
          ]) {
            if (image.isNotEmpty && !image.startsWith('assets/')) {
              throw StateError(
                'Store captures must use offline seed images: $image',
              );
            }
          }

          for (final device in devices) {
            final id = device['id'] as String;
            final width = (device['width'] as num).toInt();
            final height = (device['height'] as num).toInt();
            final dpr = (device['pixelRatio'] as num).toDouble();
            final safe = Map<String, dynamic>.from(
              device['safeArea'] as Map? ?? const {},
            );
            tester.view.devicePixelRatio = dpr;
            tester.view.physicalSize = Size(
              width.toDouble(),
              height.toDouble(),
            );
            tester.view.padding = FakeViewPadding(
              left: (safe['left'] as num? ?? 0).toDouble() * dpr,
              top: (safe['top'] as num? ?? 0).toDouble() * dpr,
              right: (safe['right'] as num? ?? 0).toDouble() * dpr,
              bottom: (safe['bottom'] as num? ?? 0).toDouble() * dpr,
            );
            tester.view.viewPadding = tester.view.padding;

            final selector = SelectableExternalBarDataProvider(
              seedProvider: localizedProvider,
              bootstrapDefaultProvider: localizedProvider,
              bootstrapDefaultDataSource: CatalogDataSource.seed,
            );
            final repository = BarCatalogRepository(
              externalProvider: selector,
              externalCacheStorage: InMemoryExternalCatalogCacheStorage(),
              localStorage: InMemoryLocalCatalogStorage(),
              overridesStorage: InMemoryCatalogOverridesStorage(),
              templateCatalog: catalog,
            );
            final snapshot = (await tester.runAsync(repository.initialize))!;
            final boundaryKey = GlobalKey();
            final captureCubit = BarCubit(
              selectionStorage: InMemoryIngredientSelectionStorage(
                initial: _ownedIds,
              ),
              settingsStorage: InMemoryBarUiSettingsStorage(
                initial: BarUiSettings(
                  appLanguage: appLanguage,
                  measurementSystem: MeasurementSystem.ml,
                ),
              ),
              shoppingListStorage: InMemoryShoppingListStorage(
                initial: _shoppingIds,
              ),
              catalogRepository: repository,
              externalProviderSelector: selector,
              initialSnapshot: snapshot,
            );
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundaryKey,
                child: _ScreenshotApp(
                  key: UniqueKey(),
                  cubit: captureCubit,
                  fallbackFamilies: _fallbackFamilies(code, fonts),
                ),
              ),
            );
            await _finishFrame(tester);
            final appContext = tester.element(find.byType(RawBarPage));
            final cubit = appContext.read<BarCubit>();
            final navigation = Navigator.of(appContext);
            String tr(String ru, String en) => appContext.tr(ru, en);

            Future<void> capture(String scene) async {
              await _finishFrame(tester);
              if (!scenes.contains(scene)) return;
              final renderingException = tester.takeException();
              expect(
                find.byType(StretchedDotsLoader).hitTestable(),
                findsNothing,
              );
              final locale = language['appStoreLocale'] as String;
              final relativePath = 'screenshots/$locale/$id/$scene.png';
              final file = File('${output.path}/$relativePath');
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await tester.runAsync(
                () => boundary.toImage(pixelRatio: dpr),
              );
              expect(image!.width, width);
              expect(image.height, height);
              final png = await tester.runAsync(
                () => image.toByteData(format: ui.ImageByteFormat.png),
              );
              image.dispose();
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(png!.buffer.asUint8List());
              expect(renderingException, isNull, reason: '$code/$id/$scene');
              captures.removeWhere((item) => item['path'] == relativePath);
              captures.add({
                'language': code,
                'locale': locale,
                'device': id,
                'screen': scene,
                'path': relativePath,
                'width': width,
                'height': height,
                'pixelRatio': dpr,
                'safeArea': safe,
                'renderer': 'flutter-widget',
                'nativeDeviceCapture': false,
                'fontFallback':
                    'offline Noto fixture replaces OS text fallback',
                if (id.startsWith('iphone-duo'))
                  'note':
                      'Offscreen responsive layout preview; not a Duo '
                      'simulator capture. Safe-area estimates require device QA.',
                'catalogCocktails': catalog.cocktails.length,
                'catalogIngredients': catalog.ingredients.length,
                'selectedIngredientCount':
                    cubit.state.selectedIngredientIds.length,
                if (scene == '03-recipe') 'servings': 4,
                if (scene == '07-almost-ready')
                  'availabilityFilter': 'missingOne',
              });
              manifestFile.parent.createSync(recursive: true);
              _atomicWriteManifest(
                manifestFile,
                const JsonEncoder.withIndent('  ').convert({
                  'schemaVersion': 1,
                  'renderer': 'flutter-widget',
                  'networkAccess': false,
                  'personalData': false,
                  'screenshots': captures,
                }),
              );
              debugPrint('Captured $relativePath ($width × $height)');
            }

            await tester.tap(find.byTooltip(tr('Фильтры', 'Filters')));
            await _finishFrame(tester);
            await tester.tap(find.text(tr('По наличию', 'By availability')));
            await tester.tap(find.text(tr('Применить', 'Apply')));
            await capture(_sceneNames[0]);
            await tester.tap(find.text(tr('Барная карта', 'Bar Menu')).last);
            await _finishFrame(tester);
            await tester.tap(find.byIcon(Icons.grid_view_rounded).last);
            await capture(_sceneNames[1]);
            if (scenes.contains(_sceneNames[6])) {
              final nearReadyCount = cubit.state.cocktails
                  .where(
                    (cocktail) =>
                        cubit.state.missingIngredientIdsFor(cocktail).length ==
                        1,
                  )
                  .length;
              expect(nearReadyCount, greaterThan(0));
              final almostReady = find.widgetWithIcon(
                ChoiceChip,
                Icons.looks_one_rounded,
              );
              final missingOneLabel = find.textContaining(
                tr('Не хватает 1', 'Missing 1'),
              );
              final filter = almostReady.evaluate().isNotEmpty
                  ? almostReady
                  : missingOneLabel;
              await tester.ensureVisible(filter);
              await tester.tap(filter);
              await _finishFrame(tester);
              expect(tester.widget<ChoiceChip>(almostReady).selected, isTrue);
              await capture(_sceneNames[6]);
            }

            final state = cubit.state;
            final mojito = state.cocktails.firstWhere(
              (item) => item.id == 'mojito',
            );
            // Real production routes, no screenshot-specific UI substitutions.
            if (scenes.contains(_sceneNames[2])) {
              navigation.push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CocktailDetailsPage(
                    cocktail: mojito,
                    missingIngredientNames: const [],
                    ingredientsById: state.ingredientsById,
                    visitorMode: false,
                    measurementSystem: MeasurementSystem.ml,
                    onEditCocktailPressed: (_) async {},
                    onToggleFavoritePressed: (_) {},
                  ),
                ),
              );
              await _finishFrame(tester);
              final increase = find.byTooltip(tr('Увеличить', 'Increase'));
              await Scrollable.ensureVisible(
                tester.element(increase),
                alignment: .48,
                duration: Duration.zero,
              );
              for (var count = 0; count < 3; count++) {
                await tester.tap(increase);
                await tester.pump(const Duration(milliseconds: 250));
              }
              await capture(_sceneNames[2]);
              navigation.pop();
              await _finishFrame(tester);
            }

            final missing = <String, Set<String>>{
              for (final cocktail in state.cocktails)
                cocktail.id: state.missingIngredientIdsFor(cocktail),
            };
            if (scenes.contains(_sceneNames[3])) {
              navigation.push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => PartyModePage(
                    cocktails: state.cocktails,
                    ingredientsById: state.ingredientsById,
                    missingIngredientIdsByCocktailId: missing,
                    measurementSystem: MeasurementSystem.ml,
                    powerSavingMode: false,
                    readOnly: false,
                    onAddShoppingIngredients: cubit.addShoppingIngredients,
                  ),
                ),
              );
              await _finishFrame(tester);
              await tester.tap(find.byType(CheckboxListTile).first);
              await _finishFrame(tester);
              for (var extraServing = 0; extraServing < 3; extraServing++) {
                await tester.tap(
                  find
                      .byTooltip(tr('Увеличить', 'Increase'))
                      .hitTestable()
                      .first,
                );
                await tester.pump(const Duration(milliseconds: 250));
              }
              await tester.tap(find.byType(CheckboxListTile).at(1));
              await capture(_sceneNames[3]);
              navigation.pop();
              await _finishFrame(tester);
            }

            if (scenes.contains(_sceneNames[4])) {
              await tester.tap(
                find.byTooltip(tr('Список покупок', 'Shopping list')),
              );
              await capture(_sceneNames[4]);
              navigation.pop();
              await _finishFrame(tester);
            }

            if (scenes.contains(_sceneNames[5])) {
              navigation.push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => SurpriseCocktailPage(
                    cocktails: state.cocktails,
                    initialCocktailId: mojito.id,
                    missingIngredientsByCocktailId: {
                      for (final entry in missing.entries)
                        entry.key: entry.value
                            .map((id) => state.ingredientsById[id]!.name)
                            .toList(),
                    },
                    ingredientsById: state.ingredientsById,
                    visitorMode: false,
                    measurementSystem: MeasurementSystem.ml,
                    powerSavingMode: false,
                    onEditCocktailPressed: (_) async {},
                    onToggleFavoritePressed: (_) {},
                  ),
                ),
              );
              await capture(_sceneNames[5]);
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await captureCubit.close();
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
          }
        }
      } finally {
        debugDisableShadows = oldDisableShadows;
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: outputPath == null,
    timeout: const Timeout(Duration(minutes: 45)),
  );
}

List<Map<String, dynamic>> _select(List source, String? selection, String key) {
  final items = source.map((item) => Map<String, dynamic>.from(item as Map));
  final requested = selection
      ?.split(',')
      .where((item) => item.isNotEmpty)
      .toSet();
  if (requested == null || requested.isEmpty) return items.toList();
  final matches = items.where((item) => requested.contains(item[key])).toList();
  if (matches.length != requested.length) {
    throw FormatException('Unknown $key selection: $selection');
  }
  return matches;
}

List<_OfflineFont> _readFonts(
  Map<String, dynamic> config,
  Directory configDir,
) {
  var configured = config['fonts'] as List?;
  if (configured == null || configured.isEmpty) {
    final sources = File('${configDir.path}/font_sources.json');
    if (sources.existsSync()) {
      configured =
          (jsonDecode(sources.readAsStringSync()) as Map)['fonts'] as List;
    }
  }
  final fonts = <_OfflineFont>[];
  if (configured != null && configured.isNotEmpty) {
    for (final entry in configured) {
      final font = Map<String, dynamic>.from(entry as Map);
      final rawPath = font['path'] as String;
      final absolute = rawPath.startsWith('/')
          ? File(rawPath)
          : File('${configDir.path}/$rawPath');
      fonts.add(_OfflineFont(font['family'] as String, absolute));
    }
  } else {
    for (final file in Directory('${configDir.path}/fonts').listSync()) {
      if (file is File && RegExp(r'\.(ttf|otf)$').hasMatch(file.path)) {
        final family = file.uri.pathSegments.last.split(RegExp(r'[-\[]')).first;
        fonts.add(_OfflineFont(family, file));
      }
    }
  }
  for (final family in ['Manrope', 'Orbitron']) {
    if (!fonts.any((font) => font.family == family)) {
      throw StateError('Missing offline $family font in store-asset config.');
    }
  }
  return fonts;
}

class _OfflineFont {
  _OfflineFont(this.family, this.file);
  final String family;
  final File file;
  Uint8List get bytes => file.readAsBytesSync();
}

List<String> _fallbackFamilies(String code, List<_OfflineFont> fonts) => [
  'Manrope',
  if (code == 'ja') 'NotoSansJP',
  if (code == 'ko') 'NotoSansKR',
  if (code == 'zh') 'NotoSansSC',
  if (code == 'ar') 'NotoSansArabic',
  if (code == 'hi') 'NotoSansDevanagari',
  ...fonts
      .map((font) => font.family)
      .where((family) => family != 'Manrope' && family != 'Orbitron'),
];

/// The production shell, routes, theme and state with isolated demonstration
/// storage. Widget tests have no iOS system font fallback, so explicitly provide
/// offline script fonts in place of that OS service; no screen is recreated.
class _ScreenshotApp extends StatelessWidget {
  const _ScreenshotApp({
    required this.cubit,
    required this.fallbackFamilies,
    super.key,
  });

  final BarCubit cubit;
  final List<String> fallbackFamilies;

  @override
  Widget build(BuildContext context) {
    final original = AppTheme.dark;
    return BlocProvider.value(
      value: cubit,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: cubit.state.appLanguage.locale,
        supportedLocales: AppLanguageX.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: original.copyWith(
          textTheme: original.textTheme.apply(
            fontFamilyFallback: fallbackFamilies,
          ),
          primaryTextTheme: original.primaryTextTheme.apply(
            fontFamilyFallback: fallbackFamilies,
          ),
          tooltipTheme: original.tooltipTheme.copyWith(
            textStyle: original.tooltipTheme.textStyle?.copyWith(
              fontFamilyFallback: fallbackFamilies,
            ),
          ),
        ),
        home: const BarHomeShell(),
      ),
    );
  }
}

Future<void> _installOfflineAssets(
  WidgetTester tester,
  List<_OfflineFont> fonts,
) async {
  final virtualFonts = <String, File>{};
  for (final family in ['Manrope', 'Orbitron']) {
    final file = fonts.firstWhere((font) => font.family == family).file;
    for (final variant in [
      'Thin',
      'ExtraLight',
      'Light',
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ]) {
      virtualFonts['store-fonts/$family-$variant.ttf'] = file;
    }
  }
  final originalManifest = await rootBundle.load('AssetManifest.bin');
  final manifest = Map<Object?, Object?>.from(
    const StandardMessageCodec().decodeMessage(originalManifest) as Map,
  );
  for (final path in virtualFonts.keys) {
    manifest[path] = [
      <String, Object>{'asset': path},
    ];
  }
  final encodedManifest = const StandardMessageCodec().encodeMessage(manifest)!;
  tester.binding.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (data) async {
      final asset = utf8.decode(data!.buffer.asUint8List());
      if (asset == 'AssetManifest.bin') return encodedManifest;
      final font = virtualFonts[asset];
      if (font != null) return ByteData.sublistView(font.readAsBytesSync());
      final file = File('build/unit_test_assets/$asset');
      if (!file.existsSync()) {
        throw FlutterError('Missing offline asset: $asset');
      }
      return ByteData.sublistView(file.readAsBytesSync());
    },
  );
}

Future<void> _loadFonts(List<_OfflineFont> fonts) async {
  // Flutter widget tests otherwise install Ahem. Register the real app faces
  // plus script fonts under every inherited family used by production widgets.
  final manrope = fonts.firstWhere((font) => font.family == 'Manrope');
  for (final font in [
    ...fonts,
    _OfflineFont('Roboto', manrope.file),
    _OfflineFont('.SF UI Text', manrope.file),
    _OfflineFont('.SF UI Display', manrope.file),
  ]) {
    final loader = FontLoader(font.family)
      ..addFont(Future.value(ByteData.sublistView(font.bytes)));
    await loader.load();
  }
  final iconFont = File(
    'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
  );
  final material = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(iconFont.readAsBytesSync())));
  await material.load();
}

Future<void> _finishFrame(WidgetTester tester) async {
  // Fixed animation time makes animated gradients repeatable, unlike
  // pumpAndSettle (production has intentionally continuous decorative effects).
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  // Image decode is real asynchronous engine work; complete before encoding PNG.
  final images = find
      .byType(BarNetworkImage)
      .evaluate()
      .where(
        (element) =>
            (element.widget as BarNetworkImage).imageUrl.startsWith('assets/'),
      );
  await tester.runAsync(() async {
    await Future.wait([
      for (final element in images)
        precacheImage(
          AssetImage((element.widget as BarNetworkImage).imageUrl),
          element,
        ),
    ]);
  });
  await tester.pump(const Duration(milliseconds: 100));
}

class _OfflineOnlyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Store screenshot capture is strictly offline.');
}

void _atomicWriteManifest(File destination, String contents) {
  destination.parent.createSync(recursive: true);
  final unique =
      '$pid-${DateTime.now().microsecondsSinceEpoch}-'
      '${math.Random.secure().nextInt(0x7FFFFFFF).toRadixString(16)}';
  final temporary = File('${destination.path}.tmp-$unique');
  temporary.createSync(exclusive: true);
  try {
    temporary.writeAsStringSync(contents, flush: true);
    temporary.renameSync(destination.path);
  } finally {
    if (temporary.existsSync()) temporary.deleteSync();
  }
}
