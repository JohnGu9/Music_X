import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music/controller/CustomImageProvider.dart';
import 'package:music/controller/CustomListManager.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/controller/MediaPlayerController.dart';
import 'package:music/ui.dart';
import 'package:music/ui/ArtworkView.dart';

abstract class ListViewChildrenBuilder<T> extends ChangeNotifier
    implements ValueListenable<List<Widget>> {
  @protected
  List<Widget> get children;

  @override
  List<Widget> get value => children;

  List<T> get data;

  @protected
  Widget builder();
}

class StandardItem extends StatelessWidget {
  const StandardItem({Key key, this.songInfo}) : super(key: key);
  final SongInfoProvider songInfo;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return ListTile(
      onTap: _onTap,
      leading: ArtworkListView(
        artwork: songInfo.artwork,
      ),
      title: Text(songInfo.title),
      subtitle: RichText(
        text: TextSpan(
            style: TextStyle(
                inherit: true,
                color:
                    Theme.of(context).textTheme.body1.color.withOpacity(0.7)),
            children: [
              TextSpan(text: songInfo.album),
              const TextSpan(text: ' · '),
              TextSpan(text: songInfo.artist),
            ]),
      ),
      trailing: IconButton(
          icon: Icon(Icons.more_horiz),
          onPressed: () {
            SongInfoPage.push(context, songInfo);
          }),
    );
  }

  _onTap() {
    MediaPlayerController.setTrack(
        playlist: LibraryListManager().songInfos, songInfo: songInfo);
    if (MediaPlayerController().state.value != MediaPlayerStatus.started)
      MediaPlayerController().start();
  }
}

class FavoriteItem extends StatelessWidget {
  const FavoriteItem({Key key, this.songInfo}) : super(key: key);
  final SongInfoProvider songInfo;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return AspectRatio(
      aspectRatio: 4,
      child: _FavoriteItemBackground(
        artwork: songInfo.artwork,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _onTap,
            child: Center(
              child: ValueListenableBuilder(
                valueListenable: songInfo.artwork.palette,
                builder: _builder,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _disLike(final context) {
    return AlertDialog(
      title: Text('Remove ${songInfo.title} from \'Favorite\' ?'),
      actions: <Widget>[
        FlatButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Confirm')),
        FlatButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel')),
      ],
    );
  }

  _onTap() {
    MediaPlayerController.setTrack(
        playlist: FavoriteListManager().songInfos, songInfo: songInfo);
    if (MediaPlayerController().state.value != MediaPlayerStatus.started)
      MediaPlayerController().start();
  }

  Widget _builder(BuildContext context, Palette value, Widget child) {
    final color = value.dominantTitleText == null
        ? Theme.of(context).textTheme.body2.color
        : value.dominantTitleText;
    return ListTile(
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          songInfo.title,
          style: TextStyle(
            fontSize: Theme.of(context).textTheme.body1.fontSize + 3.0,
            color: color,
          ),
        ),
      ),
      subtitle: RichText(
        text: TextSpan(
            style: TextStyle(
              color: color.withOpacity(0.7),
            ),
            children: [
              TextSpan(text: songInfo.album),
              const TextSpan(text: ' · '),
              TextSpan(text: songInfo.artist),
            ]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.favorite,
              color: color,
            ),
            onPressed: () {
              showCupertinoDialog(context: context, builder: _disLike);
            },
          ),
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: color,
            ),
            onPressed: () {
              SongInfoPage.push(context, songInfo);
            },
          ),
        ],
      ),
    );
  }
}

class _FavoriteItemBackground extends StatefulWidget {
  const _FavoriteItemBackground({Key key, this.child, this.artwork})
      : super(key: key);
  final Widget child;
  final ArtworkProvider artwork;

  @override
  __FavoriteItemBackgroundState createState() =>
      __FavoriteItemBackgroundState();
}

class __FavoriteItemBackgroundState extends State<_FavoriteItemBackground> {
  _onChanged() {
    return setState(() {});
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    widget.artwork.addListener(_onChanged);
    widget.artwork.palette.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_FavoriteItemBackground oldWidget) {
    // TODO: implement didUpdateWidget
    if (oldWidget.artwork != widget.artwork) {
      oldWidget.artwork.removeListener(_onChanged);
      oldWidget.artwork.palette.removeListener(_onChanged);
      widget.artwork.addListener(_onChanged);
      widget.artwork.palette.addListener(_onChanged);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    widget.artwork.removeListener(_onChanged);
    widget.artwork.palette.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          child: AnimatedSwitcher(
            layoutBuilder: defaultLayoutBuilder,
            duration: const Duration(milliseconds: 500),
            child: widget.artwork.value == null
                ? const SizedBox()
                : Image(
                    key: ValueKey(widget.artwork.data),
                    image: widget.artwork.value,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        RepaintBoundary(
          child: AnimatedSwitcher(
            layoutBuilder: defaultLayoutBuilder,
            duration: const Duration(milliseconds: 500),
            child: Container(
              key: ValueKey(widget.artwork.palette.count),
              foregroundDecoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.artwork.palette.dominant,
                    Colors.transparent,
                  ],
                  stops: const [0.2, 1.0],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }

  static Widget defaultLayoutBuilder(
      Widget currentChild, List<Widget> previousChildren) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ...previousChildren,
        if (currentChild != null) currentChild,
      ],
      alignment: Alignment.center,
    );
  }
}
