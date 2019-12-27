import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:musicx/component.dart';
import 'package:musicx/unit/Constants.dart';
import 'package:musicx/unit/Streams.dart';

class Panel extends StatefulWidget {
  const Panel({Key key}) : super(key: key);
  static const installDuration = const Duration(seconds: 1);
  static const startValue = 0.11;

  @override
  _PanelState createState() => _PanelState();
}

class _PanelState extends State<Panel> with SingleTickerProviderStateMixin {
  static final Tween<Offset> _tween =
      Tween(begin: const Offset(0, 1), end: const Offset(0, 0));
  static const _duration = Duration(milliseconds: 600);

  AnimationController _controller;

  static nullFn() {}

  void _onChanged() {
    setState(nullFn);
  }

  void _onStatusChanged(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        AnimationStream().addAnimation(hashCode);
        break;
      case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        AnimationStream().removeAnimation(hashCode);
        break;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addListener(_onChanged)
      ..addStatusListener(_onStatusChanged)
      ..animateTo(
        Panel.startValue,
        duration: Panel.installDuration,
        curve: Curves.fastOutSlowIn,
      );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build

    return FractionalTranslation(
      translation: _tween.evaluate(_controller),
      child: Stack(
        fit: StackFit.expand,
        overflow: Overflow.visible,
        children: <Widget>[
          PanelContent(
            listenable: _controller,
          ),
          CustomPageRouteGestureDetector(
              direction: AxisDirection.up,
              enabledCallback: () {
                return true;
              },
              onStartPopGesture: () {
                return Controller(
                    controller: _controller, minValue: Panel.startValue);
              })
        ],
      ),
    );
  }
}

class Controller extends CustomPageController {
  Controller(
      {@required AnimationController controller, @required double minValue})
      : routeControllerMinValue = minValue,
        routeControllerMaxValue = controller.upperBound,
        super(controller: controller);
  @override
  final double routeControllerMinValue;
  @override
  final double routeControllerMaxValue;

  static const double _kMinFlingVelocity = 1.0;
  static const int _kMaxDroppedSwipePageForwardAnimationTime =
      550; // Milliseconds.
  static const int _kMaxPageBackAnimationTime = 300; // Milliseconds.
  @override
  void dragEnd(double velocity) {
    const Curve animationToCurve = Curves.easeOut;
    const Curve animationBackCurve = Curves.easeOutCirc;

    final animateForward = velocity < _kMinFlingVelocity;
    if (animateForward) {
      final int droppedPageForwardAnimationTime = min(
        lerpDouble(
                _kMaxDroppedSwipePageForwardAnimationTime, 0, controller.value)
            .floor(),
        _kMaxPageBackAnimationTime,
      );
      controller.animateTo(1.0,
          duration: Duration(milliseconds: droppedPageForwardAnimationTime),
          curve: animationToCurve);
    } else {
      final int droppedPageBackAnimationTime = lerpDouble(
              0, _kMaxDroppedSwipePageForwardAnimationTime, controller.value)
          .floor();
      controller.animateBack(routeControllerMinValue,
          duration: Duration(milliseconds: droppedPageBackAnimationTime),
          curve: animationBackCurve);
    }
  }
}

class PanelContent extends AnimatedWidget {
  PanelContent({Key key, @required Listenable listenable})
      : padding = Tween(begin: EdgeInsets.zero, end: const EdgeInsets.all(4.0))
            .animate(CurvedAnimation(
                parent: listenable,
                curve: const Interval(Panel.startValue, 1.0))),
        super(key: key, listenable: listenable);

  final Animation<EdgeInsets> padding;

  static const borderRadius = BorderRadius.all(Constants.radius);
  static const shape = const RoundedRectangleBorder(borderRadius: borderRadius);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: padding.value,
      child:const Material(
        elevation: 10.0,
        shape: shape,
        animationDuration: Duration.zero,
        color: Colors.blue,
      ),
    );
  }
}
