import 'package:flutter/services.dart';

class MediaPlayer {
  static final _channel = const MethodChannel('MediaPlayer');
  static MediaPlayer instance;

  factory MediaPlayer() {
    instance ??= MediaPlayer._internal();
    return instance;
  }

  MediaPlayer._internal();

  MethodChannel getChannel() {
    return _channel;
  }

  init() {
    return _channel.invokeMethod('init');
  }

  start() {
    return _channel.invokeMethod('start');
  }

  pause() {
    return _channel.invokeMethod('pause');
  }

  setDataSource(
    final String filePath,
    final String title,
    final String artist,
    final String album,
    final String extendFilePath,
  ) {
    return _channel.invokeMethod('setDataSource', {
      'filePath': filePath,
      'filePath': filePath,
      'title': title,
      'artist': artist,
      'album': album,
      'extendFilePath': extendFilePath
    });
  }

  Future<int> getCurrentPosition() {
    return _channel.invokeMethod('getCurrentPosition');
  }

  Future<int> getDuration() {
    return _channel.invokeMethod('getDuration');
  }

  void seekTo(int position) {
    _channel.invokeMethod('seekTo', {'position': position});
  }

  void setLooping(bool loop) {
    _channel.invokeMethod('setLooping', {'loop': loop});
  }

  Future<bool> isLooping() {
    return _channel.invokeMethod('isLooping');
  }

  void setVolume(final double volume) {
    _channel.invokeMethod('setVolume', {'volume': volume});
  }

  Future<double> getVolume() {
    return _channel.invokeMethod('getVolume');
  }
}
