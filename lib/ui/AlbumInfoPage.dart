import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music/component.dart';
import 'package:music/controller/CustomImageProvider.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/controller/MediaPlayerController.dart';
import 'package:music/ui.dart';
import 'package:music/ui/ManagePage.dart';
import 'package:music/unit.dart';

class AlbumInfoHeritage extends InheritedWidget {
  const AlbumInfoHeritage({final Key key, final Widget child, this.albumInfo})
      : super(key: key, child: child);

  final AlbumInfoProvider albumInfo;

  static AlbumInfoHeritage of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AlbumInfoHeritage>();
  }

  @override
  bool updateShouldNotify(AlbumInfoHeritage oldWidget) {
    // TODO: implement updateShouldNotify
    return oldWidget.albumInfo != albumInfo;
  }
}

Widget _builder(BuildContext context) {
  return null;
}

class AlbumInfoPage extends StatelessWidget {
  const AlbumInfoPage._internal({Key key}) : super(key: key);

  static push(BuildContext context, final AlbumInfoProvider albumInfo) {
    return GeneralPageRoute.push(context, _builder, transitionBuilder:
        (BuildContext context, final Animation<double> animation,
            final Animation<double> secondaryAnimation, final Widget child) {
      return AlbumInfoHeritage(
        albumInfo: albumInfo,
        child: SecondaryTransition(
          listenable: secondaryAnimation,
          child: _PrimaryTransition(
            animation: animation,
            child: const AlbumInfoPage._internal(),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Material(
      shape: shape,
      clipBehavior: Clip.hardEdge,
      color: Theme.of(context).primaryColor,
      child: const _Detail(),
    );
  }
}

const textStyle = TextStyle(color: Colors.white);

class _Detail extends StatelessWidget {
  const _Detail({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    final ScrollController scrollController = ScrollController();
    final AlbumInfoProvider albumInfo = AlbumInfoHeritage.of(context).albumInfo;
    final subAnimation = CurvedAnimation(
        parent: GeneralNavigator.of(context).animation,
        curve: const Interval(0.5, 1));
    final offset = Tween(begin: const Offset(0, 1), end: const Offset(0, 0))
        .animate(subAnimation);

    Widget _listBuilder(final BuildContext context, final List<String> value,
        final Widget child) {
      final songInfos = albumInfo.songInfos;
      return SliverToBoxAdapter(
        child: SlideTransition(
          position: offset,
          child: RawReorderableListView(
            children: <Widget>[
              for (final songInfo in songInfos)
                AlbumSongInfoItem(
                  key: ValueKey(songInfo),
                  songInfo: songInfo,
                ),
            ],
            onReorder: albumInfo.reorder,
            scrollController: scrollController,
            header: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: FadeTransition(
                opacity: const AlwaysStoppedAnimation(0.7),
                child: ListTile(
                  title: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '${albumInfo.length}  Songs',
                      style: textStyle,
                    ),
                  ),
                  subtitle: Text(
                    albumInfo.artist,
                    style: textStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget _appBarBuilder(BuildContext context, Palette value, Widget child) {
      Color _titleColor() {
        if (value == null) return Colors.white;
        if (value.dominantTitleText == Colors.transparent) return Colors.white;
        return albumInfo.artwork.palette.dominantTitleText;
      }

      return SliverAppBar(
        backgroundColor: Theme.of(context).backgroundColor,
        expandedHeight: MediaQuery.of(context).size.width * 0.9,
        flexibleSpace: GeneralNavigator.of(context).gestureBuilder(
          context: context,
          child: FlexibleSpaceBar(
            centerTitle: true,
            title: LayoutBuilder(builder:
                (final BuildContext context, final BoxConstraints constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                child: FadeTransition(
                  opacity: subAnimation,
                  child: Text(
                    albumInfo.title,
                    style: TextStyle(color: _titleColor()),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }),
            background: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              layoutBuilder: Constants.expandedLayoutBuilder,
              child: Container(
                key: ValueKey(value?.dominant),
                foregroundDecoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: (value == null ||
                                value.dominant == Colors.transparent)
                            ? [
                                Colors.transparent,
                                Colors.transparent,
                              ]
                            : [
                                value.dominant.withOpacity(0.0),
                                value.dominant.withOpacity(0.7),
                              ],
                        stops: const [
                      0.5,
                      0.9,
                    ])),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: Constants.physics,
      controller: scrollController,
      slivers: <Widget>[
        DelayValueListenableBuilder(
          listenable: albumInfo.artwork,
          builder: (final context, final value, final child) {
            return DelayValueListenableBuilder(
              listenable: albumInfo.artwork?.palette,
              builder: _appBarBuilder,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                layoutBuilder: Constants.expandedLayoutBuilder,
                child: value == null
                    ? FittedBox(
                        fit: BoxFit.contain,
                        child: ScaleTransition(
                          scale: const AlwaysStoppedAnimation(0.5),
                          child: Icon(
                            Icons.music_note,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      )
                    : Image(
                        key: ValueKey(value),
                        image: value,
                        fit: BoxFit.cover,
                      ),
              ),
            );
          },
        ),
        ValueListenableBuilder(
            valueListenable: albumInfo, builder: _listBuilder),
        SliverToBoxAdapter(
          child: SizedBox(
              height:
                  MediaQuery.of(context).size.height * Panel.startValue + 8.0),
        )
      ],
    );
  }
}

class _PrimaryTransition extends AnimatedWidget {
  static final Tween _layoutOffset =
      Tween(begin: const Offset(0, 1), end: const Offset(0, 0));
  static final ColorTween _colorTween =
      ColorTween(begin: Colors.transparent, end: Colors.black12);

  const _PrimaryTransition(
      {Key key, @required this.animation, @required this.child})
      : super(key: key, listenable: animation);
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      color: _colorTween.evaluate(animation),
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: FractionalTranslation(
        translation: _layoutOffset.evaluate(animation),
        child: child,
      ),
    );
  }
}

class AlbumInfoPagePreview extends StatelessWidget {
  static push(BuildContext context, final AlbumInfoProvider albumInfo) {
    return GeneralPageRoute.push(context, _builder, transitionBuilder:
        (BuildContext context, final Animation<double> animation,
            final Animation<double> secondaryAnimation, final Widget child) {
      return AlbumInfoHeritage(
        albumInfo: albumInfo,
        child: SecondaryTransition(
          listenable: secondaryAnimation,
          child: FadeTransition(
            opacity: animation,
            child: const AlbumInfoPagePreview._internal(),
          ),
        ),
      );
    });
  }

  const AlbumInfoPagePreview._internal({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    final albumInfo = AlbumInfoHeritage.of(context).albumInfo;

    void _onTap() {
      Navigator.of(context).pop();
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(
          color: Colors.black12,
          child: GestureDetector(
            onTap: _onTap,
          ),
        ),
        Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: AlbumItemView(
              albumInfo: albumInfo,
            ),
          ),
        ),
      ],
    );
  }
}

class AlbumSongInfoItem extends StatefulWidget {
  AlbumSongInfoItem({Key key, this.songInfo}) : super(key: key);
  final SongInfoProvider songInfo;

  @override
  _AlbumSongInfoItemState createState() => _AlbumSongInfoItemState();
}

class _AlbumSongInfoItemState extends State<AlbumSongInfoItem>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    void _onTap() {
      final AlbumInfoProvider albumInfo =
          AlbumInfoHeritage.of(context).albumInfo;
      MediaPlayerController.setTrack(
          songInfo: widget.songInfo, playlist: albumInfo.songInfos);
      MediaPlayerController().start();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ListTile(
          onTap: _onTap,
          title: Text(widget.songInfo.title),
          trailing: IconButton(
            icon: const Icon(Icons.expand_more),
            onPressed: _onPressed,
          ),
        ),
        SizeTransition(
          sizeFactor: _controller,
          axis: Axis.vertical,
          child: FadeTransition(
            opacity: _controller,
            child: _SongInfoDetail(
              songInfo: widget.songInfo,
            ),
          ),
        ),
      ],
    );
  }

  _onPressed() {
    _controller.value == 0
        ? _controller.animateTo(
            1.0,
            curve: Curves.fastOutSlowIn,
          )
        : _controller.animateBack(
            0.0,
            curve: Curves.fastOutSlowIn,
          );
  }
}

class _SongInfoDetail extends StatelessWidget {
  const _SongInfoDetail({Key key, @required this.songInfo}) : super(key: key);
  final SongInfoProvider songInfo;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: SongInfoArtworkView(
              artwork: songInfo.artwork,
            ),
          ),
          const VerticalDivider(
            color: Colors.transparent,
          ),
          Expanded(
            child: FadeTransition(
              opacity: const AlwaysStoppedAnimation(0.7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Duration: ${songInfo.stringDuration}'),
                  Text('File Path: ${songInfo.filePath}'),
                  Text('File Size: ${songInfo.fileSize}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
