import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:music/component/AsyncTaskManager.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/unit.dart';
import 'package:music/unit/MediaMetadataRetriever.dart';
import 'package:music/unit/Streams.dart';

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
      await SchedulerBinding.instance.scheduleTask(fn, Priority.animation);
      await Future.delayed(const Duration(milliseconds: 200));
      yield fn;
    }
  }
}

abstract class CustomImageProvider<T extends ImageProvider>
    extends ChangeNotifier implements ValueListenable<T> {
  @protected
  String get id;
}

class ArtworkProvider extends CustomImageProvider<MemoryImage> {
  static final Map _cache = Map<String, ArtworkProvider>();
  static final LoadImageTaskManager manager = LoadImageTaskManager();

  factory ArtworkProvider({@required String id}) {
    _cache[id] ??= ArtworkProvider._internal(id);
    return _cache[id];
  }

  ArtworkProvider._internal(this.filePath)
      : _state = CustomImageProviderStatus.updating {
    _initialization = manager.runTask(_initialize, AsyncTaskPriority.NORMAL);
  }

  final String filePath;
  Uint8List data;

  Future get initialization => _initialization;
  Future _initialization;

  _initialize() async {
    if (filePath == null) {
      _state = CustomImageProviderStatus.updated;
      notifyListeners();
      return;
    }

    assert(await File(filePath).exists());
    data = await MediaMetadataRetriever.getEmbeddedPicture(filePath: filePath);
    _state = CustomImageProviderStatus.updated;
    notifyListeners();
  }

  CustomImageProviderStatus get state => _state;
  CustomImageProviderStatus _state;

  @override
  MemoryImage get value {
    if (data == null)
      return null;
    else if (_provider == null || _provider.bytes != data)
      _provider = MemoryImage(data);

    return _provider;
  }

  MemoryImage _provider;

  @override
  // TODO: implement id
  String get id => filePath;

  Palette get palette {
    _palette ??= Palette.generate(this);
    return _palette;
  }

  Palette _palette;
}

class Palette extends ChangeNotifier implements ValueListenable<Palette> {
  static Palette generate(ArtworkProvider artwork) {
    final palette = Palette(artwork: artwork);
    return palette;
  }

  Palette({@required this.artwork}) {
    _listener();
    artwork.addListener(_listener);
  }

  final ArtworkProvider artwork;

  _listener() async {
    if (artwork.data == null) return clear();
    final res = await Native.palette(data: artwork.data);
    fromMap(res);
  }

  int count = 0;

  clear() {
    dominant = Colors.transparent;
    vibrant = Colors.transparent;
    muted = Colors.transparent;

    dominantTitleText = null;
    vibrantTitleText = null;
    mutedTitleText = null;
  }

  fromMap(Map map) {
    dominant = map['Dominant'] ?? Colors.transparent;
    vibrant = map['Vibrant'] ?? Colors.transparent;
    muted = map['Muted'] ?? Colors.transparent;
    dominantTitleText = map['DominantTitleText'];
    vibrantTitleText = map['VibrantTitleText'];
    mutedTitleText = map['MutedTitleText'];
    notifyListeners();
  }

  Color dominant = Colors.transparent;
  Color vibrant = Colors.transparent;
  Color muted = Colors.transparent;

  Color dominantTitleText;
  Color vibrantTitleText;
  Color mutedTitleText;

  @override
  void notifyListeners() {
    // TODO: implement notifyListeners
    count++;
    super.notifyListeners();
  }

  @override
  // TODO: implement value
  Palette get value => this;
}

class AlbumArtworkProvider extends ArtworkProvider {
  static final Map<AlbumInfoProvider, AlbumArtworkProvider> _cache = Map();
  static final AlbumManager albumManager = AlbumManager()
    ..addListener(_listener);

  static void _listener() {
    /// gc
    _cache.removeWhere((final AlbumInfoProvider key, final value) {
      return !albumManager.contains(key);
    });
  }

  factory AlbumArtworkProvider({final AlbumInfoProvider albumInfo}) {
    _cache[albumInfo] ??= AlbumArtworkProvider._internal(albumInfo);
    return _cache[albumInfo];
  }

  AlbumArtworkProvider._internal(this.albumInfo) : super._internal(null) {
    _init();
  }

  _init() async {
    await albumInfo.initialization;
    for (final e in albumInfo.songInfos) await e.artwork.initialization;

    final _set = Set<ArtworkProvider>();
    albumInfo.songInfos.forEach((final e) {
      if (e.artwork?.data != null) _set.add(e.artwork);
    });
    available = _set;
    _simple = available.isEmpty ? null : available.first;

    albumInfo.addListener(update);
    albumInfo.songInfos.forEach((final e) {
      e.artwork?.addListener(update);
    });

    notifyListeners();
  }

  void update() {
    final _set = Set<ArtworkProvider>();
    albumInfo.songInfos.forEach((final e) {
      if (e.artwork?.data != null) _set.add(e.artwork);
    });
    available = _set;
    _simple = available.isEmpty ? null : available.first;

    albumInfo.songInfos.forEach((final e) {
      e.artwork?.removeListener(update);
      e.artwork?.addListener(update);
    });
    notifyListeners();
  }

  final AlbumInfoProvider albumInfo;

  ArtworkProvider _simple;

  Iterable<ArtworkProvider> available;

  @override
  // TODO: implement value
  MemoryImage get value => _simple?.value;

  @override
  // TODO: implement state
  CustomImageProviderStatus get state => _simple?.state;

  @override
  // TODO: implement palette
  Palette get palette => _simple?.palette;
}
