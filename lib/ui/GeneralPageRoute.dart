import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:musicx/component/CustomPageRoute.dart';
import 'package:musicx/unit/Streams.dart';

typedef TransitionBuilder = Widget Function(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
    Widget gesture);

class GeneralPageRoute<T> extends CustomPageRoute<T> {
  static push(
    final BuildContext context,
    final WidgetBuilder builder, {
    final TransitionBuilder transitionBuilder,
    final Duration transitionDuration,
    final bool opaque = false,
    final AxisDirection direction = AxisDirection.left,
  }) {
    final route = GeneralPageRoute._internal(
        builder: builder,
        transitionBuilder: transitionBuilder,
        transitionDuration: transitionDuration,
        opaque: opaque,
        direction: direction);
    AnimationStream().addAnimation(route.hashCode);
    Navigator.push(context, route);
    route.listenAnimation();
  }

  static pushReplacement(
    final BuildContext context,
    final WidgetBuilder builder, {
    final TransitionBuilder transitionBuilder,
    final Duration transitionDuration,
    final bool opaque = false,
    final AxisDirection direction = AxisDirection.up,
  }) {
    final route = GeneralPageRoute._internal(
        builder: builder,
        transitionBuilder: transitionBuilder,
        transitionDuration: transitionDuration,
        opaque: opaque,
        direction: direction);
    AnimationStream().addAnimation(route.hashCode);
    Navigator.pushReplacement(context, route);
    route.listenAnimation();
  }

  GeneralPageRoute._internal({
    @required final WidgetBuilder builder,
    @required final Duration transitionDuration,
    final RouteSettings settings,
    final TransitionBuilder transitionBuilder,
    final bool opaque,
    this.direction,
  }) : super(
            builder: builder,
            settings: settings,
            transitionBuilder: transitionBuilder,
            transitionDuration: transitionDuration,
            opaque: opaque);

  final AxisDirection direction;

  void listenAnimation() {
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

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // TODO: implement buildTransitions
    return transitionBuilder(
        context,
        animation,
        secondaryAnimation,
        child,
        CustomPageRouteGestureDetector<T>(
          enabledCallback: () => CustomPageRoute.isPopGestureEnabled<T>(this),
          onStartPopGesture: () => CustomPageRoute.startPopGesture<T>(this),
          direction: direction,
        ));
  }
}
