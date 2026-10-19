import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_bar/core/reviews/native_review_gateway.dart';
import 'package:my_bar/core/reviews/review_prompt_controller.dart';
import 'package:my_bar/core/reviews/review_prompt_coordinator.dart';
import 'package:my_bar/core/reviews/review_prompt_policy.dart';
import 'package:my_bar/core/reviews/review_prompt_storage.dart';

void main() {
  testWidgets('does not request a review on launch or merely after waiting', (
    tester,
  ) async {
    final harness = await _mount(tester);

    await tester.pump(const Duration(minutes: 10));

    expect(harness.gateway.availabilityChecks, 0);
    expect(harness.gateway.requests, 0);
  });

  testWidgets('waits four idle seconds after a successful action', (
    tester,
  ) async {
    final harness = await _mount(tester);

    await tester.tap(find.byKey(const Key('successful-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3999));
    expect(harness.gateway.requests, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(harness.gateway.availabilityChecks, 1);
    expect(harness.gateway.requests, 1);
  });

  testWidgets('defers a pending request while another page covers home', (
    tester,
  ) async {
    final harness = await _mount(tester);
    await harness.controller.recordSuccessfulAction();
    await tester.pump();
    unawaited(
      harness.navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const Scaffold(body: Text('Recipe page')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(harness.gateway.requests, 0);

    harness.navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(harness.gateway.requests, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(harness.gateway.requests, 1);
  });

  testWidgets('defers a pending request while a dialog covers home', (
    tester,
  ) async {
    final harness = await _mount(tester);
    await harness.controller.recordSuccessfulAction();
    await tester.pump();
    unawaited(
      showDialog<void>(
        context: tester.element(find.byKey(const Key('home'))),
        builder: (context) => const AlertDialog(content: Text('Open dialog')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(harness.gateway.requests, 0);

    harness.navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(harness.gateway.requests, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(harness.gateway.requests, 1);
  });

  testWidgets(
    'backgrounding discards the opportunity without prompting on resume',
    (tester) async {
      final harness = await _mount(tester);
      await harness.controller.recordSuccessfulAction();
      await tester.pump(const Duration(seconds: 3));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(harness.gateway.requests, 0);
      _resume(tester);
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(harness.gateway.requests, 0);
      expect(harness.gateway.availabilityChecks, 0);

      await harness.controller.recordSuccessfulAction();
      await tester.pump(const Duration(seconds: 4));
      expect(harness.gateway.requests, 1);
    },
  );

  testWidgets('another touch restarts the full idle delay', (tester) async {
    final harness = await _mount(tester);
    await harness.controller.recordSuccessfulAction();
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.byKey(const Key('ordinary-interaction')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3999));
    expect(harness.gateway.requests, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(harness.gateway.requests, 1);
  });

  testWidgets('never requests while a pointer is held down', (tester) async {
    final harness = await _mount(tester);
    await harness.controller.recordSuccessfulAction();
    await tester.pump(const Duration(seconds: 3));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('ordinary-interaction'))),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(harness.gateway.requests, 0);
    await gesture.up();
    await tester.pump(const Duration(seconds: 4));
    expect(harness.gateway.requests, 1);
  });

  testWidgets('a visible keyboard suppresses the request', (tester) async {
    final harness = await _mount(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    await harness.controller.recordSuccessfulAction();
    await tester.pump(const Duration(seconds: 10));
    expect(harness.gateway.requests, 0);
    expect(harness.gateway.availabilityChecks, 0);

    tester.view.resetViewInsets();
    await tester.pump();
    await harness.controller.recordSuccessfulAction();
    await tester.pump(const Duration(seconds: 4));
    expect(harness.gateway.requests, 1);
  });

  testWidgets(
    'focused text input suppresses requests even without keyboard insets',
    (tester) async {
      final harness = await _mount(tester);
      await tester.tap(find.byKey(const Key('text-input')));
      await tester.pump();
      await harness.controller.recordSuccessfulAction();
      await tester.pump(const Duration(seconds: 10));
      expect(harness.gateway.requests, 0);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await harness.controller.recordSuccessfulAction();
      await tester.pump(const Duration(seconds: 4));
      expect(harness.gateway.requests, 1);
    },
  );

  testWidgets('disposal cancels a pending opportunity', (tester) async {
    final harness = await _mount(tester);
    await harness.controller.recordSuccessfulAction();
    await tester.pump(const Duration(seconds: 3));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));

    expect(harness.gateway.requests, 0);
    expect(harness.gateway.availabilityChecks, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding placeholder cannot trigger review scheduling', (
    tester,
  ) async {
    final harness = await _mount(tester, onboardingComplete: false);
    await harness.controller.recordSuccessfulAction();
    await tester.pump(const Duration(minutes: 10));
    expect(harness.gateway.requests, 0);

    harness.onboardingComplete.value = true;
    await tester.pump();
    await tester.pump(const Duration(minutes: 10));
    expect(harness.gateway.requests, 0);

    await harness.controller.recordSuccessfulAction();
    await tester.pump(const Duration(seconds: 4));
    expect(harness.gateway.requests, 1);
  });
}

Future<_Harness> _mount(
  WidgetTester tester, {
  bool onboardingComplete = true,
}) async {
  _resume(tester);
  addTearDown(() => _resume(tester));
  final now = DateTime.utc(2026, 10, 20, 12);
  final gateway = _FakeReviewGateway();
  final controller = ReviewPromptController(
    storage: InMemoryReviewPromptStorage(
      initial: ReviewPromptState(
        firstUsedAt: now.subtract(const Duration(days: 8)),
        lastObservedAt: now,
        usageDays: [
          now.subtract(const Duration(days: 8)),
          now.subtract(const Duration(days: 4)),
          now,
        ],
        successfulActionCount: 5,
      ),
    ),
    gateway: gateway,
    now: () => now,
    foregroundDuration: () => const Duration(minutes: 2),
  );
  final navigator = GlobalKey<NavigatorState>();
  final routeObserver = RouteObserver<ModalRoute<dynamic>>();
  final onboarding = ValueNotifier(onboardingComplete);
  addTearDown(controller.dispose);
  addTearDown(onboarding.dispose);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [routeObserver],
      home: ValueListenableBuilder<bool>(
        valueListenable: onboarding,
        builder: (context, completed, _) {
          if (!completed) {
            return const Scaffold(body: Text('Onboarding'));
          }
          return ReviewPromptCoordinator(
            controller: controller,
            routeObserver: routeObserver,
            child: Scaffold(
              key: const Key('home'),
              body: Column(
                children: [
                  TextButton(
                    key: const Key('successful-action'),
                    onPressed: () =>
                        unawaited(controller.recordSuccessfulAction()),
                    child: const Text('Save a meaningful action'),
                  ),
                  TextButton(
                    key: const Key('ordinary-interaction'),
                    onPressed: () {},
                    child: const Text('Interact without recording an action'),
                  ),
                  const TextField(key: Key('text-input')),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pump();
  return _Harness(
    controller: controller,
    gateway: gateway,
    navigator: navigator,
    onboardingComplete: onboarding,
  );
}

void _resume(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.paused) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
}

class _Harness {
  const _Harness({
    required this.controller,
    required this.gateway,
    required this.navigator,
    required this.onboardingComplete,
  });

  final ReviewPromptController controller;
  final _FakeReviewGateway gateway;
  final GlobalKey<NavigatorState> navigator;
  final ValueNotifier<bool> onboardingComplete;
}

class _FakeReviewGateway implements ReviewGateway {
  int availabilityChecks = 0;
  int requests = 0;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return true;
  }

  @override
  Future<void> requestReview() async {
    requests++;
  }
}
