import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SingleTouchRecognizer extends StatelessWidget {
  const SingleTouchRecognizer({this.child, Key key})
      : handlers =
            const GestureRecognizerFactoryWithHandlers<_SingleTouchRecognizer>(
                _constructor, _initializer),
        super(key: key);

  final Widget child;
  final GestureRecognizerFactoryWithHandlers handlers;

  static _SingleTouchRecognizer _constructor() {
    return _SingleTouchRecognizer();
  }

  static void _initializer(_SingleTouchRecognizer instance) {}

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _SingleTouchRecognizer: handlers
      },
      child: child,
    );
  }
}

class _SingleTouchRecognizer extends OneSequenceGestureRecognizer {
  @override
  // TODO: implement debugDescription
  String get debugDescription => null;

  @override
  void didStopTrackingLastPointer(int pointer) {
    // TODO: implement didStopTrackingLastPointer
  }

  @override
  void handleEvent(PointerEvent event) {
    // TODO: implement handleEvent
    if (!event.down && event.pointer == _p) {
      // The event have finished.
      // Mark flag to allow new event to pass through to the child.
      _p = 0;
    }
  }

  int _p = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // TODO: implement addAllowedPointer
    startTrackingPointer(event.pointer);
    //ignore event if another event is already in progress
    if (_p == 0) {
      // There is no other event in progress
      // reject this event allow the event pass through to the child widget.
      resolve(GestureDisposition.rejected);
      _p = event.pointer;
    } else {
      // There is an event in progress.
      // absorb other events
      resolve(GestureDisposition.accepted);
    }
  }
}
