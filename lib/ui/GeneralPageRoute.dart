import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:music/component/CustomPageRoute.dart';
import 'package:music/ui/Panel.dart';
import 'package:music/unit/Streams.dart';

typedef TransitionBuilder = Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child);

class GeneralPageRoute<T> extends CustomPageRoute<T> {
  static push(
    final BuildContext context,
    final WidgetBuilder builder, {
    final TransitionBuilder transitionBuilder,
    final Duration transitionDuration,
    final bool opaque = false,
    final AxisDirection direction = AxisDirection.up,
    final HitTestBehavior gestureHitTestBehavior = HitTestBehavior.translucent,
  }) {
    final route = GeneralPageRoute._internal(
        builder: builder,
        transitionBuilder: transitionBuilder,
        transitionDuration: transitionDuration,
        opaque: opaque,
        direction: direction,
        gestureHitTestBehavior: gestureHitTestBehavior);
    if (transitionDuration?.inMilliseconds == Duration.zero.inMilliseconds)
      return Navigator.pushReplacement(context, route);
    AnimationStream().addAnimation(route.hashCode);
    Navigator.push(context, route);
    route.bootAnimation();
  }

  static pushReplacement(
    final BuildContext context,
    final WidgetBuilder builder, {
    final TransitionBuilder transitionBuilder,
    final Duration transitionDuration,
    final bool opaque = false,
    final AxisDirection direction = AxisDirection.up,
    final bool overrideAnimation = false,
    final HitTestBehavior gestureHitTestBehavior = HitTestBehavior.translucent,
  }) {
    final route = GeneralPageRoute._internal(
        builder: builder,
        transitionBuilder: transitionBuilder,
        transitionDuration: transitionDuration,
        opaque: opaque,
        direction: direction,
        gestureHitTestBehavior: gestureHitTestBehavior);
    if (transitionDuration?.inMilliseconds == Duration.zero.inMilliseconds)
      return Navigator.pushReplacement(context, route);
    AnimationStream().addAnimation(route.hashCode);
    Navigator.pushReplacement(context, route);
    route.bootAnimation(override: overrideAnimation);
  }

  static const _defaultDuration = Duration(milliseconds: 450);

  GeneralPageRoute._internal({
    @required final WidgetBuilder builder,
    @required final Duration transitionDuration,
    final RouteSettings settings,
    final TransitionBuilder transitionBuilder,
    final bool opaque,
    this.direction,
    this.gestureHitTestBehavior = HitTestBehavior.translucent,
  }) : super(
            builder: builder,
            settings: settings,
            transitionBuilder: transitionBuilder,
            transitionDuration: transitionDuration ?? _defaultDuration,
            opaque: opaque);
  final HitTestBehavior gestureHitTestBehavior;
  final AxisDirection direction;

  void bootAnimation({bool override = true}) {
    if (override) {
      navigator.didStartUserGesture();
      final simulation = SpringSimulation(_spring, 0, 1.0, 0);
      controller.animateWith(simulation).then((value) {
        navigator.didStopUserGesture();
      });
    }
    animation.addStatusListener((AnimationStatus status) {
      switch (status) {
        case AnimationStatus.dismissed:
        case AnimationStatus.completed:
          AnimationStream().removeAnimation(this.hashCode);
          break;
        case AnimationStatus.forward:
        case AnimationStatus.reverse:
          AnimationStream().addAnimation(this.hashCode);
          break;
      }
    });
  }

  static bool isPopGestureInProgress(PageRoute route) =>
      route.navigator.userGestureInProgress;

  static bool isPopGestureEnabled<T>(PageRoute<T> route) {
    if (route.isFirst) return false;
    if (route.willHandlePopInternally) return false;
//    if (route.hasScopedWillPopCallback) return false;
    if (route.fullscreenDialog) return false;
    if (route.animation.status != AnimationStatus.completed) return false;
    if (route.secondaryAnimation.status != AnimationStatus.dismissed)
      return false;
    if (isPopGestureInProgress(route)) return false;
    return true;
  }

