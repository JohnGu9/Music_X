import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MediaMetadataRetriever {
  static final MethodChannel _channel = MethodChannel("MediaMetadataRetriever");

  static Future<Uint8List> getEmbeddedPicture({
    @required final String filePath,
  }) async {
    return Future.microtask(() async {
      return await _channel
          .invokeMethod('getEmbeddedPicture', {'filePath': filePath});
    });
  }

  static Future<Map<String, String>> getBasicInfo({@required String filePath}) {
    return _channel.invokeMethod('getBasicInfo', {'filePath': filePath});
  }
}
