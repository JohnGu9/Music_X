import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:music/component.dart';
import 'package:music/controller/MediaPlayerController.dart';
import 'package:music/unit.dart';

import 'CustomImageProvider.dart';

final FlutterAudioQuery audioQuery = FlutterAudioQuery();

class SongInfoManagerConfig {
  static const minDuration = 30 * 1000;
}

class SongInfoManager extends Subscribeable<String, dynamic>
    with BaseListDebug {
  static SongInfoManager instance;
  static final Map<String, SongInfoProvider> songInfoCollection = Map();

  factory SongInfoManager() {
    instance ??= SongInfoManager._internal();
    return instance;
  }

  SongInfoManager._internal() : initialization = Future(_initialize);

  final Future initialization;

  static bool validSongCheck(SongInfo songInfo) {
    if (int.parse(songInfo.duration) < SongInfoManagerConfig.minDuration)
      return false;
    if (!File(songInfo.filePath).existsSync()) return false;
    return true;
  }

  static bool validAlbumCheck(AlbumInfo albumInfo) {
    return true;
  }

  static Future _initialize() async {
    await AnimationStream().idle();
    final List<SongInfo> _songs = await audioQuery.getSongs();
    _songs.forEach((final songInfo) {
      if (validSongCheck(songInfo))
        songInfoCollection[songInfo.filePath] ??=
            SongInfoProvider._internal(songInfo);
    });

    instance.addAll(songInfoCollection.keys);
  }

  Future update() async {
    final List<SongInfo> _list = await audioQuery.getSongs();
    final Map<String, SongInfo> _pathMap =
        Map.fromIterable(_list, key: (final e) {
      return e.filePath;
    }, value: (final e) {
      return e;
    });
    songInfoCollection.removeWhere((final String key, final value) {
      return !_pathMap.containsKey(key);
    }); // release that item was deleted.
    _list.forEach((final songInfo) {
      if (validSongCheck(songInfo))
        songInfoCollection[songInfo.filePath] ??=
            SongInfoProvider._internal(songInfo);
    });

    if (sync(songInfoCollection.keys)) notifyListeners();
  }

  @override
  String convertTo(p) {
    // TODO: implement convertTo
    // master node
    return null;
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    instance = null;
  }
}

class SongInfoMapList extends EfficientMapList<SongInfoProvider, String> {
  static final Map<List<String>, SongInfoMapList> _cache = Map();

  factory SongInfoMapList({@required Subscribeable<String, dynamic> parent}) {
    _cache[parent] ??= SongInfoMapList._internal(parent);
    return _cache[parent];
  }

  SongInfoMapList._internal(Subscribeable<String, dynamic> parent)
      : super(parent: parent);

  @override
  String convertFrom(SongInfoProvider e) {
    // TODO: implement convertFrom
    return e.id;
  }

  @override
  SongInfoProvider convertTo(String p) {
    // TODO: implement convertTo
    return SongInfoProvider(id: p);
  }
}

abstract class InfoProvider {
  const InfoProvider();

  @protected
  String get id; //id should be unique.
}

class SongInfoProvider extends InfoProvider {
  static const unknown = '<unknown>';

  factory SongInfoProvider({final SongInfo songInfo, final String id}) {
    return SongInfoManager.songInfoCollection[id ?? songInfo?.filePath] ??
        InValidSongInfoProvider.instance;
  }

  SongInfoProvider._internal(final SongInfo songInfo)
      : assert(songInfo != null),
        this._songInfo = songInfo,
        _duration = int.parse(songInfo.duration);

  const SongInfoProvider._unknown()
      : _songInfo = null,
        _duration = 0;

  final SongInfo _songInfo;
  final int _duration;

  // id redirect to filePath
  @override
  String get id => _songInfo.filePath;

  SongInfo get songInfo => _songInfo;

  String get title => _songInfo.title;

  String get album => _songInfo.album;

  String get artist => _songInfo.artist;

  int get duration => _duration;

  String get stringDuration {
    final _time = this.duration ~/ 1000;
    return (_time ~/ 60).toString() +
        ' min ' +
        (_time % 60).toString() +
        ' sec ';
  }

