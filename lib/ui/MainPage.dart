import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music/component.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/controller/CustomListManager.dart';
import 'package:music/controller/MediaPlayerController.dart';
import 'package:music/ui.dart';
import 'package:music/ui/ManagePage.dart';
import 'package:music/ui/SettingPage.dart';
import 'package:music/unit.dart';
import 'package:music/unit/Streams.dart';

const PageSidePadding =
    const EdgeInsets.symmetric(horizontal: 30, vertical: 20);

class MainPage extends StatelessWidget {
  const MainPage({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return _SecondaryTransitionBuilder(
      animation: GeneralNavigator.of(context).secondaryAnimation,
      child: ValueListenableBuilder(
        valueListenable: ThemeHeritage.of(context).controller,
        builder: _builder,
      ),
    );
  }

  static Widget _builder(BuildContext context, ThemeData value, Widget child) {
    return _PrimaryTransitionBuilder(
      animation: GeneralNavigator.of(context).animation,
      colors: [
        Theme.of(context).primaryColor.withOpacity(0.4),
        Theme.of(context).primaryColor.withOpacity(0.7),
        Theme.of(context).primaryColor,
      ],
    );
  }
}

const titlePadding = const EdgeInsets.symmetric(vertical: 30, horizontal: 30);
// ignore: non_constant_identifier_names
Widget _SecondaryTransitionBuilder({Animation animation, Widget child}) {
  return SecondaryTransition(
    listenable: animation,
    child: child,
  );
}

class _PrimaryTransitionBuilder extends AnimatedWidget {
  _PrimaryTransitionBuilder({Key key, this.animation, List<Color> colors})
      : assert(colors.length == 3),
        curves = const [
          Interval(0.1, 0.4, curve: Curves.easeOut),
          Interval(0.2, 0.6, curve: Curves.easeOut),
          Interval(0.3, 1.0, curve: Curves.easeOut),
        ],
        paints = MultiInkwellPainter.painterGenerator(colors),
        alignments = const [alignment, alignment, alignment],
        _scales = [0.0, 0.0, 0.0],
        delayAnimation = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.5, 1.0, curve: Curves.fastOutSlowIn)),
        controller = ScrollController(),
        super(key: key, listenable: animation);

  static const alignment = Alignment.bottomCenter;

  final Animation<double> animation;
  final Animation<double> delayAnimation;
  final List<Curve> curves;
  final List<Paint> paints;
  final List<Alignment> alignments;
  final List<double> _scales;

  final ScrollController controller;

  bool get isAnimating {
    return animation.status == AnimationStatus.reverse ||
        animation.status == AnimationStatus.forward;
  }

  List<double> get scales {
    for (int i = 0; i < _scales.length; i++)
      _scales[i] = curves[i].transform(animation.value);
    return _scales;
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return CustomPaint(
      willChange: isAnimating,
      painter: MultiInkwellPainter(
          paints: paints,
          alignments: alignments,
          scales: scales,
          label: animation.value),
      child: CustomScrollView(
        physics: Constants.physics,
        controller: controller,
        slivers: <Widget>[
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: 200,
            backgroundColor: Colors.transparent,
            actions: <Widget>[
              IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    return SettingPage.push(context);
                  })
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: titlePadding,
              title: FadeTransition(
                  opacity: delayAnimation,
                  child: Text(
                    'Music X',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  )),
            ),
          ),
          const CupertinoSliverRefreshControl(
            onRefresh: _onRefresh,
          ),
          SliverToBoxAdapter(
            child: FractionalTranslation(
              translation: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .evaluate(delayAnimation),
              child: RepaintBoundary(
                child: StandardListView(
                  scrollController: controller,
                  listManager: LibraryListManager(),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
                height: MediaQuery.of(context).size.height * Panel.startValue +
                    8.0),
          )
        ],
      ),
    );
  }

  static Future<void> _onRefresh() async {
    await SongInfoManager().update();
  }
}

class StandardListView extends StatefulWidget {
  StandardListView(
      {Key key,
      this.scrollController,
      @required this.listManager,
      this.tips = defaultTips})
      : super(key: key);
  final ScrollController scrollController;
  final ListManager listManager;
  final String tips;

  static const defaultTips =
      'Uh, Sorry... \nLooking for audios \nBut found nothing. ';

  @override
  _StandardListViewState createState() => _StandardListViewState();
}

