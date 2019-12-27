import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Native {
  static StreamController _controller;

  static init() {
    _controller = StreamController.broadcast();
  }

  static dispose() {
    _controller.close();
  }

  static final MethodChannel _channel = MethodChannel("Native")
    ..setMethodCallHandler(handler);

  static Future handler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case "Palette":
        _controller.sink.add(methodCall.arguments);
    }
  }

  static int paletteToken = 0;

  static Future<Map> palette({@required Uint8List data}) async {
    assert(_controller != null, 'Native palette required Native call [init]');
    final token = paletteToken++;
    _channel.invokeMethod('Palette', {'data': data, 'token': token});
    return await _controller.stream.firstWhere((event) {
      if (event is Map) return event['token'] == token ? true : false;
      return false;
    });
  }
}
