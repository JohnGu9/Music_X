import 'package:flutter/material.dart';

class SecondaryTransition extends AnimatedWidget {
  static final _tween = Tween(begin: 1.0, end: 0.9);

  SecondaryTransition(
      {Key key, @required Listenable listenable, @required this.child})
      : _animation =
            CurvedAnimation(parent: listenable, curve: Curves.fastOutSlowIn),
        super(key: key, listenable: listenable);
  final Widget child;
  final Animation _animation;

  bool get isActive {
    final animation = listenable as Animation;
    return animation.value <= 0.1;
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    final double scaleValue = _tween.evaluate(_animation);
    final Matrix4 transform = Matrix4.identity()
      ..scale(scaleValue, scaleValue, 1.0);
    return Transform(
      transform: transform,
      alignment: Alignment.center,
      child: child,
    );
  }
}
