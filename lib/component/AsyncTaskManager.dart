import 'dart:async';

import 'package:flutter/material.dart';

enum AsyncTaskPriority { MIN, NORMAL, MAX }

typedef NullCallback = Function();

abstract class AsyncTaskManager<T extends NullCallback> {
  AsyncTaskManager() : controller = StreamController() {
    _stream = run().asBroadcastStream();
  }

  @protected
  final StreamController<T> controller;

  Stream<T> _stream;

  @protected
  Stream<T> get stream => _stream;

  @protected
  Stream<T> run() async* {
    await for (final T fn in controller.stream) yield await runSingleTask(fn);
  }

  @protected
  Future<T> runSingleTask(T fn) async {
    await Future(fn);
    return fn;
  }

  Future<void> runTask(T function, AsyncTaskPriority priority) async {
    if (priority == AsyncTaskPriority.MAX) {
      await Future.microtask(function);
      return;
    }
    controller.sink.add(function);
    await stream.firstWhere((T event) => event == function);
  }

  @protected
  @mustCallSuper
  void dispose() {
    controller.close();
  }
}
