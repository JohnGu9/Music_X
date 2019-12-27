import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_query/flutter_audio_query.dart';
import 'package:musicx/unit/Streams.dart';

class SongInfoManagerConfig {
  static const minDuration = 30 * 1000;
}

enum InfoManagerState {
  idle,
  updating,
  updated,
  unknown,
}

abstract class InfoManager<T extends InfoProvider> extends ChangeNotifier
    implements ValueListenable<InfoManager> {
  List<T> get collection;

  List<T> get newCollection;

  List<T> get disposedCollection;

  InfoManagerState get state;
}

class SongInfoManager extends InfoManager<SongInfoProvider> {
  static SongInfoManager instance;

  static List<String> _ids;
  static List<SongInfoProvider> _collection;
  static Map<String, SongInfoProvider> _idMap;

  static List<SongInfoProvider> _newCollection;
  static List<SongInfoProvider> _disposedCollection;

  static _initialize() async {
    await AnimationStream().idle();
    final audioQuery = FlutterAudioQuery();
    final songList = await audioQuery.getSongs();
    if (instance == null) return;

    songList.retainWhere((final SongInfo songInfo) {
      try {
        return int.parse(songInfo.duration) >=
            SongInfoManagerConfig.minDuration;
      } catch (e) {
        return false;
      }
    });

    _collection = List.generate(songList.length, (final int i) {
      return SongInfoProvider._internal(songList[i]);
    });
    _ids = List.generate(_collection.length, (final int i) {
      return _collection[i].id;
    });
    _idMap = Map.fromIterables(_ids, _collection);

    instance._state = InfoManagerState.updated;
    instance.notifyListeners();
  }

  factory SongInfoManager() {
    instance ??= SongInfoManager._internal();
    return instance;
  }

  static update() async {
    if (instance == null) return;
    instance._state = InfoManagerState.updating;
    instance.notifyListeners();
    await AnimationStream().idle();
    final audioQuery = FlutterAudioQuery();
    final songList = await audioQuery.getSongs();
    if (instance == null) return;
    final List<String> _newIds = List.generate(songList.length, (final int i) {
      return songList[i].filePath;
    }, growable: false);

    _disposedCollection = List();
    _ids.forEach((String id) {
      if (!_newIds.contains(id)) {
        // the file is not exist now.
        final disposed = _idMap.remove(id);
        _collection.remove(disposed);
        _disposedCollection.add(disposed);
      } else
        // the file all ready exist.
        _newIds.remove(id);
    });
    _ids.addAll(_newIds);

    songList.retainWhere((final songInfo) {
      return !_idMap.containsKey(songInfo.filePath);
    });
    _newCollection = List.generate(songList.length, (final int i) {
      return SongInfoProvider._internal(songList[i]);
    }, growable: false);
    _collection.addAll(_newCollection);
    _idMap.addAll(Map.fromIterables(_newIds, _newCollection));
    _ids.retainWhere((String id) {
      return _idMap.containsKey(id);
    });

    instance._state = InfoManagerState.updated;
    instance.notifyListeners();
  }

  SongInfoManager._internal()
      : _initialization = Future(_initialize),
        _state = InfoManagerState.updating;

  @override
  List<SongInfoProvider> get collection => _collection;

  List<String> get ids => _ids;

  Future get initialization => _initialization;
  Future _initialization;

  @override
  get state => _state;
  InfoManagerState _state;

  @override
  dispose() {
    instance = null;
    _collection = null;
    _state = null;
    super.dispose();
  }

  @override
  // TODO: implement value
  SongInfoManager get value => this;

  @override
  // TODO: implement disposedCollection
  List<SongInfoProvider> get disposedCollection => _disposedCollection;

  @override
  // TODO: implement newCollection
  List<SongInfoProvider> get newCollection => _newCollection;
}

abstract class InfoProvider {
  @protected
  String get id; //id should be unique.
}

class SongInfoProvider extends InfoProvider {
  factory SongInfoProvider({final SongInfo songInfo, final String id}) {
    return SongInfoManager._idMap[id ?? songInfo.filePath];
  }

  SongInfoProvider._internal(final SongInfo songInfo)
      : this._songInfo = songInfo,
        _duration = int.parse(songInfo.duration);
  final SongInfo _songInfo;
  final int _duration;

  SongInfo get songInfo => _songInfo;

  String get title => _songInfo.title;

  String get album => _songInfo.album;

  String get artist => _songInfo.artist;

  int get duration => _duration;

  String get filePath => _songInfo.filePath;

  // id redirect to filePath
  String get id => _songInfo.filePath;
}
