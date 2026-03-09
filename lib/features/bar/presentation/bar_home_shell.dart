import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:animated_border_widgets/animated_border_widgets.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_localization.dart';
import '../cubit/bar_cubit.dart';
import '../data/bar_catalog_json_codec.dart';
import '../domain/models/cocktail.dart';
import '../domain/models/ingredient.dart';
import '../domain/models/measurement_system.dart';
import 'pages/cocktail_editor_page.dart';
import 'pages/bar_menu_page.dart';
import 'pages/raw_bar_page.dart';
import 'widgets/bar_management_dialogs.dart';
import 'widgets/neon_bottom_navigation.dart';

class BarHomeShell extends StatefulWidget {
  const BarHomeShell({super.key});

  @override
  State<BarHomeShell> createState() => _BarHomeShellState();
}

class _BarHomeShellState extends State<BarHomeShell>
    with WidgetsBindingObserver {
  static const _jsonCodec = BarCatalogJsonCodec();
  static final Uri _developerSiteUri = Uri.parse('https://logion-web.ru/');
  static const double _hiddenSideToggleVisibleFraction = 1 / 3;

  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  int _currentTab = 0;
  String _appVersionLabel = '...';
  bool _isSideNavigationVisible = true;
  bool _isSyncingSystemPowerMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncSystemPowerSavingMode();
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((_) {
      _syncSystemPowerSavingMode();
    });
    _loadAppVersion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _batteryStateSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncSystemPowerSavingMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BarCubit>().state;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final showOnlyBarMenu = state.barMenuOnlyMode;
    final powerSavingMode = state.effectivePowerSavingMode;
    final useSideNavigation =
        !showOnlyBarMenu && useLandscapeSideNavigation(context);
    final showSideNavigation = useSideNavigation && _isSideNavigationVisible;
    final showBottomNavigation = !showOnlyBarMenu && !useSideNavigation;
    final bottomOverlayPadding = showBottomNavigation
        ? kNeonBottomNavigationHeight +
              kNeonBottomNavigationBottomMargin +
              bottomInset
        : bottomInset;

    final pages = showOnlyBarMenu
        ? <Widget>[
            BarMenuPage(
              cocktails: state.cocktails,
              selectedIngredientIds: state.selectedIngredientIds,
              ingredientsById: state.ingredientsById,
              visitorMode: state.visitorMode,
              measurementSystem: state.measurementSystem,
              powerSavingMode: powerSavingMode,
              bottomOverlayPadding: bottomOverlayPadding,
              onManagePressed: () => _openBarManagement(),
              onEditCocktailPressed: _handleEditCocktail,
              onToggleFavoritePressed: _toggleFavorite,
            ),
          ]
        : <Widget>[
            RawBarPage(
              ingredients: state.ingredients,
              cocktails: state.cocktails,
              selectedIngredientIds: state.selectedIngredientIds,
              allowSelection: !state.visitorMode,
              powerSavingMode: powerSavingMode,
              bottomOverlayPadding: bottomOverlayPadding,
              onToggleIngredient: (id) => _toggleIngredient(id),
              onEditIngredient: _handleEditIngredient,
              onManagePressed: () => _openBarManagement(),
            ),
            BarMenuPage(
              cocktails: state.cocktails,
              selectedIngredientIds: state.selectedIngredientIds,
              ingredientsById: state.ingredientsById,
              visitorMode: state.visitorMode,
              measurementSystem: state.measurementSystem,
              powerSavingMode: powerSavingMode,
              bottomOverlayPadding: bottomOverlayPadding,
              onManagePressed: () => _openBarManagement(),
              onEditCocktailPressed: _handleEditCocktail,
              onToggleFavoritePressed: _toggleFavorite,
            ),
          ];

    final currentIndex = showOnlyBarMenu ? 0 : _currentTab;
    final pageStack = IndexedStack(index: currentIndex, children: pages);
    final bodyContent = useSideNavigation
        ? Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: showSideNavigation ? kNeonSideNavigationWidth + 30 : 0,
                child: showSideNavigation
                    ? GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          if (details.delta.dx < -10) {
                            _setSideNavigationVisibility(false);
                          }
                        },
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity < -260) {
                            _setSideNavigationVisibility(false);
                          }
                        },
                        child: SafeArea(
                          right: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                            child: Column(
                              children: <Widget>[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _SideNavigationToggleHandle(
                                    tooltip: context.tr(
                                      'Скрыть меню',
                                      'Hide menu',
                                    ),
                                    icon: Icons
                                        .keyboard_double_arrow_left_rounded,
                                    onPressed: () {
                                      _setSideNavigationVisibility(false);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: NeonSideNavigation(
                                      currentIndex: currentIndex,
                                      powerSavingMode: powerSavingMode,
                                      onChanged: (index) =>
                                          setState(() => _currentTab = index),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              Expanded(child: pageStack),
            ],
          )
        : pageStack;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            bodyContent,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + 88,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        const Color(0xFF7D4BFF).withValues(alpha: 0.65),
                        const Color(0xFF7D4BFF).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (useSideNavigation && !showSideNavigation)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 30,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    if (details.delta.dx > 10) {
                      _setSideNavigationVisibility(true);
                    }
                  },
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 260) {
                      _setSideNavigationVisibility(true);
                    }
                  },
                ),
              ),
            if (useSideNavigation && !showSideNavigation)
              Positioned(
                left:
                    -_SideNavigationToggleHandle.size *
                    (1 - _hiddenSideToggleVisibleFraction),
                top: topInset + 88,
                child: _SideNavigationToggleHandle(
                  tooltip: context.tr('Показать меню', 'Show menu'),
                  icon: Icons.keyboard_double_arrow_right_rounded,
                  onPressed: () {
                    _setSideNavigationVisibility(true);
                  },
                ),
              ),
            if (showBottomNavigation)
              Align(
                alignment: Alignment.bottomCenter,
                child: NeonBottomNavigation(
                  currentIndex: currentIndex,
                  powerSavingMode: powerSavingMode,
                  onChanged: (index) => setState(() => _currentTab = index),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _setSideNavigationVisibility(bool visible) {
    if (!mounted || _isSideNavigationVisible == visible) {
      return;
    }
    setState(() => _isSideNavigationVisible = visible);
  }

  Future<void> _toggleIngredient(String id) {
    return context.read<BarCubit>().toggleIngredient(id);
  }

  Future<void> _toggleFavorite(String cocktailId) {
    return context.read<BarCubit>().toggleCocktailFavorite(cocktailId);
  }

  Future<void> _openBarManagement() async {
    final action = await _showAdaptiveActionSheet<_BarManagementAction>(
      maxDialogWidth: 420,
      builder: (context) {
        final isVisitorMode = context.read<BarCubit>().state.visitorMode;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!isVisitorMode) ...<Widget>[
                  ListTile(
                    leading: const Icon(Icons.add_box_rounded),
                    title: Text(
                      context.tr('Добавить ингредиент', 'Add ingredient'),
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      _BarManagementAction.addIngredient,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.local_bar_rounded),
                    title: Text(
                      context.tr('Добавить коктейль', 'Add cocktail'),
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      _BarManagementAction.addCocktail,
                    ),
                  ),
                  const Divider(height: 22),
                ],
                ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: Text(context.tr('Настройки', 'Settings')),
                  onTap: () =>
                      Navigator.pop(context, _BarManagementAction.settings),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(context.tr('О приложении', 'About app')),
                  onTap: () =>
                      Navigator.pop(context, _BarManagementAction.about),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _BarManagementAction.addIngredient:
        await _handleAddIngredient();
      case _BarManagementAction.addCocktail:
        await _handleAddCocktail();
      case _BarManagementAction.settings:
        await _openSettings();
      case _BarManagementAction.about:
        _showAbout();
    }
  }

  Future<void> _openSettings() async {
    final cubit = context.read<BarCubit>();
    var visitorMode = cubit.state.visitorMode;
    var barMenuOnlyMode = cubit.state.barMenuOnlyMode;
    var powerSavingMode = cubit.state.powerSavingMode;
    final systemPowerSavingMode = cubit.state.systemPowerSavingMode;
    var appLanguage = cubit.state.appLanguage;
    var measurementSystem = cubit.state.measurementSystem;

    final action = await _showAdaptiveActionSheet<_BarSettingsAction>(
      maxDialogWidth: 640,
      builder: (context) {
        final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.82;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ListTile(
                            leading: const Icon(Icons.settings_suggest_rounded),
                            title: Text(
                              context.tr(
                                'Настройки барной карты',
                                'Bar card settings',
                              ),
                            ),
                          ),
                          SwitchListTile.adaptive(
                            value: visitorMode,
                            activeThumbColor: const Color(0xFF8FA3FF),
                            title: Text(
                              context.tr('Режим посетителя', 'Visitor mode'),
                            ),
                            subtitle: Text(
                              context.tr(
                                'Скрывает кнопки с редактированием',
                                'Hides editing controls',
                              ),
                            ),
                            onChanged: (value) async {
                              setModalState(() => visitorMode = value);
                              await cubit.setVisitorMode(value);
                            },
                          ),
                          SwitchListTile.adaptive(
                            value: barMenuOnlyMode,
                            activeThumbColor: const Color(0xFF8FA3FF),
                            title: Text(
                              context.tr(
                                'Режим барной карты',
                                'Bar card only mode',
                              ),
                            ),
                            subtitle: Text(
                              context.tr(
                                'Показывает только страницу "Барная карта"',
                                'Shows only the "Bar Menu" page',
                              ),
                            ),
                            onChanged: (value) async {
                              setModalState(() => barMenuOnlyMode = value);
                              await cubit.setBarMenuOnlyMode(value);
                              if (value && mounted) {
                                setState(() => _currentTab = 1);
                              }
                            },
                          ),
                          SwitchListTile.adaptive(
                            value: powerSavingMode || systemPowerSavingMode,
                            activeThumbColor: const Color(0xFF8FA3FF),
                            title: Text(
                              context.tr(
                                'Режим экономии энергии',
                                'Power saving mode',
                              ),
                            ),
                            subtitle: Text(
                              systemPowerSavingMode
                                  ? context.tr(
                                      'Активирован системным энергосбережением устройства.',
                                      'Enabled by the device system power saving mode.',
                                    )
                                  : context.tr(
                                      'Упрощает эффекты интерфейса (blur, glow, анимации) для снижения нагрева и расхода батареи.',
                                      'Reduces heavy UI effects (blur, glow, animations) to lower heat and battery usage.',
                                    ),
                            ),
                            onChanged: systemPowerSavingMode
                                ? null
                                : (value) async {
                                    setModalState(
                                      () => powerSavingMode = value,
                                    );
                                    await cubit.setPowerSavingMode(value);
                                  },
                          ),
                          const Divider(height: 16),
                          ListTile(
                            leading: const Icon(Icons.language_rounded),
                            title: Text(context.tr('Язык', 'Language')),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                            child: SegmentedButton<AppLanguage>(
                              showSelectedIcon: false,
                              selected: <AppLanguage>{appLanguage},
                              segments: <ButtonSegment<AppLanguage>>[
                                ButtonSegment<AppLanguage>(
                                  value: AppLanguage.system,
                                  label: Text(
                                    context.appLanguageLabel(
                                      AppLanguage.system,
                                    ),
                                  ),
                                ),
                                ButtonSegment<AppLanguage>(
                                  value: AppLanguage.russian,
                                  label: Text(
                                    context.appLanguageLabel(
                                      AppLanguage.russian,
                                    ),
                                  ),
                                ),
                                ButtonSegment<AppLanguage>(
                                  value: AppLanguage.english,
                                  label: Text(
                                    context.appLanguageLabel(
                                      AppLanguage.english,
                                    ),
                                  ),
                                ),
                              ],
                              onSelectionChanged: (selection) async {
                                if (selection.isEmpty) {
                                  return;
                                }
                                final nextLanguage = selection.first;
                                setModalState(() => appLanguage = nextLanguage);
                                await cubit.setAppLanguage(nextLanguage);
                                if (!mounted) {
                                  return;
                                }
                                setModalState(
                                  () => appLanguage = cubit.state.appLanguage,
                                );
                              },
                            ),
                          ),
                          ListTile(
                            dense: true,
                            title: Text(context.appLanguageLabel(appLanguage)),
                            subtitle: Text(
                              appLanguage == AppLanguage.system
                                  ? context.tr(
                                      'По умолчанию определяется системным языком устройства.',
                                      'By default uses the device system language.',
                                    )
                                  : context.tr(
                                      'Выбор сохраняется между запусками приложения.',
                                      'Selection is preserved between app launches.',
                                    ),
                            ),
                          ),
                          const Divider(height: 16),
                          ListTile(
                            leading: const Icon(Icons.straighten_rounded),
                            title: Text(
                              context.tr(
                                'Система измерения',
                                'Measurement system',
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                            child: SegmentedButton<MeasurementSystem>(
                              showSelectedIcon: false,
                              selected: <MeasurementSystem>{measurementSystem},
                              segments: <ButtonSegment<MeasurementSystem>>[
                                ButtonSegment<MeasurementSystem>(
                                  value: MeasurementSystem.flOz,
                                  label: Text(
                                    context.measurementSystemLabel(
                                      MeasurementSystem.flOz,
                                    ),
                                  ),
                                ),
                                ButtonSegment<MeasurementSystem>(
                                  value: MeasurementSystem.ml,
                                  label: Text(
                                    context.measurementSystemLabel(
                                      MeasurementSystem.ml,
                                    ),
                                  ),
                                ),
                                ButtonSegment<MeasurementSystem>(
                                  value: MeasurementSystem.cl,
                                  label: Text(
                                    context.measurementSystemLabel(
                                      MeasurementSystem.cl,
                                    ),
                                  ),
                                ),
                              ],
                              onSelectionChanged: (selection) async {
                                if (selection.isEmpty) {
                                  return;
                                }
                                final nextSystem = selection.first;
                                setModalState(
                                  () => measurementSystem = nextSystem,
                                );
                                await cubit.setMeasurementSystem(nextSystem);
                                if (!mounted) {
                                  return;
                                }
                                setModalState(
                                  () => measurementSystem =
                                      cubit.state.measurementSystem,
                                );
                              },
                            ),
                          ),
                          ListTile(
                            dense: true,
                            title: Text(
                              context.measurementSystemLabel(measurementSystem),
                            ),
                            subtitle: Text(
                              context.tr(
                                'Объёмные единицы в составе коктейлей конвертируются автоматически.',
                                'Volume units in ingredients are converted automatically.',
                              ),
                            ),
                          ),
                          const Divider(height: 16),
                          ListTile(
                            leading: const Icon(Icons.upload_file_rounded),
                            title: Text(
                              context.tr(
                                'Импортировать барную карту',
                                'Import bar catalog',
                              ),
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              _BarSettingsAction.import,
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.download_rounded),
                            title: Text(
                              context.tr(
                                'Экспортировать барную карту',
                                'Export bar catalog',
                              ),
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              _BarSettingsAction.export,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _BarSettingsAction.import:
        await _handleImport();
      case _BarSettingsAction.export:
        await _handleExport();
    }
  }

  Future<T?> _showAdaptiveActionSheet<T>({
    required WidgetBuilder builder,
    required double maxDialogWidth,
  }) {
    if (isTabletLayout(context)) {
      return showDialog<T>(
        context: context,
        barrierColor: const Color(0xAA050711),
        builder: (dialogContext) {
          final maxDialogHeight =
              MediaQuery.sizeOf(dialogContext).height * 0.88;
          return Dialog(
            backgroundColor: const Color(0xFF161B2E),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxDialogWidth,
                maxHeight: maxDialogHeight,
              ),
              child: builder(dialogContext),
            ),
          );
        },
      );
    }
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: const Color(0xFF161B2E),
      showDragHandle: true,
      isScrollControlled: true,
      builder: builder,
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xAA050711),
      builder: (dialogContext) {
        final mediaSize = MediaQuery.sizeOf(dialogContext);
        final horizontalInset = isTabletLayout(dialogContext) ? 32.0 : 20.0;
        final availableWidth = mediaSize.width - (horizontalInset * 2);
        final targetWidth = availableWidth.clamp(320.0, 520.0).toDouble();
        final maxDialogHeight = mediaSize.height * 0.9;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: horizontalInset,
            vertical: 24,
          ),
          child: SizedBox(
            width: targetWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDialogHeight),
              child: AnimatedGradientBorder(
                borderRadius: BorderRadius.circular(28),
                borderWidth: 1.7,
                innerColor: const Color(0xFF101429),
                colors: const <Color>[
                  Color(0xFFB679FF),
                  Color(0xFF5BD4FF),
                  Color(0xFFFF8AC7),
                  Color(0xFFB679FF),
                ],
                glowEffect: true,
                glow: const AnimatedGradientBorderGlow(
                  opacity: 0.42,
                  outerBlurSigma: 16,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0x55B87BFF),
                              Color(0x5535C5FF),
                            ],
                          ),
                          border: Border.all(color: const Color(0x66C9A7FF)),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x66745AFF),
                              blurRadius: 18,
                              spreadRadius: 0.8,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/icon.png',
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: Icon(
                                    Icons.local_bar_rounded,
                                    size: 34,
                                    color: Color(0xFFD7DFFF),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: <Color>[
                              Color(0xFFFFA6D8),
                              Color(0xFF95D6FF),
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          context.tr('Мой Бар', 'My Bar'),
                          style: Theme.of(dialogContext).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.25,
                              ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          'Версия ${_appVersionLabel.isEmpty ? 'неизвестно' : _appVersionLabel}',
                          'Version ${_appVersionLabel.isEmpty ? 'unknown' : _appVersionLabel}',
                        ),
                        style: const TextStyle(
                          color: Color(0xFFAEC0F0),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr(
                          'Неоновый помощник для домашнего бара: отмечайте ингредиенты, находите доступные коктейли и настраивайте собственную барную карту.',
                          'Neon helper for your home bar: track ingredients, find available cocktails, and customize your bar catalog.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFD7DEF5),
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _PressableAboutButton(
                        onPressed: _openDeveloperSite,
                        icon: Icons.open_in_new_rounded,
                        label: context.tr(
                          'Сайт разработчика',
                          'Developer website',
                        ),
                        foregroundColor: const Color(0xFFCFE3FF),
                        backgroundColor: const Color(0x33121A38),
                        pressedBackgroundColor: const Color(0x551B2954),
                        borderColor: const Color(0x667C8DFF),
                      ),
                      const SizedBox(height: 10),
                      _PressableAboutButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icons.check_rounded,
                        label: context.tr('Понятно', 'OK'),
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF5C63FF),
                        pressedBackgroundColor: const Color(0xFF4D53D8),
                        glowColor: const Color(0x665C63FF),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleAddIngredient() async {
    final cubit = context.read<BarCubit>();
    final input = await showAddIngredientDialog(context);
    if (input == null || !mounted) {
      return;
    }

    try {
      await cubit.addIngredient(
        name: input.name,
        category: input.category,
        image: input.image,
        isDecoration: input.isDecoration,
        isOptional: input.isOptional,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(context.tr('Ингредиент добавлен', 'Ingredient added'));
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.localizeErrorMessage(error.message));
    }
  }

  Future<void> _syncSystemPowerSavingMode() async {
    if (!mounted || _isSyncingSystemPowerMode) {
      return;
    }
    _isSyncingSystemPowerMode = true;
    try {
      final enabled = await _battery.isInBatterySaveMode;
      if (!mounted) {
        return;
      }
      context.read<BarCubit>().setSystemPowerSavingMode(enabled);
    } catch (_) {
      if (!mounted) {
        return;
      }
      context.read<BarCubit>().setSystemPowerSavingMode(false);
    } finally {
      _isSyncingSystemPowerMode = false;
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final buildNumber = packageInfo.buildNumber.trim();
      final versionLabel = buildNumber.isEmpty
          ? packageInfo.version
          : '${packageInfo.version} (b: $buildNumber)';
      if (!mounted) {
        return;
      }
      setState(() => _appVersionLabel = versionLabel);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _appVersionLabel = '');
    }
  }

  Future<void> _openDeveloperSite() async {
    try {
      final launched = await launchUrl(
        _developerSiteUri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) {
        return;
      }
      if (!launched) {
        _showSnackBar(
          context.tr(
            'Не удалось открыть сайт разработчика',
            'Failed to open developer website',
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.tr(
          'Не удалось открыть сайт разработчика',
          'Failed to open developer website',
        ),
      );
    }
  }

  Future<void> _handleEditIngredient(Ingredient ingredient) async {
    final cubit = context.read<BarCubit>();
    final input = await showEditIngredientDialog(
      context,
      ingredient: ingredient,
    );
    if (input == null || !mounted) {
      return;
    }

    try {
      await cubit.updateIngredient(
        ingredientId: ingredient.id,
        name: input.name,
        category: input.category,
        image: input.image,
        isDecoration: input.isDecoration,
        isOptional: input.isOptional,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(context.tr('Ингредиент обновлён', 'Ingredient updated'));
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.localizeErrorMessage(error.message));
    }
  }

  Future<void> _handleAddCocktail() async {
    final cubit = context.read<BarCubit>();
    final ingredients = cubit.state.ingredients;
    if (ingredients.isEmpty) {
      _showSnackBar(
        context.tr(
          'Сначала добавь хотя бы один ингредиент',
          'Add at least one ingredient first',
        ),
      );
      return;
    }

    final input = await Navigator.of(context).push<AddCocktailInput>(
      MaterialPageRoute<AddCocktailInput>(
        builder: (_) => CocktailEditorPage.create(
          ingredients: ingredients,
          powerSavingMode: cubit.state.effectivePowerSavingMode,
        ),
      ),
    );
    if (input == null || !mounted) {
      return;
    }

    try {
      await cubit.addCocktail(
        name: input.name,
        description: input.description,
        preparationSteps: input.preparationSteps,
        image: input.image,
        glassType: input.glassType,
        ingredientIds: input.ingredientIds,
        ingredientSubstitutions: input.ingredientSubstitutions,
        ingredientAmounts: input.ingredientAmounts,
        ingredientUnits: input.ingredientUnits,
        optionalIngredientIds: input.optionalIngredientIds,
        decorationIngredientIds: input.decorationIngredientIds,
        tags: input.tags,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(context.tr('Коктейль добавлен', 'Cocktail added'));
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.localizeErrorMessage(error.message));
    }
  }

  Future<void> _handleEditCocktail(Cocktail cocktail) async {
    final cubit = context.read<BarCubit>();
    final input = await Navigator.of(context).push<AddCocktailInput>(
      MaterialPageRoute<AddCocktailInput>(
        builder: (_) => CocktailEditorPage.edit(
          ingredients: cubit.state.ingredients,
          initialCocktail: cocktail,
          powerSavingMode: cubit.state.effectivePowerSavingMode,
        ),
      ),
    );
    if (input == null || !mounted) {
      return;
    }

    try {
      await cubit.updateCocktail(
        cocktailId: cocktail.id,
        name: input.name,
        description: input.description,
        preparationSteps: input.preparationSteps,
        image: input.image,
        glassType: input.glassType,
        ingredientIds: input.ingredientIds,
        ingredientSubstitutions: input.ingredientSubstitutions,
        ingredientAmounts: input.ingredientAmounts,
        ingredientUnits: input.ingredientUnits,
        optionalIngredientIds: input.optionalIngredientIds,
        decorationIngredientIds: input.decorationIngredientIds,
        tags: input.tags,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(context.tr('Коктейль обновлён', 'Cocktail updated'));
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.localizeErrorMessage(error.message));
    }
  }

  Future<void> _handleImport() async {
    final cubit = context.read<BarCubit>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final content = await _readPickedFile(file);
      final catalog = _jsonCodec.decode(content);

      await cubit.importCatalog(catalog);
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.tr('Барная карта импортирована', 'Bar catalog imported'),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.tr(
          'Ошибка JSON: ${context.localizeErrorMessage(error.message)}',
          'JSON error: ${context.localizeErrorMessage(error.message)}',
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.tr(
          'Не удалось импортировать файл: $error',
          'Failed to import file: $error',
        ),
      );
    }
  }

  Future<void> _handleExport() async {
    final cubit = context.read<BarCubit>();
    try {
      final catalog = cubit.exportCatalog();
      final payload = _jsonCodec.encode(catalog);
      final file = await _writeExportFile(payload);
      if (!mounted) {
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: context.tr(
            'Экспорт барной карты "Мой Бар"',
            'Export of "My Bar" catalog',
          ),
        ),
      );

      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.tr(
          'Барная карта подготовлена к экспорту',
          'Bar catalog is ready to export',
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(context.localizeErrorMessage(error.message));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.tr(
          'Не удалось экспортировать файл: $error',
          'Failed to export file: $error',
        ),
      );
    }
  }

  Future<String> _readPickedFile(PlatformFile file) async {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    if (file.path != null) {
      return File(file.path!).readAsString();
    }

    throw const FormatException('Файл пустой или недоступен.');
  }

  Future<File> _writeExportFile(String payload) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/my_bar_map_$timestamp.json');
    await file.writeAsString(payload, flush: true);
    return file;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SideNavigationToggleHandle extends StatefulWidget {
  const _SideNavigationToggleHandle({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  static const double size = 44;

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_SideNavigationToggleHandle> createState() =>
      _SideNavigationToggleHandleState();
}

class _SideNavigationToggleHandleState
    extends State<_SideNavigationToggleHandle> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            scale: _pressed ? 0.95 : 1,
            child: AnimatedGradientBorder(
              borderRadius: BorderRadius.circular(16),
              borderWidth: 1.2,
              innerColor: _pressed
                  ? const Color(0xCC202748)
                  : const Color(0xCC161B33),
              colors: const <Color>[
                Color(0xFFAA84FF),
                Color(0xFF76C4FF),
                Color(0xFFAA84FF),
              ],
              glowEffect: true,
              glow: const AnimatedGradientBorderGlow(opacity: 0.34),
              child: SizedBox(
                width: _SideNavigationToggleHandle.size,
                height: _SideNavigationToggleHandle.size,
                child: Icon(widget.icon, color: const Color(0xFFD2DEFF)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableAboutButton extends StatefulWidget {
  const _PressableAboutButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.pressedBackgroundColor,
    this.borderColor,
    this.glowColor,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color pressedBackgroundColor;
  final Color? borderColor;
  final Color? glowColor;

  @override
  State<_PressableAboutButton> createState() => _PressableAboutButtonState();
}

class _PressableAboutButtonState extends State<_PressableAboutButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          scale: _pressed ? 0.97 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _pressed
                  ? widget.pressedBackgroundColor
                  : widget.backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: widget.borderColor == null
                  ? null
                  : Border.all(color: widget.borderColor!),
              boxShadow: widget.glowColor == null
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: widget.glowColor!,
                        blurRadius: 12,
                        spreadRadius: 0.6,
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(widget.icon, size: 18, color: widget.foregroundColor),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.foregroundColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _BarManagementAction { addIngredient, addCocktail, settings, about }

enum _BarSettingsAction { import, export }
