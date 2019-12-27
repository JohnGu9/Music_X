import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:musicx/component/AsyncTaskManager.dart';
import 'package:musicx/unit/MediaMetadataRetriever.dart';
import 'package:musicx/unit/Streams.dart';

enum CustomImageProviderStatus {
  updating,
  updated,
}

typedef NullCallback = Function();

class LoadImageTaskManager extends AsyncTaskManager {
  final awaitStream = AnimationStream();

  @override
  Stream<NullCallback> run() async* {
    await for (final NullCallback fn in controller.stream) {
      await awaitStream.idle();
      await Future(fn);
      yield fn;
    }
  }
}

abstract class CustomImageProvider<T extends ImageProvider>
    extends ChangeNotifier implements ValueListenable<T> {}

class ArtworkProvider extends CustomImageProvider {
  static final Map _cache = Map<String, ArtworkProvider>();
  static final LoadImageTaskManager manager = LoadImageTaskManager();

  factory ArtworkProvider({@required String filePath}) {
    _cache[filePath] ??= ArtworkProvider._internal(filePath);
    return _cache[filePath];
  }

  ArtworkProvider._internal(this.filePath)
      : _state = CustomImageProviderStatus.updating {
    _initialization = manager.runTask(_initialize, AsyncTaskPriority.NORMAL);
  }

  final String filePath;
  Uint8List _data;

  Future get initialization => _initialization;
  Future _initialization;

  _initialize() async {
    assert(await File(filePath).exists());
    _data = await MediaMetadataRetriever.getEmbeddedPicture(filePath: filePath);
    _state = CustomImageProviderStatus.updated;
    notifyListeners();
  }

  CustomImageProviderStatus get state => _state;
  CustomImageProviderStatus _state;

  @override
  ImageProvider get value => _data == null ? null : MemoryImage(_data);
}
