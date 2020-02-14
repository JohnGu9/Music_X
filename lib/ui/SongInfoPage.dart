import 'package:flutter/material.dart';
import 'package:music/component.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/controller/CustomListManager.dart';
import 'package:music/controller/MediaPlayerController.dart';
import 'package:music/ui.dart';
import 'package:music/unit.dart';

class SongInfoHeritage extends InheritedWidget {
  const SongInfoHeritage({Key key, Widget child, this.songInfo})
      : super(key: key, child: child);

  final SongInfoProvider songInfo;

  static SongInfoHeritage of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SongInfoHeritage>();
  }

  @override
  bool updateShouldNotify(SongInfoHeritage oldWidget) {
    // TODO: implement updateShouldNotify
    return oldWidget.songInfo != songInfo;
  }
}

class SongInfoPage extends StatelessWidget {
  static push(BuildContext context, final SongInfoProvider songInfo) {
    return GeneralPageRoute.push(context, _builder, transitionBuilder:
        (BuildContext context, final Animation<double> animation,
            final Animation<double> secondaryAnimation, final Widget child) {
      return SongInfoHeritage(
        songInfo: songInfo,
        child: SongInfoPage._internal(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
        ),
      );
    });
  }

  static Widget _builder(BuildContext context) {
    return null;
  }

  const SongInfoPage._internal({
    Key key,
    @required this.animation,
    @required this.secondaryAnimation,
    this.gesture,
    this.songInfo,
  }) : super(key: key);
  final Animation animation;
  final Animation secondaryAnimation;
  final Widget gesture;
  final SongInfoProvider songInfo;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return RepaintBoundary(
      child: GeneralNavigator.of(context).gestureBuilder(
        context: context,
        child: SecondaryTransition(
          listenable: secondaryAnimation,
          child: RepaintBoundary(
            child: _SongInfoPage(
              animation: animation,
              gesture: gesture,
            ),
          ),
        ),
      ),
    );
  }
}

class _SongInfoPage extends AnimatedWidget {
  static final Tween _layoutOffset =
      Tween(begin: const Offset(0, 1), end: const Offset(0, 0));
  static final ColorTween _colorTween =
      ColorTween(begin: Colors.transparent, end: Colors.black12);

  _SongInfoPage({Key key, this.animation, this.gesture})
      : super(key: key, listenable: animation);
  final Animation animation;
  final Widget gesture;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Container(
      color: _colorTween.evaluate(animation),
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: FractionalTranslation(
        translation: _layoutOffset.evaluate(animation),
        child: Material(
          shape: shape,
          elevation: 6.0,
          color: Theme.of(context).primaryColor,
          clipBehavior: Clip.hardEdge,
          child: const _Layout1(),
        ),
      ),
    );
  }
}

