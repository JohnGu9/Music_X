import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:musicx/controller/CustomImageProvider.dart';
import 'package:musicx/controller/CustomSongInfo.dart';
import 'package:musicx/ui/ArtworkView.dart';
import 'package:musicx/unit.dart';
import 'package:musicx/unit/Streams.dart';

abstract class ListViewChildrenBuilder extends ChangeNotifier
    implements ValueListenable<List<Widget>> {
  @protected
  List<Widget> get children;

  @protected
  Widget builder();
}

class LibraryListViewChildrenBuilder extends ListViewChildrenBuilder {
  static LibraryListViewChildrenBuilder instance;

  factory LibraryListViewChildrenBuilder() {
    instance ??= LibraryListViewChildrenBuilder._internal();
    return instance;
  }

  LibraryListViewChildrenBuilder._internal()
      : _initialization = Future(_initialize);

  Future _initialization;

  get initialization => _initialization;

  static _initialize() async {
    final manager = SongInfoManager();
    if (manager == null) return null;
    await manager.initialization;
    await AnimationStream().idle();
    instance._children = Map();

    if (instance == null)
      return manager.removeListener(_listener); // return null

    instance.children = List();
    manager.collection.forEach((final songInfo) {
      //add elements when elements don't exist before.
      final widget = instance.builder(songInfo: songInfo);
      instance._children[songInfo] = widget;
      instance.children.add(widget);
    });

    instance.notifyListeners();
    manager.addListener(_listener);
  }

  static _listener() async {
    final manager = SongInfoManager();
    if (manager == null) return null;
    await manager.initialization;
    await AnimationStream().idle();
    instance._children = Map();

    if (instance == null)
      return manager.removeListener(_listener); // return null

    manager.disposedCollection?.forEach((final songInfo) {
      instance._children.remove(songInfo);
      instance.children.remove(songInfo);
    });
    manager.newCollection?.forEach((final songInfo) {
      //add elements when elements don't exist before.
      instance._children[songInfo] ??= instance.builder(songInfo: songInfo);
      if (!instance.children.contains(instance._children[songInfo]))
        instance.children.insert(0, instance._children[songInfo]);
    });

    instance.notifyListeners();
    return manager;
  }

  @override
  Widget builder({SongInfoProvider songInfo}) {
    // TODO: implement builder
    return LibraryItem(
      key: ValueKey(songInfo),
      songInfo: songInfo,
    );
  }

  reorder(int oldIndex, int newIndex) {
    return Constants.reorder(children, oldIndex, newIndex);
  }

  @override
  // TODO: implement children
  List<Widget> children;
  Map<SongInfoProvider, Widget> _children;

  @override
  // TODO: implement value
  List<Widget> get value => children;
}

class LibraryItem extends StatelessWidget {
  const LibraryItem({Key key, this.songInfo}) : super(key: key);
  final SongInfoProvider songInfo;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return ListTile(
      onTap: _onTap,
      leading: ArtworkListView(
        artwork: ArtworkProvider(filePath: songInfo.filePath),
      ),
      title: Text(songInfo.title),
      subtitle: RichText(
        text: TextSpan(
            style: TextStyle(
                inherit: true,
                color:
                    Theme.of(context).textTheme.body1.color.withOpacity(0.7)),
            children: [
              TextSpan(
                text: songInfo.album,
              ),
              TextSpan(
                text: ' · ',
              ),
              TextSpan(
                text: songInfo.artist,
              ),
            ]),
      ),
    );
  }

  void _onTap() {}
}
