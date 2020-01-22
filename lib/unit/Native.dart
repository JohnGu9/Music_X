import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Native {
  static StreamController _controller;

  static init() {
    assert(_controller == null);
    _controller = StreamController.broadcast();
  }

  static dispose() {
    _controller.close();
  }

  static final MethodChannel _channel = MethodChannel("Native")
    ..setMethodCallHandler(handler);

  static Future handler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'Palette':
        _controller.sink.add(methodCall.arguments);
        break;
    }
  }

  static moveTaskToBack() {
    return _channel.invokeMethod('moveTaskToBack');
  }

  static int paletteToken = 0;

  static Future<Map> palette({@required Uint8List data}) async {
    assert(_controller != null, 'Native palette required Native call [init]');
    assert(data != null);
    final token = paletteToken++;
    _channel.invokeMethod('Palette', {'data': data, 'token': token});

    final res = await _controller.stream.firstWhere((event) {
      if (event is Map && event['token'] == token) return true;
      return false;
    }) as Map;
    res.forEach((final key, final data) {
      if (data == null) return;
      res[key] = colorParse(data);
    });
    return res;
  }

  // Parse Android [Color] Object getRgb method result
  static Color colorParse(int rgb) => Color.fromARGB(
      255, (rgb & 16711680) >> 16, (rgb & 65280) >> 8, (rgb & 255));
}