class _Layout1 extends StatelessWidget {
  const _Layout1({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return const LayoutBuilder(
      builder: _builder,
    );
  }

  static Widget _builder(BuildContext context, BoxConstraints constraints) {
    const curve = Interval(0.5, 1);
    final tween = Tween(begin: const Offset(0, 1), end: const Offset(0, 0))
        .animate(CurvedAnimation(
            parent: GeneralNavigator.of(context).animation, curve: curve));
    return Column(
      children: <Widget>[
        SizedBox(
          height: constraints.maxHeight * (1 - _sheetSize),
          child: Column(
            children: <Widget>[
              const Icon(Icons.remove),
              const Expanded(child: _SongInfoView()),
              const ButtonRow(),
              const SizedBox(height: 10)
            ],
          ),
        ),
        Expanded(
          child: SlideTransition(
            position: tween,
            child: const _Layout2(),
          ),
        ),
      ],
    );
  }
}

class ButtonRow extends StatelessWidget {
  const ButtonRow({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BorderTextButton(
          color: Theme.of(context).primaryColor,
          paddingColor: Theme.of(context).primaryColor,
          text: 'PLAY',
          textColor: Colors.white,
          fontSize: 16,
          icon: Icons.play_arrow,
          onTap: () {
            MediaPlayerController.setTrack(
                playlist: LibraryListManager().songInfos,
                songInfo: SongInfoHeritage.of(context).songInfo);
            MediaPlayerController().start();
          },
        ),
        const VerticalDivider(width: 10),
        BorderTextButton(
          color: Theme.of(context).primaryColor,
          paddingColor: Theme.of(context).primaryColor,
          text: 'NEXT PLAY',
          textColor: Colors.white,
          fontSize: 16,
          icon: Icons.playlist_add,
          onTap: () {
            final SongInfoProvider thisSongInfo =
                SongInfoHeritage.of(context).songInfo;
            if (thisSongInfo == null) return;
            if (!MediaPlayerController()
                .currentPlayList
                .value
                .contains(thisSongInfo)) return;

            final currentIndex = MediaPlayerController().currentIndex;
            final thisIndex = MediaPlayerController()
                .currentPlayList
                .value
                .indexOf(thisSongInfo);
            PlayListRegister(MediaPlayerController().currentPlayList.value)
                ?.onReorder(thisIndex, currentIndex + 1);
            Toast.easeMassage(context,
                text:
                    '${thisSongInfo.songInfo.title} will be played on the next');
          },
        ),
        const VerticalDivider(width: 10),
        BorderTextButton(
          color: Theme.of(context).primaryColor,
          paddingColor: Theme.of(context).primaryColor,
          text: '',
          textColor: Colors.white,
          fontSize: 16,
          customIcon: FavoriteButtonIcon(
            songInfo: SongInfoHeritage.of(context).songInfo,
          ),
          onTap: () {
            FavoriteListManager.favoriteOrNot(
                SongInfoHeritage.of(context).songInfo);
          },
        ),
      ],
    );
  }
}

class _SongInfoView extends StatelessWidget {
  const _SongInfoView({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: SongInfoArtworkView(
              artwork: SongInfoHeritage.of(context).songInfo.artwork,
              color: Theme.of(context).backgroundColor,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SelectableText(
                SongInfoHeritage.of(context).songInfo.title,
                style: Theme.of(context)
                    .textTheme
                    .headline5
                    .apply(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _sheetSize = 0.63;

class _Layout2 extends StatelessWidget {
  const _Layout2({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Material(
      borderRadius: borderRadius,
      color: Theme.of(context).backgroundColor,
      elevation: 6.0,
      clipBehavior: Clip.hardEdge,
      child: CustomScrollView(
        physics: Constants.physics,
        slivers: const <Widget>[
          SliverToBoxAdapter(child: _Detail()),
          SliverBottomPadding,
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    final songInfo = SongInfoHeritage.of(context).songInfo;
    final theme = Theme.of(context);
    return Padding(
      padding: PageSidePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.album),
            title: SelectableText(
              songInfo.album,
              style: theme.textTheme.bodyText2,
            ),
            subtitle: const Text('Album'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person),
            title: SelectableText(
              songInfo.artist,
              style: theme.textTheme.bodyText2,
            ),
            subtitle: const Text('Artist'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.closed_caption),
            title: SelectableText(
              songInfo.composer,
              style: theme.textTheme.bodyText2,
            ),
            subtitle: const Text('Composer'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: SelectableText(
              songInfo.year,
              style: theme.textTheme.bodyText2,
            ),
            subtitle: const Text('Release Year'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.art_track),
            title: SelectableText(
              songInfo.track,
              style: theme.textTheme.bodyText2,
            ),
            subtitle: const Text('Track amount'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time),
            title: SelectableText(
              songInfo.stringDuration,
              style: theme.textTheme.bodyText2,
            ),
            subtitle: const Text('Duration'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.find_in_page),
            title: SelectableText(
              songInfo.filePath,
              style: theme.textTheme.bodyText2,
            ),
            subtitle: const Text('File Path'),
          ),
        ],
      ),
    );
  }
}
