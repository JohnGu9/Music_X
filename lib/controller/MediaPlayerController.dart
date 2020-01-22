import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music/component/CustomValueNotifier.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/controller/CustomListManager.dart';
import 'package:music/unit/MediaPlayer.dart';

enum MediaPlayerSequenceMode {
  repeat,
  shuffle,
  repeat_one,
}

// MediaPlayer Status
enum MediaPlayerStatus {
  end,
  error,
  started,
  paused,
}

typedef NullCallBack = Function();

class MediaPlayerController {
  static MediaPlayerController _instance;

  Future<dynamic> methodCallHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'start':
        debugPrint('onStart');
        start();
        return null;

      case 'pause':
        debugPrint('onPause');
        pause();
        return null;

      case 'toPrevious':
        toPrevious();
        return null;

      case 'toNext':
        toNext();
        return null;

      case 'State':
      case 'onSeekComplete':
        final arguments = methodCall.arguments;
        updateState(arguments);
        return null;

      case 'onError':
        state.value = MediaPlayerStatus.error;
        debugPrint('onError');
        return null;

      case 'onCompletion':
        state.value = MediaPlayerStatus.paused;
        debugPrint('onCompletion');
        _toNext();
        return null;

      case 'onBufferingUpdate':
        return null;
      default:
    }
    return null;
  }

  updateState(Map arguments) async {
    switch (arguments['State']) {
      case 'started':
        state.value = MediaPlayerStatus.started;

        duration.value = arguments['Duration'];
        final int currentPosition = arguments['CurrentPosition'];
        await progressController.animateTo(currentPosition / duration.value,
            duration: const Duration(seconds: 1), curve: Curves.fastOutSlowIn);
        await progressController.animateTo(1.0,
            curve: Curves.linear,
            duration: Duration(milliseconds: duration.value - currentPosition));
        break;

      case 'paused':
        state.value = MediaPlayerStatus.paused;
        if (arguments['Duration'] != null &&
            arguments['CurrentPosition'] != null) {
          duration.value = arguments['Duration'];
          final int currentPosition = arguments['CurrentPosition'];
          await progressController.animateTo(currentPosition / duration.value,
              duration: const Duration(seconds: 1),
              curve: Curves.fastOutSlowIn);
        }

        break;
      case 'end':
        state.value = MediaPlayerStatus.end;
        progressController.stop();
        break;
    }
  }

  factory MediaPlayerController(
      {AnimationController animationController,
      AnimationController progressController}) {
    _instance ??= MediaPlayerController._internal(
        animationController, progressController);
    return _instance;
  }

  final CustomValueNotifier<MediaPlayerSequenceMode> sequenceMode =
      CustomValueNotifier(MediaPlayerSequenceMode.repeat);

  final LazyValueNotifier<SongInfoProvider> current = LazyValueNotifier(null);
  final LazyValueNotifier<List<SongInfoProvider>> currentPlayList =
      LazyValueNotifier(null);

  final CustomValueNotifier<MediaPlayerStatus> state =
      CustomValueNotifier(MediaPlayerStatus.end);

  final CustomValueNotifier<int> duration = CustomValueNotifier(1);

  MediaPlayerController._internal(
      this.stateChangedController, this.progressController)
      : mediaPlayer = MediaPlayer() {
    initialize();
  }

  final MediaPlayer mediaPlayer;
  final AnimationController stateChangedController;
  final AnimationController progressController;

  void initialize() {
    // bind callback
    mediaPlayer.getChannel().setMethodCallHandler(methodCallHandler);

    // start service instance
    mediaPlayer.init();

    // bind Listener
    current.addListener(() {
      final songInfo = current.value;
      _setDataSource(
          songInfo.filePath, songInfo.title, songInfo.artist, songInfo.album,
          extendFilePath: songInfo.extendFilePath);
      if (lastState == MediaPlayerStatus.started) start();
      return RecentLog.login(
          playlist: currentPlayList.value, songInfo: current.value);
    });

    currentPlayList.addListener(() {
      return RecentLog.login(
          playlist: currentPlayList.value, songInfo: current.value);
    });

    state.addListener(() {
      if (state.value == MediaPlayerStatus.started)
        stateChangedController.animateTo(1.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.fastOutSlowIn);
      else
        stateChangedController.animateBack(0.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.fastOutSlowIn);
    });
  }

  void dispose() {
    current.dispose();
    currentPlayList.dispose();
  }

  static void switchSequenceMode({final MediaPlayerSequenceMode mode}) {
    if (mode != null) {
      _instance.sequenceMode.value = mode;
      return;
    }
    switch (_instance.sequenceMode.value) {
      case MediaPlayerSequenceMode.repeat:
        // TODO: Handle this case.
        _instance.sequenceMode.value = MediaPlayerSequenceMode.shuffle;
        break;
      case MediaPlayerSequenceMode.shuffle:
        // TODO: Handle this case.
        _instance.sequenceMode.value = MediaPlayerSequenceMode.repeat_one;

        break;
      case MediaPlayerSequenceMode.repeat_one:
        // TODO: Handle this case.
        _instance.sequenceMode.value = MediaPlayerSequenceMode.repeat;
        break;
    }
  }

  MediaPlayerStatus lastState = MediaPlayerStatus.paused;

  static playOrPause() {
    switch (_instance.state.value) {
      case MediaPlayerStatus.end:
        // TODO: Handle this case.
        break;
      case MediaPlayerStatus.error:
        // TODO: Handle this case.
        assert(false);
        break;
      case MediaPlayerStatus.started:
        // TODO: Handle this case.
        _instance.pause();
        break;
      case MediaPlayerStatus.paused:
        // TODO: Handle this case.
        _instance.start();
        break;
    }
  }

  start() {
    if (current.value == null) return;
    mediaPlayer.start();
    lastState = MediaPlayerStatus.started;
  }

  pause() {
    mediaPlayer.pause();
    lastState = MediaPlayerStatus.paused;
  }

  _setDataSource(
    final String filePath,
    final String title,
    final String artist,
    final String album, {
    final String extendFilePath,
  }) {
    mediaPlayer.setDataSource(filePath, title, artist, album, extendFilePath);
  }

  seekTo(double value, {final bool skipAnimation = false}) {
    debugPrint("seekTo: $value");
    final position = (duration.value * value).toInt();
    mediaPlayer.seekTo(position);
    if (skipAnimation) progressController.value = value;
  }

  static setTrack(
      {List<SongInfoProvider> playlist, @required SongInfoProvider songInfo}) {
    final currentPlayListDiff =
        playlist == null ? false : _instance.currentPlayList.value != playlist;
    final currentDiff = _instance.current.value != songInfo;

    if (currentPlayListDiff) {
      assert(PlayListRegister.check(playlist), 'This PlayList is illegal. ');
      if (RecentLog.log.isNotEmpty)
        RecentLog.log.last.playList.listManager.removeListener(_listener);
      PlayListRegister(playlist).listManager.addListener(_listener);
      _instance.currentPlayList.value = playlist;
    }
    if (currentDiff) _instance.current.value = songInfo;

    if (currentPlayListDiff) _instance.currentPlayList.notifyListeners();
    if (currentDiff) _instance.current.notifyListeners();
  }

  static _listener() {
    return _instance.currentPlayList.notifyListeners();
  }

  toPrevious() {
    debugPrint('toPrevious');
    if (currentPlayList.value == null) return;
    if (currentIndex == 0) {
      current.value = currentPlayList.value[currentPlayList.value.length - 1];
    } else {
      current.value = currentPlayList.value[currentIndex - 1];
    }
    current.notifyListeners();
  }

  // just skip to next one
  toNext() {
    debugPrint('toNext');
    if (currentPlayList.value == null) return;
    if (currentIndex == currentPlayList.value.length - 1) {
      current.value = currentPlayList.value[0];
    } else {
      current.value = currentPlayList.value[currentIndex + 1];
    }
    current.notifyListeners();
  }

  int indexOf(final SongInfoProvider songInfo) {
    if (currentPlayList.value.contains(songInfo))
      return currentPlayList.value.indexOf(songInfo);
    return null;
  }

  int get currentIndex {
    return currentPlayList.value.indexOf(current.value);
  }

  double volume = 1;

  setVolume(final double volume) {
    this.volume = volume;
    return mediaPlayer.setVolume(this.volume);
  }

  double getVolume() {
    return volume;
  }

  // depend on sequenceMode
  _toNext() {
    switch (sequenceMode.value) {
      case MediaPlayerSequenceMode.repeat:
        // TODO: Handle this case.
        toNext();
        break;

      case MediaPlayerSequenceMode.shuffle:
        // TODO: Handle this case.
        final random = Random();
        int index = random.nextInt(currentPlayList.value.length - 2);
        if (index < currentIndex)
          current.value = currentPlayList.value[index];
        else
          current.value = currentPlayList.value[index + 1];
        current.notifyListeners();
        break;
      case MediaPlayerSequenceMode.repeat_one:
        // TODO: Handle this case.
        start();
        break;
    }
  }
}

