import 'dart:async';

import 'package:flutter/scheduler.dart';

class AnimationStream {
  static AnimationStream instance;

  factory AnimationStream() {
    instance ??= AnimationStream._internal();
    return instance;
  }

  AnimationStream._internal() : controller = StreamController.broadcast();

  final StreamController<int> controller;
  int _counter = 0;

  bool get isAnimating {
    return _counter != 0;
  }

  Map<Object, bool> _objMap = Map();

  addAnimation(Object obj /*the object attach(logical) to animation*/,
      {Duration timeout = const Duration(seconds: 5)}) {
    if (_objMap.containsKey(obj)) return;
    _objMap[obj] = true;
    controller.sink.add(++_counter);

    // protect the resource actually release
    if (timeout == null) return;
    Future.delayed(timeout, () => removeAnimation(obj));
  }

  removeAnimation(int hashCode) {
    if (_objMap.containsKey(hashCode)) {
      _objMap.remove(hashCode);
      controller.sink.add(--_counter);
    }
  }

  Future _idle;

  idle() async {
    await SchedulerBinding.instance.endOfFrame;
    if (isAnimating) {
      _idle ??=
          controller.stream.firstWhere((int event) => event == 0).then((_) {
        _idle = null;
      });
      await _idle;
    }
  }

  void dispose() {
    instance = null;
    controller.close();
  }
}
