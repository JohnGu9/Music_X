import 'package:flutter/cupertino.dart';
import 'package:music/component.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/ui.dart';

import 'MediaPlayerController.dart';

get dataCenter {
  return GeneralInfoManager();
}

enum ManagerState {
  idle,
  updating,
  updated,
  unknown,
}

class CoreListManager extends Subscribeable<String, dynamic>
    with DataBaseExtendList, DataBaseExtendLinkedList, Reorderable {
  /// This manager for ListManager
  /// [innerList] storage the extend listManagers' table name in a additional table [databaseCustomListManager]
  static const databaseListManager = 'ListManager';
  static const databaseCustomListManager = 'CustomListManager';
  static const fixedListManager = ['library', 'favorite'];
  static final dataCenter = GeneralInfoManager();
  static CoreListManager instance = CoreListManager._internal();

  factory CoreListManager() {
    return instance;
  }

  CoreListManager._internal() : state = ManagerState.idle {
    _listManagers = CustomListManagerMapList(parent: this);
    _initialization = initialize(databaseCustomListManager);
  }

  ManagerState state;

  Future get initialization => _initialization;
  @protected
  Future _initialization;

  List<ListManager> get listManagers => _listManagers;
  @protected
  List<ListManager> _listManagers;

  @protected
  @visibleForTesting
  initialize(String table) async {
    state = ManagerState.updating;
    await bind(database: databaseListManager, table: databaseCustomListManager);
    // after bind, the data will be recovery from database and ready to subscribe parent;
    addListener(_watchOver);
    state = ManagerState.updated;
  }

  @protected
  _watchOver() async {
    assert(this.toSet().length == length, 'illegel new list name');
    final storageNames = await recoverToList();
    final missingNames = takeWhile((final element) {
      return !storageNames.contains(element);
    });
    // release the data
    missingNames.forEach((final element) {
      CustomListManager(table: element).dispose();
    });
  }

  @override
  String convertTo(p) {
    // TODO: implement convertTo
    // master node
    assert(false);
    return null;
  }
}

class CustomListManagerMapList extends EfficientMapList<ListManager, String> {
  CustomListManagerMapList({final List<String> parent}) : super(parent: parent);

  @override
  String convertFrom(ListManager e) {
    // TODO: implement convertFrom
    assert(false);
    return null;
  }

  @override
  ListManager convertTo(String p) {
    // TODO: implement convertTo
    return CustomListManager(table: p);
  }
}

abstract class ListManager extends Subscribeable<String, String>
    with DataBaseExtendList, DataBaseExtendLinkedList, Reorderable {
  ListManager(
      {SubscribeMode subscribeMode = SubscribeMode.onlyDisposeWhileSync,
      @required String table})
      : state = ManagerState.idle,
        super(subscribeMode: subscribeMode) {
    _initialization = initialize(table);
    _songInfos = SongInfoMapList(parent: this);
    PlayListRegister(_songInfos,
        title: table, onReorder: reorder, listManager: this);
  }

  Future get initialization => _initialization;
  Future _initialization;

  ManagerState state;

  List<SongInfoProvider> get songInfos => _songInfos;
  @protected
  List<SongInfoProvider> _songInfos;

  @protected
  @visibleForTesting
  initialize(String table) async {
    state = ManagerState.updating;
    await dataCenter.initialization;
    await bind(database: CoreListManager.databaseListManager, table: table);
    // after bind, the data will be recovery from database and ready to subscribe parent;
    state = ManagerState.updated;
    subscribe(dataCenter);
  }

  @override
  String convertTo(String p) {
    // TODO: implement convertTo
    return p;
  }

  @override
  void dispose() {
    // TODO: implement dispose
    PlayListRegister.unregister(PlayListRegister(_songInfos));
    dropTable();
    super.dispose();
  }
}

class LibraryListManager extends ListManager {
  static LibraryListManager instance = LibraryListManager._internal();

  factory LibraryListManager() {
    return instance;
  }

  LibraryListManager._internal()
      : super(
            subscribeMode: SubscribeMode.addAndDisposeWhileSync,
            table: CoreListManager.fixedListManager[0]);

  @override
  void dispose() {
    // TODO: implement dispose
    assert(false, 'illegel operation');
    super.dispose();
  }
}

class FavoriteListManager extends ListManager {
  static FavoriteListManager instance = FavoriteListManager._internal();

  factory FavoriteListManager() {
    return instance;
  }

  FavoriteListManager._internal()
      : super(table: CoreListManager.fixedListManager[1]);

  static favoriteOrNot(final SongInfoProvider songInfo) async {
    if (songInfo == null) return;
    await instance.initialization;
    if (instance.songInfos.contains(songInfo))
      instance.remove(songInfo.id);
    else
      instance.add(songInfo.id);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    assert(false, 'illegel operation');
    super.dispose();
  }
}

class CustomListManager extends ListManager {
  static Map<String, CustomListManager> _cache = Map();

  factory CustomListManager({@required String table}) {
    _cache[table] ??= CustomListManager._internal(table: table);
    return _cache[table];
  }

  CustomListManager._internal({@required String table})
      : assert(table != null),
        super(table: table);

  @override
  void dispose() {
    // TODO: implement dispose
    _cache.removeWhere((final name, final value) {
      return value == this;
    });
    super.dispose();
  }
}

abstract class WidgetMapList<T> extends EfficientMapList<Widget, T> {
  Map<T, Widget> widgets = Map();

  WidgetMapList({@required List<T> parent}) : super(parent: parent);

  @override
  void operator []=(int index, Widget value) {
    // TODO: implement []=
    widgets[parent[index]] = value;
  }

  @override
  T convertFrom(Widget e) {
    // TODO: implement convertFrom
    assert(false);
    return null;
  }

  @protected
  Widget builder(T p);

  @override
  Widget convertTo(T p) {
    // TODO: implement convertTo
    widgets[p] ??= builder(p);
    return widgets[p];
  }
}

class StandardItemMapList extends WidgetMapList<String> {
  static final Map<List<String>, StandardItemMapList> cache = Map();

  factory StandardItemMapList({@required List<String> parent}) {
    cache[parent] ??= StandardItemMapList._internal(parent: parent);
    return cache[parent];
  }

  StandardItemMapList._internal({@required List<String> parent})
      : super(parent: parent);

  @override
  Widget builder(String p) {
    // TODO: implement builder
    return StandardItem(
      key: ValueKey(p),
      songInfo: SongInfoProvider(id: p),
    );
  }
}

class FavoriteMapList extends WidgetMapList<String> {
  static final Map<List<String>, FavoriteMapList> cache = Map();

  factory FavoriteMapList({@required List<String> parent}) {
    cache[parent] ??= FavoriteMapList._internal(parent: parent);
    return cache[parent];
  }

  FavoriteMapList._internal({@required List<String> parent})
      : super(parent: parent);

  @override
  Widget builder(String p) {
    // TODO: implement builder
    return FavoriteItem(
      key: ValueKey(p),
      songInfo: SongInfoProvider(id: p),
    );
  }
}