class _StandardListViewState extends State<StandardListView>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Offset> _position;

  ManagerState _lastState = ManagerState.unknown;

  _listener() async {
    await AnimationStream().idle();
    if (!mounted) return;
    if (_lastState != widget.listManager.state) {
      _lastState = widget.listManager.state;
      await _controller.animateBack(0.0, curve: Curves.fastOutSlowIn);
    }
    if (!mounted) return;
    setState(() {
      if (_waitingState) {
        _controller.animateBack(0.0, curve: Curves.fastOutSlowIn);
      } else {
        _controller.animateTo(1.0, curve: Curves.fastOutSlowIn);
      }
    });
  }

  bool get _waitingState {
    return widget.listManager.state == ManagerState.idle ||
        widget.listManager.state == ManagerState.updating;
  }

  _controllerListener(final AnimationStatus status) {
    switch (status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        AnimationStream().removeAnimation(_controller.hashCode);
        break;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        AnimationStream().addAnimation(_controller.hashCode);
        break;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 1), value: 0.0)
      ..addStatusListener(_controllerListener);
    _position = Tween(begin: Offset(0.0, 1.0), end: Offset(0.0, 0.0))
        .animate(_controller);

    _listener();
    widget.listManager.addListener(_listener);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    widget.listManager.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return _builder(context, StandardItemMapList(parent: LibraryListManager()));
  }

  void _onReorder(int oldIndex, int newIndex) {
    widget.listManager.reorder(oldIndex, newIndex);
  }

  Widget _builder(BuildContext context, List<Widget> children) {
    if (_waitingState)
      return const Center(
          child: Padding(
        padding: const EdgeInsets.all(50.0),
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.white)),
      ));
    else if (children.isEmpty)
      return FadeTransition(
        opacity: _controller,
        child: SlideTransition(
          position: _position,
          child: Material(
            color: Theme.of(context).backgroundColor,
            borderRadius: const BorderRadius.all(Constants.radius),
            child: Padding(
              padding: const EdgeInsets.all(50.0),
              child: SizedBox(
                width: 200,
                height: 200,
                child: Text(
                  widget.tips,
                  style: Theme.of(context).textTheme.headline6,
                ),
              ),
            ),
          ),
        ),
      );
    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: _position,
        child: Material(
          color: Theme.of(context).backgroundColor,
          borderRadius: const BorderRadius.all(Constants.radius),
          child: RawReorderableListView(
            header: const _ListHeader(),
            end: SizedBox(height: Constants.radius.y),
            onDragStart: _onDragStart,
            onDragEnd: _onDragEnd,
            children: children,
            onReorder: _onReorder,
            scrollController: widget.scrollController,
            protectAreaBottomRight: 150,
          ),
        ),
      ),
    );
  }

  _onDragStart() {
    return AnimationStream.instance.addAnimation(hashCode);
  }

  _onDragEnd() {
    return AnimationStream.instance.removeAnimation(hashCode);
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: <Widget>[
          const VerticalDivider(width: 15),
          BorderTextButton(
            color: Theme.of(context).primaryColor,
            paddingColor: Theme.of(context).primaryColor,
            text: 'PLAY',
            textColor: Colors.white,
            fontSize: 16,
            icon: Icons.play_arrow,
            onTap: _playButton,
          ),
          const VerticalDivider(width: 10),
          BorderTextButton(
            color: Theme.of(context).primaryColor,
            paddingColor: Theme.of(context).primaryColor,
            text: 'SHUFFLE',
            textColor: Colors.white,
            fontSize: 16,
            icon: Icons.shuffle,
            onTap: _shuffleButton,
          ),
          const VerticalDivider(width: 15),
          BorderTextButton(
            color: Theme.of(context).primaryColor,
            paddingColor: Theme.of(context).primaryColor,
            text: '',
            textColor: Colors.white,
            fontSize: 16,
            icon: Icons.library_music,
            onTap: () {
              return ManagePage.push(context);
            },
          ),
        ],
      ),
    );
  }

  _playButton() {
    final mc = MediaPlayerController();
    if (mc.state.value == MediaPlayerStatus.paused)
      return MediaPlayerController().start();
    else if (mc.state.value == MediaPlayerStatus.end) {
      MediaPlayerController.setTrack(
          playlist: LibraryListManager().songInfos,
          songInfo: LibraryListManager().songInfos.first);
      mc.start();
    }
  }

  _shuffleButton() {
    MediaPlayerController.switchSequenceMode(
        mode: MediaPlayerSequenceMode.shuffle);
    final mc = MediaPlayerController();
    if (mc.currentPlayList.value == null) {
      _playButton();
      return;
    }
    final playlist = mc.currentPlayList.value;
    if (playlist.length <= 1) return;

    final currentIndex = mc.currentIndex;
    if (playlist.length == 2) {
      MediaPlayerController.setTrack(
          songInfo: playlist[currentIndex == 0 ? 1 : 0]);
      mc.start();
      return;
    }

    final index = Random().nextInt(playlist.length - 2);
    MediaPlayerController.setTrack(
        songInfo: playlist[index >= currentIndex ? index + 1 : index]);
    mc.start();
  }
}
