import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/app_theme.dart';
import '../features/bar/cubit/bar_cubit.dart';
import '../features/bar/data/bar_ui_settings_storage.dart';
import '../features/bar/data/ingredient_selection_storage.dart';
import '../features/bar/data/models/catalog_layer_models.dart';
import '../features/bar/data/providers/external_bar_data_provider.dart';
import '../features/bar/data/repositories/bar_catalog_repository.dart';
import '../features/bar/presentation/bar_home_shell.dart';

class MyBarApp extends StatelessWidget {
  const MyBarApp({
    required this.selectionStorage,
    required this.settingsStorage,
    required this.catalogRepository,
    required this.externalProviderSelector,
    required this.initialSnapshot,
    super.key,
  });

  final IngredientSelectionStorage selectionStorage;
  final BarUiSettingsStorage settingsStorage;
  final BarCatalogRepository catalogRepository;
  final SelectableExternalBarDataProvider externalProviderSelector;
  final UnifiedCatalogSnapshot initialSnapshot;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BarCubit>(
      create: (_) => BarCubit(
        selectionStorage: selectionStorage,
        settingsStorage: settingsStorage,
        catalogRepository: catalogRepository,
        externalProviderSelector: externalProviderSelector,
        initialSnapshot: initialSnapshot,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Мой Бар',
        theme: AppTheme.dark,
        home: const BarHomeShell(),
      ),
    );
  }
}