class PlayListRegister {
  static final Map<List, PlayListRegister> registers = Map();

  static check(List playList) {
    return registers.containsKey(playList);
  }

  factory PlayListRegister(List playList,
      {ListManager listManager,
      String title,
      Function(int, int) onReorder,
      String subTitle,
      Icon icon}) {
    assert(playList != null);
    if (!registers.containsKey(playList)) {
      assert(title != null);
      registers[playList] = PlayListRegister._internal(
          playList, title, onReorder, listManager, subTitle, icon);
    }
    return registers[playList];
  }

  static unregister(PlayListRegister playListRegister) {
    registers.remove(playListRegister.playList);
  }

  const PlayListRegister._internal(this.playList, this.title, this._onReorder,
      this.listManager, this.subTitle, this.icon);

  final String title;
  final String subTitle;
  final List playList;
  final ListManager listManager;
  final Icon icon;
  final Function(int, int) _onReorder;

  Function(int, int) get onReorder {
    return _onReorder ?? listManager.reorder;
  }

  @override
  String toString() {
    // TODO: implement toString
    return 'PlayListRegister => \n{Title: ' + title + '}';
  }
}

class RecentLog {
  static final List<RecentLog> _cache = List();
  static const Limit = 10;

  static List<RecentLog> get log {
    return _cache;
  }

  static bool login(
      {@required List playlist, @required SongInfoProvider songInfo}) {
    for (int i = 0; i < log.length; i++) {
      if (_cache[i].playList == PlayListRegister(playlist) &&
          _cache[i].songInfo == songInfo) {
        final logged = _cache.removeAt(i);
        _cache.add(logged);
        return true;
      }
    }
    if (_cache.length >= Limit) _cache.removeAt(0);

    _cache.add(RecentLog._internal(
        playList: PlayListRegister(playlist), songInfo: songInfo));
    return true;
  }

  RecentLog._internal({this.playList, this.songInfo});

  final PlayListRegister playList;
  final SongInfoProvider songInfo;

  @override
  String toString() {
    // TODO: implement toString
    return 'RecentLog: ' + playList.title + ' ' + songInfo.title;
  }
}
