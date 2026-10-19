import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_bar/core/localization/app_language.dart';
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
import 'package:my_bar/features/bar/domain/models/ingredient.dart';
import 'package:my_bar/features/bar/presentation/bar_home_shell.dart';
import 'package:my_bar/features/bar/presentation/pages/cocktail_editor_page.dart';
import 'package:my_bar/features/bar/presentation/widgets/bar_management_dialogs.dart';

const _ingredient = Ingredient(
  id: 'gin',
  name: 'Gin',
  category: 'Spirits',
  image: '/photos/original.jpg',
);

void main() {
  late FilePickerPlatform originalPlatform;
  late _PickerPlatform picker;

  setUp(() {
    originalPlatform = FilePickerPlatform.instance;
    picker = _PickerPlatform();
    FilePickerPlatform.instance = picker;
  });

  tearDown(() {
    FilePickerPlatform.instance = originalPlatform;
  });

  testWidgets('cocktail editor picks an image and preserves it on cancel', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      const CocktailEditorPage.create(ingredients: [_ingredient]),
    );
    final photoField = _photoField();
    await tester.enterText(photoField, '/photos/original.jpg');

    picker.result = _PickedFile(uri: Uri.file('/photos/cocktail.jpg'));
    await tester.ensureVisible(find.text('Pick from device'));
    await tester.tap(find.text('Pick from device'));
    await tester.pumpAndSettle();

    expect(picker.types, [FileType.image]);
    expect(_fieldText(tester, photoField), '/photos/cocktail.jpg');

    picker.result = null;
    await tester.tap(find.text('Pick from device'));
    await tester.pumpAndSettle();

    expect(picker.types, [FileType.image, FileType.image]);
    expect(_fieldText(tester, photoField), '/photos/cocktail.jpg');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ingredient dialog cancels safely and saves the selected photo', (
    tester,
  ) async {
    AddIngredientInput? saved;
    await _pumpPage(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              saved = await showEditIngredientDialog(
                context,
                ingredient: _ingredient,
              );
            },
            child: const Text('Open ingredient'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open ingredient'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pick from device'));
    await tester.pumpAndSettle();
    expect(_fieldText(tester, _photoField()), '/photos/original.jpg');

    picker.result = _PickedFile(uri: Uri.file('/photos/ingredient.jpg'));
    await tester.tap(find.text('Pick from device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(picker.types, [FileType.image, FileType.image]);
    expect(saved?.image, '/photos/ingredient.jpg');
    expect(saved?.name, 'Gin');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'catalog import reads UTF-8 bytes without requiring a local path',
    (tester) async {
      final file = _PickedFile(
        // A picker can expose a document URI instead of an on-disk path.
        uri: Uri.parse('content://documents/bar.json'),
        bytes: Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'ingredients': [
                {
                  'id': 'lemon',
                  'name': 'Лимон',
                  'category': 'Fruit',
                  'image': '',
                },
              ],
              'cocktails': <Object>[],
            }),
          ),
        ),
      );
      picker.result = file;
      final cubit = await _pumpShell(tester);

      await _openImport(tester);

      expect(file.path, isNull);
      expect(file.reads, 1);
      expect(picker.types, [FileType.custom]);
      expect(picker.extensions, [
        <String>['json'],
      ]);
      expect(
        cubit.state.ingredients.map((item) => item.name),
        contains('Лимон'),
      );
      expect(find.text('Bar catalog imported'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canceling catalog import leaves the catalog unchanged', (
    tester,
  ) async {
    final cubit = await _pumpShell(tester);
    final initialIngredients = cubit.state.ingredients;

    await _openImport(tester);

    expect(picker.types, [FileType.custom]);
    expect(picker.extensions, [
      <String>['json'],
    ]);
    expect(cubit.state.ingredients, initialIngredients);
    expect(find.text('Bar catalog imported'), findsNothing);
    expect(find.textContaining('Failed to import file:'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Finder _photoField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.hintText == 'https://... or /storage/.../photo.jpg',
);

String _fieldText(WidgetTester tester, Finder finder) =>
    tester.widget<TextField>(finder).controller!.text;

Future<void> _pumpPage(
  WidgetTester tester,
  Widget home, {
  BarCubit? cubit,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1100);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final app = MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: home,
  );
  await tester.pumpWidget(
    cubit == null ? app : BlocProvider.value(value: cubit, child: app),
  );
  await tester.pumpAndSettle();
}

Future<BarCubit> _pumpShell(WidgetTester tester) async {
  final catalog = BarCatalog(ingredients: [_ingredient], cocktails: []);
  final provider = _CatalogProvider(catalog);
  final selector = SelectableExternalBarDataProvider(
    seedProvider: provider,
    bootstrapDefaultProvider: provider,
    bootstrapDefaultDataSource: CatalogDataSource.seed,
  );
  final repository = BarCatalogRepository(
    externalProvider: selector,
    externalCacheStorage: InMemoryExternalCatalogCacheStorage(),
    localStorage: InMemoryLocalCatalogStorage(),
    overridesStorage: InMemoryCatalogOverridesStorage(),
    templateCatalog: catalog,
  );
  final cubit = BarCubit(
    selectionStorage: InMemoryIngredientSelectionStorage(),
    shoppingListStorage: InMemoryShoppingListStorage(),
    settingsStorage: InMemoryBarUiSettingsStorage(
      initial: const BarUiSettings(
        appLanguage: AppLanguage.english,
        powerSavingMode: true,
      ),
    ),
    catalogRepository: repository,
    externalProviderSelector: selector,
    initialSnapshot: await repository.initialize(),
  );
  addTearDown(cubit.close);
  await _pumpPage(tester, const BarHomeShell(), cubit: cubit);
  return cubit;
}

Future<void> _openImport(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Bar management'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Import bar catalog'));
  await tester.tap(find.text('Import bar catalog'));
  await tester.pumpAndSettle();
}

class _PickerPlatform extends FilePickerPlatform {
  PlatformFile? result;
  final types = <FileType>[];
  final extensions = <List<String>?>[];

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    types.add(type);
    extensions.add(allowedExtensions);
    return result;
  }
}

final class _PickedFile extends PlatformFile {
  _PickedFile({required this.uri, Uint8List? bytes})
    : _bytes = bytes ?? Uint8List(0);

  @override
  final Uri uri;
  final Uint8List _bytes;
  int reads = 0;

  @override
  String get name => uri.pathSegments.last;

  @override
  Never get xFile => throw UnimplementedError('Not needed by these pickers');

  @override
  int lengthSync() => _bytes.length;

  @override
  Future<int> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    return _bytes;
  }

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}

class _CatalogProvider implements ExternalBarDataProvider {
  _CatalogProvider(this.catalog);

  final BarCatalog catalog;

  @override
  String get sourceId => 'picker_test';

  @override
  ExternalProviderFormat get format => ExternalProviderFormat.generic;

  @override
  Future<List<Map<String, dynamic>>> fetchIngredients() async =>
      catalog.ingredients.map((item) => item.toJson()).toList();

  @override
  Future<List<Map<String, dynamic>>> fetchCocktails() async =>
      catalog.cocktails.map((item) => item.toJson()).toList();
}
