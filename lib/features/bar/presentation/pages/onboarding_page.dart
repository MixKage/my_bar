import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/bar_pressable.dart';
import '../../data/onboarding_storage.dart';
import '../widgets/neon_background.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    required this.storage,
    required this.child,
    this.powerSavingMode = false,
    super.key,
  });
  final OnboardingStorage storage;
  final Widget child;
  final bool powerSavingMode;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  late bool _completed;
  @override
  void initState() {
    super.initState();
    _completed = widget.storage.isCompleted;
  }

  @override
  Widget build(BuildContext context) => _completed
      ? widget.child
      : OnboardingPage(
          powerSavingMode: widget.powerSavingMode,
          onComplete: () async {
            await widget.storage.complete();
            if (mounted) setState(() => _completed = true);
          },
        );
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    required this.onComplete,
    this.powerSavingMode = false,
    super.key,
  });
  final Future<void> Function() onComplete;
  final bool powerSavingMode;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onComplete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Не удалось сохранить. Попробуйте ещё раз.',
                'Could not save. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _go(int page) {
    final duration = AppMotion.duration(
      context,
      AppMotion.standard,
      powerSavingMode: widget.powerSavingMode,
    );
    if (duration == Duration.zero) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: duration,
        curve: AppMotion.enterCurve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = <({IconData icon, String title, String body})>[
      (
        icon: Icons.liquor_rounded,
        title: context.tr('Ваш домашний бар', 'Your home bar'),
        body: context.tr(
          '1. Откройте раздел «Ингредиенты» и нажмите на продукты и напитки, которые есть у вас дома. Галочка означает, что ингредиент в наличии.\n\n2. Перейдите в «Барную карту»: приложение покажет, какие коктейли можно приготовить из выбранного. Фильтр «Можно сейчас» оставит только доступные рецепты.',
          '1. Open Ingredients and tap the products and drinks you have at home. A checkmark means the ingredient is in stock.\n\n2. Open Bar Menu to see which cocktails you can make with your ingredients. Use the Ready filter to show only recipes you can make now.',
        ),
      ),
      (
        icon: Icons.shopping_basket_rounded,
        title: context.tr('Ещё один ингредиент…', 'Just one more ingredient…'),
        body: context.tr(
          'Фильтры «Не хватает 1» и «Не хватает 2» находят почти доступные рецепты. Умный список покупок подскажет, что докупить.',
          '“Missing 1” and “Missing 2” reveal nearly-ready recipes. The smart shopping list helps you decide what to buy next.',
        ),
      ),
      (
        icon: Icons.celebration_rounded,
        title: context.tr('Готовьте для компании', 'Mix for a crowd'),
        body: context.tr(
          'Калькулятор пересчитает состав на нужное число порций. В режиме вечеринки выберите коктейли и получите общий список ингредиентов.',
          'Scale recipes to any serving count. In Party Mode, choose cocktails and get a combined ingredient list.',
        ),
      ),
      (
        icon: Icons.casino_rounded,
        title: context.tr('Откройте новый вкус', 'Discover a new favorite'),
        body: context.tr(
          'Нажмите «Удиви меня» и листайте случайные рецепты кнопкой «Следующий коктейль». Сохраняйте понравившиеся в избранное. Все эти функции бесплатны и работают офлайн.',
          'Tap “Surprise me” and explore random recipes with “Next cocktail”. Save your favorites. All these features are free and work offline.',
        ),
      ),
    ];
    return Scaffold(
      body: NeonBackground(
        topGlow: const Color(0xFF7D4BFF),
        bottomGlow: const Color(0xFF2AA6FF),
        reduceEffects: widget.powerSavingMode,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            context.tr(
                              'Знакомство с приложением',
                              'Welcome to My Bar',
                            ),
                            style: const TextStyle(
                              color: Color(0xFFAEB9DB),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        BarPressable(
                          onTap: _saving ? null : _finish,
                          powerSavingMode: widget.powerSavingMode,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              context.tr('Пропустить', 'Skip'),
                              style: const TextStyle(color: Color(0xFFB8C9FF)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      onPageChanged: (value) => setState(() => _page = value),
                      itemCount: slides.length,
                      itemBuilder: (context, index) {
                        final slide = slides[index];
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
                          child: Column(
                            children: <Widget>[
                              Container(
                                width: 112,
                                height: 112,
                                decoration: BoxDecoration(
                                  color: const Color(0x333D497F),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: const Color(0x886C7ED1),
                                  ),
                                ),
                                child: Icon(
                                  slide.icon,
                                  size: 52,
                                  color: const Color(0xFFBBC7FF),
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                slide.body,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFB8C3E2),
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: <Widget>[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            '${_page + 1} / ${slides.length}',
                            style: const TextStyle(color: Color(0xFFAEB9DB)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            if (_page > 0) ...<Widget>[
                              BarHeaderButton(
                                tooltip: context.tr('Назад', 'Back'),
                                icon: Icons.arrow_back_rounded,
                                powerSavingMode: widget.powerSavingMode,
                                onPressed: () => _go(_page - 1),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: BarActionButton(
                                label: _page == slides.length - 1
                                    ? context.tr('Начать', 'Get started')
                                    : context.tr('Далее', 'Next'),
                                icon: _page == slides.length - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                powerSavingMode: widget.powerSavingMode,
                                onPressed: _saving
                                    ? null
                                    : () {
                                        if (_page == slides.length - 1) {
                                          _finish();
                                        } else {
                                          _go(_page + 1);
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
