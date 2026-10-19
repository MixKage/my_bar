import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/localization/app_language.dart';
import '../core/localization/app_localization.dart';
import '../core/reviews/review_prompt_controller.dart';
import '../core/reviews/review_prompt_coordinator.dart';
import '../core/theme/app_theme.dart';
import '../features/bar/cubit/bar_cubit.dart';
import '../features/bar/cubit/bar_state.dart';
import '../features/bar/data/bar_ui_settings_storage.dart';
import '../features/bar/data/ingredient_selection_storage.dart';
import '../features/bar/data/models/catalog_layer_models.dart';
import '../features/bar/data/providers/external_bar_data_provider.dart';
import '../features/bar/data/repositories/bar_catalog_repository.dart';
import '../features/bar/data/shopping_list_storage.dart';
import '../features/bar/presentation/bar_home_shell.dart';
import '../features/bar/data/onboarding_storage.dart';
import '../features/bar/presentation/pages/onboarding_page.dart';

class MyBarApp extends StatefulWidget {
  const MyBarApp({
    required this.onboardingStorage,
    required this.selectionStorage,
    required this.settingsStorage,
    required this.shoppingListStorage,
    required this.catalogRepository,
    required this.externalProviderSelector,
    required this.initialSnapshot,
    this.reviewPromptController,
    super.key,
  });

  final OnboardingStorage onboardingStorage;
  final IngredientSelectionStorage selectionStorage;
  final BarUiSettingsStorage settingsStorage;
  final ShoppingListStorage shoppingListStorage;
  final BarCatalogRepository catalogRepository;
  final SelectableExternalBarDataProvider externalProviderSelector;
  final UnifiedCatalogSnapshot initialSnapshot;

  /// Optional for previews/tests; the caller owns this controller's lifetime.
  final ReviewPromptController? reviewPromptController;

  @override
  State<MyBarApp> createState() => _MyBarAppState();
}

class _MyBarAppState extends State<MyBarApp> {
  final _reviewRouteObserver = RouteObserver<ModalRoute<dynamic>>();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BarCubit>(
      create: (_) => BarCubit(
        selectionStorage: widget.selectionStorage,
        settingsStorage: widget.settingsStorage,
        shoppingListStorage: widget.shoppingListStorage,
        catalogRepository: widget.catalogRepository,
        externalProviderSelector: widget.externalProviderSelector,
        initialSnapshot: widget.initialSnapshot,
      ),
      child: BlocBuilder<BarCubit, BarState>(
        buildWhen: (previous, current) =>
            previous.appLanguage != current.appLanguage ||
            previous.effectivePowerSavingMode !=
                current.effectivePowerSavingMode,
        builder: (context, state) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorObservers: [_reviewRouteObserver],
            locale: state.appLanguage.locale,
            supportedLocales: AppLanguageX.supportedLocales,
            localeListResolutionCallback: (locales, _) =>
                AppLanguageX.resolveLocale(locales),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            onGenerateTitle: (context) => context.tr('Мой Бар', 'My Bar'),
            theme: AppTheme.dark,
            home: OnboardingGate(
              storage: widget.onboardingStorage,
              powerSavingMode: state.effectivePowerSavingMode,
              child: widget.reviewPromptController == null
                  ? const BarHomeShell()
                  : ReviewPromptCoordinator(
                      controller: widget.reviewPromptController!,
                      routeObserver: _reviewRouteObserver,
                      child: BarHomeShell(
                        reviewPromptController: widget.reviewPromptController,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
