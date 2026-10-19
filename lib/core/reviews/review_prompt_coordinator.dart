import 'dart:async';

import 'package:flutter/material.dart';

import 'review_prompt_controller.dart';

/// Mounted only after onboarding. Requests are limited to the idle home screen,
/// never a recipe, editor, modal, keyboard interaction, or background session.
class ReviewPromptCoordinator extends StatefulWidget {
  const ReviewPromptCoordinator({
    required this.controller,
    required this.routeObserver,
    required this.child,
    super.key,
  });

  static const idleDelay = Duration(seconds: 4);

  final ReviewPromptController controller;
  final RouteObserver<ModalRoute<dynamic>> routeObserver;
  final Widget child;

  @override
  State<ReviewPromptCoordinator> createState() =>
      _ReviewPromptCoordinatorState();
}

class _ReviewPromptCoordinatorState extends State<ReviewPromptCoordinator>
    with WidgetsBindingObserver, RouteAware {
  Timer? _idleTimer;
  ModalRoute<dynamic>? _route;
  bool _pendingOpportunity = false;
  bool _scrolling = false;
  final Set<int> _pointers = {};

  bool get _resumed {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onSuccessfulAction);
    if (_resumed) unawaited(widget.controller.startSession());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      widget.routeObserver.unsubscribe(this);
      _route = route;
      if (route != null) widget.routeObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant ReviewPromptCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSuccessfulAction);
      oldWidget.controller.stopSession();
      widget.controller.addListener(_onSuccessfulAction);
      _discardOpportunity();
      if (_resumed) unawaited(widget.controller.startSession());
    }
    if (oldWidget.routeObserver != widget.routeObserver) {
      oldWidget.routeObserver.unsubscribe(this);
      if (_route != null) widget.routeObserver.subscribe(this, _route!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.startSession());
    } else {
      _discardOpportunity();
      _pointers.clear();
      _scrolling = false;
      widget.controller.stopSession();
    }
  }

  void _onSuccessfulAction() {
    _pendingOpportunity = true;
    _schedule();
  }

  bool get _hasTextFocus {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    return focusedContext?.widget is EditableText ||
        focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _canPresent() =>
      mounted &&
      _resumed &&
      _route?.isCurrent == true &&
      _pointers.isEmpty &&
      !_scrolling &&
      MediaQuery.viewInsetsOf(context).bottom == 0 &&
      !_hasTextFocus;

  void _schedule() {
    _idleTimer?.cancel();
    if (!_pendingOpportunity || !_canPresent()) return;
    _idleTimer = Timer(ReviewPromptCoordinator.idleDelay, () {
      if (!_canPresent()) return;
      _pendingOpportunity = false;
      unawaited(widget.controller.maybeRequest(canPresent: _canPresent));
    });
  }

  void _discardOpportunity() {
    _idleTimer?.cancel();
    _pendingOpportunity = false;
  }

  @override
  void didPushNext() => _idleTimer?.cancel();

  @override
  void didPopNext() => _schedule();

  @override
  void dispose() {
    _idleTimer?.cancel();
    widget.routeObserver.unsubscribe(this);
    widget.controller.removeListener(_onSuccessfulAction);
    widget.controller.stopSession();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      _pointers.add(event.pointer);
      _idleTimer?.cancel();
    },
    onPointerUp: (event) {
      _pointers.remove(event.pointer);
      _schedule();
    },
    onPointerCancel: (event) {
      _pointers.remove(event.pointer);
      _schedule();
    },
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _scrolling = true;
          _idleTimer?.cancel();
        } else if (notification is ScrollEndNotification) {
          _scrolling = false;
          _schedule();
        }
        return false;
      },
      child: widget.child,
    ),
  );
}