  String get filePath => _songInfo.filePath;

  String get fileSize => _songInfo.fileSize;

  // not safe to retrieve
  String get composer =>
      _songInfo.composer == null ? unknown : _songInfo.composer;

  String get year => _songInfo.year == null ? unknown : _songInfo.year;

  String get track => _songInfo.track == null ? unknown : _songInfo.track;

  ArtworkProvider get artwork => ArtworkProvider(id: id);

  String get extendFilePath => null;
}

class InValidSongInfoProvider extends SongInfoProvider {
  static const InValidSongInfoProvider instance = InValidSongInfoProvider();

  const InValidSongInfoProvider() : super._unknown();

  @override
  // TODO: implement title
  String get title => SongInfoProvider.unknown;

  @override
  // TODO: implement album
  String get album => SongInfoProvider.unknown;

  @override
  // TODO: implement artist
  String get artist => SongInfoProvider.unknown;

  @override
  // TODO: implement filePath
  String get filePath => SongInfoProvider.unknown;

  @override
  // TODO: implement id
  String get id => SongInfoProvider.unknown;

  @override
  // TODO: implement fileSize
  String get fileSize => SongInfoProvider.unknown;

  @override
  // TODO: implement composer
  String get composer => SongInfoProvider.unknown;

  @override
  // TODO: implement year
  String get year => SongInfoProvider.unknown;

  @override
  // TODO: implement track
  String get track => SongInfoProvider.unknown;

  @override
  // TODO: implement artwork
  ArtworkProvider get artwork => null;
}

class AlbumManager extends BaseList<AlbumInfoProvider> with ListNotify {
  static final AlbumManager instance = AlbumManager._internal();

  factory AlbumManager() {
    return instance;
  }

  AlbumManager._internal() {
    _initialize();
  }

  bool containsId(final String id) {
    return !every((final e) {
      return e.id != id;
    });
  }

  _initialize() async {
    final albums = await audioQuery.getAlbums();
    addAll(albums.map<AlbumInfoProvider>((final e) {
      return AlbumInfoProvider._internal(e);
    }));
    SongInfoManager.instance.addListener(_listener);
  }

  _listener() async {
    final albums = await audioQuery.getAlbums();
    final map = Map.fromIterable(albums, key: (final e) {
      return e.id;
    }, value: (final e) {
      return e;
    });
    removeWhere((final e) {
      return !map.containsKey(e.id);
    });
    final missing = albums.takeWhile((final e) {
      return !containsId(e.id);
    }).map<AlbumInfoProvider>((final e) {
      return AlbumInfoProvider._internal(e);
    });
    insertAll(0, missing);
  }
}

class AlbumInfoProvider extends Subscribeable<String, String>
    with Reorderable
    implements InfoProvider {
  factory AlbumInfoProvider({
    final AlbumInfo albumInfo,
    final String id,
  }) {
    return AlbumManager.instance.firstWhere((final AlbumInfoProvider e) {
      return e.id == (id ?? albumInfo.id);
    });
  }

  AlbumInfoProvider._internal(this.albumInfo) {
    initialization = _initialize();
    _imageProvider = AlbumArtworkProvider(albumInfo: this);
  }

  Future initialization;

  _initialize() async {
    addAll((await audioQuery.getSongsFromAlbum(albumId: id)).map((final e) {
      return e.filePath;
    }));
    _songInfos = SongInfoMapList(parent: this);
    PlayListRegister(songInfos,
        title: title, onReorder: reorder, listenable: this);
    subscribe(SongInfoManager.instance);
  }

  final AlbumInfo albumInfo;

  List<SongInfoProvider> get songInfos => _songInfos;
  List<SongInfoProvider> _songInfos;

  @override
  // TODO: implement id
  String get id => albumInfo.id;

  String get title => albumInfo.title;

  String get artist => albumInfo.artist;

  AlbumArtworkProvider get artwork => _imageProvider;
  AlbumArtworkProvider _imageProvider;

  @override
  // TODO: implement value
  AlbumInfoProvider get value => this;

  @override
  String convertTo(String p) {
    // TODO: implement convertTo
    return p;
  }
}