  static CustomPageController<T> startPopGesture<T>(
      PageRoute<T> route, double size) {
    assert(isPopGestureEnabled(route));

    return _Controller<T>(
      navigator: route.navigator,
      controller: route.controller, size: size,
      // protected access
    );
  }

  double _size(BuildContext context) {
    switch (direction) {
      case AxisDirection.up:

      case AxisDirection.down:
        return MediaQuery.of(context).size.height;
      case AxisDirection.left:

      case AxisDirection.right:
        return MediaQuery.of(context).size.width;
    }
    assert(false);
    return null;
  }

  Widget gestureBuilder({@required BuildContext context, Widget child}) {
    return CustomPageRouteGestureDetector<T>(
      hitTestBehavior: gestureHitTestBehavior,
      enabledCallback: () => isPopGestureEnabled<T>(this),
      onStartPopGesture: () => startPopGesture<T>(this, _size(context)),
      direction: direction,
      child: child,
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // TODO: implement buildTransitions
    return GeneralNavigator(
      controller: controller,
      navigator: navigator,
      gestureBuilder: gestureBuilder,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: transitionBuilder(
        context,
        animation,
        secondaryAnimation,
        child,
      ),
    );
  }
}

const _spring = SpringDescription(
  mass: 30,
  stiffness: 1,
  damping: 1,
);

class _Controller<T> extends CustomPageController<T> {
  _Controller(
      {@required NavigatorState navigator,
      @required AnimationController controller,
      @required this.size})
      : routeControllerMinValue = controller.lowerBound,
        routeControllerMaxValue = controller.upperBound,
        super(
          navigator: navigator,
          controller: controller,
          minFlingVelocity: 0.1,
        );

  final double size;

  @override
  final double routeControllerMinValue;
  @override
  final double routeControllerMaxValue;

  @override
  void dragEnd(double velocity) async {
    assert(navigator != null);

    final animateForward = velocity < minFlingVelocity;
    if (animateForward) {
      final simulation = SpringSimulation(
          _spring, controller.value, routeControllerMaxValue, -velocity / size);
      await controller.animateWith(simulation);
    } else {
      navigator.pop();
      if (controller.isAnimating) {
        final simulation = SpringSimulation(_spring, controller.value,
            routeControllerMinValue, -velocity / size);
        await controller.animateWith(simulation);
        // make animation actually finish using [animateBack], just call [animateWith] the animation will never finish.
        controller.animateBack(0.0, duration: Duration.zero);
      }
    }
    navigator.didStopUserGesture();
  }
}

class GeneralNavigator extends InheritedWidget {
  static BuildContext _buildContext;

  static GeneralNavigator of(BuildContext context) {
    final GeneralNavigator _gn =
        context.dependOnInheritedWidgetOfExactType<GeneralNavigator>();
    _buildContext = context;
    return _gn;
  }

  GeneralNavigator(
      {final Key key,
      final Widget child,
      this.controller,
      this.navigator,
      this.gestureBuilder,
      this.animation,
      this.secondaryAnimation})
      : super(key: key, child: GeneralWillPopScope(child: child));

  @protected
  final AnimationController controller;
  @protected
  final NavigatorState navigator;

  final Widget Function({@required BuildContext context, Widget child})
      gestureBuilder;

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;

  bool pop() {
    if (!navigator.userGestureInProgress && !controller.isAnimating)
      routePop(_buildContext);
    return false;
  }

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) {
    // TODO: implement updateShouldNotify
    return false;
  }
}

class GeneralWillPopScope extends StatelessWidget {
  const GeneralWillPopScope({Key key, this.child}) : super(key: key);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return WillPopScope(
        onWillPop: () async {
          return GeneralNavigator.of(context).pop();
        },
        child: child);
  }
}
