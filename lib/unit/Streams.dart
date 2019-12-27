import 'dart:async';

import 'package:flutter/cupertino.dart';
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

  Map<int, bool> _hashCodeMap = Map();

  addAnimation(int hashCode) {
    if (_hashCodeMap.containsKey(hashCode)) return;
    debugPrint("addAnimation");
    _hashCodeMap[hashCode] = true;
    controller.sink.add(++_counter);
  }

  removeAnimation(int hashCode) {
    debugPrint("removeAnimation");
    if (_hashCodeMap.remove(hashCode)) --_counter;
    controller.sink.add(_counter);
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
