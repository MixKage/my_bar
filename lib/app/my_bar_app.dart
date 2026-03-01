import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/app_theme.dart';
import '../features/bar/cubit/bar_cubit.dart';
import '../features/bar/data/bar_catalog_storage.dart';
import '../features/bar/data/ingredient_selection_storage.dart';
import '../features/bar/domain/models/bar_catalog.dart';
import '../features/bar/presentation/bar_home_shell.dart';

class MyBarApp extends StatelessWidget {
  const MyBarApp({
    required this.selectionStorage,
    required this.catalogStorage,
    required this.initialCatalog,
    required this.templateCatalog,
    super.key,
  });

  final IngredientSelectionStorage selectionStorage;
  final BarCatalogStorage catalogStorage;
  final BarCatalog initialCatalog;
  final BarCatalog templateCatalog;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BarCubit>(
      create: (_) => BarCubit(
        selectionStorage: selectionStorage,
        catalogStorage: catalogStorage,
        initialCatalog: initialCatalog,
        templateCatalog: templateCatalog,
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
