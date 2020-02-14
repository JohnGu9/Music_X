import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:music/component.dart';
import 'package:music/controller/CustomInfoProvider.dart';
import 'package:music/controller/CustomListManager.dart';
import 'package:music/controller/MediaPlayerController.dart';
import 'package:music/ui.dart';
import 'package:music/unit.dart';
import 'package:music/unit/Constants.dart';
import 'package:music/unit/Streams.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

routePop(BuildContext context) {
  bool notOpened() {
    return _PanelState._controller.value - _PanelState._controller.upperBound >
        0.001;
  }

  bool notClosed() {
    return _PanelState._controller.value - Panel.startValue > 0.001;
  }

  if (_PanelState._controller.isAnimating) return;
  if (notOpened() && notClosed()) {
    debugPrint(
        'panel controller in progress: ${_PanelState._controller.value}');
    return;
  }
  if (notClosed()) {
    final simulation = SpringSimulation(
        spring, _PanelState._controller.value, Panel.startValue, 0);
    _PanelState._controller.animateWith(simulation);
    return;
  }

  if (Navigator.of(context).canPop())
    Navigator.pop(context);
  else
    Native.moveTaskToBack();
}

class Panel extends StatefulWidget {
  const Panel({Key key}) : super(key: key);
  static const installDuration = const Duration(seconds: 1);
  static double startValue = 0.11;

  @override
  _PanelState createState() => _PanelState();
}

class _PanelState extends State<Panel> with SingleTickerProviderStateMixin {
  static final Tween<Offset> _tween =
      Tween(begin: const Offset(0, 1), end: const Offset(0, 0));
  static final ColorTween _colorTween =
      ColorTween(begin: Colors.transparent, end: Colors.black54);

  static const _duration = Duration(milliseconds: 600);

  static AnimationController _controller;
  static Animation _animation;

  static void nullFn() {}

  void _onChanged() {
    setState(nullFn);
  }

  void _onStatusChanged(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        AnimationStream().addAnimation(hashCode);
        break;
      case AnimationStatus.dismissed:
      case AnimationStatus.completed:
        AnimationStream().removeAnimation(hashCode);
        break;
    }
  }

  Widget content;

  Widget _contentBuilder() {
    return Container(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: [
        BoxShadow(
            color: Colors.grey[900].withOpacity(0.4),
            spreadRadius: 5.0,
            blurRadius: 5.0)
      ]),
      child: CustomPageRouteGestureDetector(
        direction: AxisDirection.up,
        enabledCallback: _enabledCallback,
        onStartPopGesture: _onStartPopGesture,
        child: _PanelContent(listenable: _animation),
      ),
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addListener(_onChanged)
      ..addStatusListener(_onStatusChanged)
      ..animateTo(
        Panel.startValue,
        duration: Panel.installDuration,
        curve: Curves.fastOutSlowIn,
      );
    _animation = CurvedAnimation(
        parent: _controller, curve: Interval(Panel.startValue, 1.0));
    content = _contentBuilder();
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
    return Stack(
      fit: StackFit.expand,
      overflow: Overflow.visible,
      children: <Widget>[
        IgnorePointer(
          ignoring: true,
          child: Container(
            color: _colorTween.evaluate(_animation),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: FractionalTranslation(
            translation: _tween.evaluate(_controller),
            child: content,
          ),
        ),
      ],
    );
  }

  static bool _enabledCallback() {
    return true;
  }

  CustomPageController _onStartPopGesture() {
    return _Controller(
        controller: _controller,
        minValue: Panel.startValue,
        size: MediaQuery.of(context).size.height);
  }
}

const spring = SpringDescription(
  mass: 30,
  stiffness: 1,
  damping: 1,
);

class _Controller<T> extends CustomPageController<T> {
  _Controller(
      {@required AnimationController controller,
      @required double minValue,
      @required this.size})
      : routeControllerMinValue = minValue,
        routeControllerMaxValue = controller.upperBound,
        super(controller: controller);
  @override
  final double routeControllerMinValue;
  @override
  final double routeControllerMaxValue;

  final double size;

  @override
  void dragEnd(double velocity) {
    final animateForward = velocity < minFlingVelocity;
    if (animateForward) {
      final simulation = SpringSimulation(
          spring, controller.value, routeControllerMaxValue, -velocity / size);
      controller.animateWith(simulation);
    } else {
      final simulation = SpringSimulation(
          spring, controller.value, routeControllerMinValue, -velocity / size);
      controller.animateWith(simulation);
    }
  }
}

const borderRadius = BorderRadius.all(Constants.radius);
const shape = const RoundedRectangleBorder(borderRadius: borderRadius);

class _PanelContent extends AnimatedWidget {
  _PanelContent({Key key, @required Listenable listenable})
      : blur = ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        _miniView = _MiniView(controller: listenable),
        _fullView = _FullView(controller: listenable),
        super(key: key, listenable: listenable);

  final ImageFilter blur;
  final Widget _miniView;
  final Widget _fullView;

  bool get _miniViewIgnoring {
    return (listenable as Animation).value > 0.1;
  }

  bool get _fullViewIgnoring {
    return (listenable as Animation).value < 0.9;
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Material(
      shape: shape,
      animationDuration: Duration.zero,
      color: Theme.of(context).backgroundColor,
      clipBehavior: Clip.hardEdge,
      child: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          RepaintBoundary(
            child: IgnorePointer(
              ignoring: _fullViewIgnoring,
              child: _fullView,
            ),
          ),
          RepaintBoundary(
            child: IgnorePointer(
              ignoring: _miniViewIgnoring,
              child: _miniView,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniView extends StatelessWidget {
  _MiniView({Key key, Listenable controller})
      : _animation = Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
            parent: controller, curve: const Interval(0.0, 0.5))),
        super(key: key);

  final Animation<double> _animation;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    final mediaQuery = MediaQuery.of(context);
    return FadeTransition(
      opacity: _animation,
      child: SizedBox(
        height: (mediaQuery.size.height - mediaQuery.padding.top) *
            Panel.startValue,
        child: const _MiniViewContent(),
      ),
    );
  }
}

class _MiniViewContent extends StatelessWidget {
  const _MiniViewContent({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          const RepaintBoundary(child: const AutoPanelArtworkView()),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: MediaPlayerController().current,
              builder: _builder,
            ),
          ),
          RepaintBoundary(
            child: IconButton(
                icon: AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: MediaPlayerController().stateChangedController),
                onPressed: _onTap),
          ),
        ],
      ),
    );
  }

  static _onTap() {
    return MediaPlayerController.playOrPause();
  }

  static Widget _builder(BuildContext context, final SongInfoProvider songInfo,
      final Widget button) {
    return ListTile(
      title: Text(
        songInfo?.title == null ? 'Music X' : songInfo.title,
        maxLines: 2,
        overflow: TextOverflow.fade,
      ),
      subtitle: Text(
        songInfo?.artist == null ? ' ' : songInfo.artist,
        maxLines: 1,
        overflow: TextOverflow.fade,
      ),
    );
  }
}

class _FullView extends StatelessWidget {
  _FullView({Key key, this.controller})
      : _fullViewContent1_opacity = CurvedAnimation(
            parent: controller, curve: const Interval(0.5, 1.0)),
        _fullViewContent2_offset =
            Tween(begin: const Offset(0, 1), end: const Offset(0, 0)).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeOut)),
        _fullViewContent3_offset =
            Tween(begin: const Offset(0, 1), end: const Offset(0, 0)).animate(
                CurvedAnimation(
                    parent: controller,
                    curve: const Interval(0.7, 1.0, curve: Curves.easeOut))),
        super(key: key);

  final Animation controller;

  // ignore: non_constant_identifier_names
  final Animation _fullViewContent1_opacity;

  // ignore: non_constant_identifier_names
  final Animation _fullViewContent2_offset;

  // ignore: non_constant_identifier_names
  final Animation _fullViewContent3_offset;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return LayoutBuilder(
      builder: _builder,
    );
  }

  Widget _builder(BuildContext context, BoxConstraints constraints) {
    return Stack(
      alignment: Alignment.bottomCenter,
      overflow: Overflow.visible,
      children: <Widget>[
        FadeTransition(
            opacity: _fullViewContent1_opacity,
            child: const _FullViewContent1()),
        SlideTransition(
          position: _fullViewContent2_offset,
          child: SizedBox(
            height: constraints.maxHeight * _fullViewContent2_height,
            child: const _FullViewContent2(),
          ),
        ),
        SlideTransition(
          position: _fullViewContent3_offset,
          child: SizedBox(
            height: constraints.maxHeight * _fullViewContent3_height,
            width: constraints.maxWidth,
            child: const _FullViewContent3(),
          ),
        ),
        FadeTransition(
          opacity: _fullViewContent1_opacity,
          child: const Align(
            alignment: Alignment.topCenter,
            child: Icon(Icons.remove),
          ),
        )
      ],
    );
  }
}

const _fullViewContent2_height = 0.32;

const _fullViewContent3_height = _fullViewContent2_height - 0.12;

class _FullViewContent1 extends StatelessWidget {
  const _FullViewContent1({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Material(
      color: Theme.of(context).backgroundColor,
      shape: shape,
      child: LayoutBuilder(
        builder: _builder,
      ),
    );
  }

  static Widget _builder(BuildContext context, BoxConstraints constraints) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: constraints.maxHeight * (1 - _fullViewContent2_height),
        child: Padding(
          padding: EdgeInsets.only(
              left: PageSidePadding.left,
              right: PageSidePadding.right,
              top: MediaQuery.of(context).padding.top),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              RepaintBoundary(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: ArtworkBuilder(
                        animation: MediaPlayerController().progressController,
                      ),
                    ),
                  ),
                ),
              ),
              RepaintBoundary(
                child: ValueListenableBuilder(
                  valueListenable: MediaPlayerController().current,
                  builder: _infoBuilder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _infoBuilder(BuildContext context,
      final SongInfoProvider songInfo, final Widget child) {
    return SizedBox(
      height: 70,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
                style: TextStyle(
                    inherit: true,
                    color: Theme.of(context)
                        .textTheme
                        .bodyText2
                        .color
                        .withOpacity(0.7)),
                children: [
                  TextSpan(
                      text: songInfo?.album == null ? 'Album' : songInfo.album),
                  const TextSpan(text: ' · '),
                  TextSpan(
                      text: songInfo?.artist == null
                          ? 'Artist'
                          : songInfo.artist),
                ]),
          ),
        ),
        subtitle: Text(
          songInfo?.title == null ? 'Music X' : songInfo.title,
          style: Theme.of(context).textTheme.headline5,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class ArtworkBuilder extends AnimatedWidget {
  ArtworkBuilder({Key key, this.animation})
      : customWidths = CustomSliderWidths(
          progressBarWidth: 2.0,
          trackWidth: 2.0,
        ),
        super(key: key, listenable: animation);
  final Animation animation;
  final CustomSliderWidths customWidths;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return SleekCircularSlider(
      min: 0.0,
      max: 1.0,
      initialValue: animation.value,
      appearance: CircularSliderAppearance(
        startAngle: 90,
        animationEnabled: false,
        customColors: CustomSliderColors(
          dotColor: Colors.transparent,
          progressBarColors: const <Color>[
            Colors.black38,
            Colors.black38,
          ],
          trackColor: Colors.black12,
        ),
        customWidths: customWidths,
      ),
      innerWidget: _innerWidget,
    );
  }

  static Widget _innerWidget(double value) {
    return const _InnerWidget();
  }
}

class _InnerWidget extends StatelessWidget {
  const _InnerWidget({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Stack(
      children: <Widget>[
        const Padding(
          padding: const EdgeInsets.all(2.0),
          child: const AutoPanelArtworkView(
            shape: const CircleBorder(),
          ),
        ),
        RepaintBoundary(
          child: Align(
            alignment: Alignment(0.8, 0.8),
            child: Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).backgroundColor,
                  shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: Material(
                  elevation: 6.0,
                  color: Theme.of(context).accentColor,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: _onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(7.0),
                      child: AnimatedIcon(
                        size: 15,
                        icon: AnimatedIcons.play_pause,
                        progress:
                            MediaPlayerController().stateChangedController,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  static void _onTap() {
    MediaPlayerController.playOrPause();
  }
}

const double IconSize = 20;

const ButtonShape = CircleBorder();

const EdgeInsets edgeInsets = EdgeInsets.all(15.0);

class _FullViewContent2 extends StatelessWidget {
  const _FullViewContent2({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Material(
      color: Theme.of(context).primaryColor,
      shape: shape,
      child: const LayoutBuilder(
        builder: _builder,
      ),
    );
  }

  static Widget _builder(BuildContext context, BoxConstraints constraints) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: constraints.maxHeight *
            (1 - (_fullViewContent3_height / _fullViewContent2_height)),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const <Widget>[
            const FlatButton(
              onPressed: _button1,
              color: Colors.white10,
              shape: ButtonShape,
              padding: edgeInsets,
              child: const SequenceModeIcon(),
            ),
            const FlatButton(
              onPressed: _button2,
              color: Colors.white10,
              shape: ButtonShape,
              padding: edgeInsets,
              child: const Icon(
                Icons.skip_previous,
                size: IconSize,
              ),
            ),
            const FlatButton(
              onPressed: _button3,
              color: Colors.white10,
              shape: ButtonShape,
              padding: edgeInsets,
              child: const Icon(
                Icons.skip_next,
                size: IconSize,
              ),
            ),
            const FlatButton(
              onPressed: _button4,
              color: Colors.white10,
              shape: ButtonShape,
              padding: edgeInsets,
              child: const AutoFavoriteButtonIcon(),
            ),
          ],
        ),
      ),
    );
  }

  static _button1() {
    return MediaPlayerController.switchSequenceMode();
  }

  static _button2() {
    return MediaPlayerController().toPrevious();
  }

  static _button3() {
    return MediaPlayerController().toNext();
  }

  static _button4() {
    final songInfo = MediaPlayerController().current.value;
    FavoriteListManager.favoriteOrNot(songInfo);
  }
}

class SequenceModeIcon extends StatelessWidget {
  const SequenceModeIcon({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return RepaintBoundary(
      child: ValueListenableBuilder(
        valueListenable: MediaPlayerController().sequenceMode,
        builder: _builder,
      ),
    );
  }

  static Widget _builder(
      BuildContext context, MediaPlayerSequenceMode value, Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: getIcon(value),
    );
  }

  static Icon getIcon(MediaPlayerSequenceMode value) {
    switch (value) {
      case MediaPlayerSequenceMode.repeat:
        // TODO: Handle this case.
        return const Icon(
          Icons.repeat,
          key: ValueKey(MediaPlayerSequenceMode.repeat),
          size: IconSize,
        );
      case MediaPlayerSequenceMode.shuffle:
        // TODO: Handle this case.
        return const Icon(
          Icons.shuffle,
          key: ValueKey(MediaPlayerSequenceMode.shuffle),
          size: IconSize,
        );
      case MediaPlayerSequenceMode.repeat_one:
        // TODO: Handle this case.
        return const Icon(
          Icons.repeat_one,
          key: ValueKey(MediaPlayerSequenceMode.repeat_one),
          size: IconSize,
        );
    }
    return const Icon(
      Icons.repeat,
      size: IconSize,
    );
  }
}

class _FullViewContent3 extends StatelessWidget {
  const _FullViewContent3({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return RepaintBoundary(
      child: Material(
        color: Theme.of(context).backgroundColor,
        shape: shape,
        clipBehavior: Clip.hardEdge,
        child: PageView(
          physics: Constants.physics,
          scrollDirection: pageViewAxis,
          children: const <Widget>[
            const ShaderMask(
              shaderCallback: _shaderCallback,
              blendMode: BlendMode.dstIn,
              child: const _ListView(),
            ),
            const _SliderView(),
          ],
        ),
      ),
    );
  }

  static Shader _shaderCallback(final rect) {
    const linearGradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent
        ],
        stops: const [
          0.0,
          0.08,
          0.92,
          1.0,
        ]);
    return linearGradient
        .createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
  }
}

const pageViewAxis = Axis.vertical;
const axis = Axis.horizontal;

class _SliderView extends StatelessWidget {
  const _SliderView({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width / 10),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const <Widget>[
          const _ProgressSlider(),
          const _VolumeSlider(),
        ],
      ),
    );
  }
}

class _ProgressSlider extends StatefulWidget {
  const _ProgressSlider({Key key}) : super(key: key);

  @override
  __ProgressSliderState createState() => __ProgressSliderState();
}

class __ProgressSliderState extends State<_ProgressSlider> {
  static final MediaPlayerController _playerController =
      MediaPlayerController();
  static final controller = _playerController.progressController;

  double val = 0;

  bool _enable = true;

  double start;

  _onChangeStart(final newValue) {
    _enable = false;
    _controller.sink.add(_enable);
    setState(() {
      return val = newValue;
    });
  }

  _onChangeEnd(final newValue) {
    MediaPlayerController()
        .seekTo(newValue, skipAnimation: (start - newValue).abs() >= 0.05);
    start = null;
    _enable = true;
    _controller.sink.add(_enable);
  }

  _onChanged(final double newValue) {
    if (start == null) {
      start = newValue;
    } else {
      setState(() {
        return val = newValue;
      });
    }
  }

  _listener() async {
    if (!_enable) {
      await _controller.stream.firstWhere((final val) {
        return val == true;
      });
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    setState(() {
      return val = controller.value;
    });
  }

  StreamController _controller;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _enable = true;
    _controller = StreamController.broadcast();
    controller.addListener(_listener);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _enable = true;
    _controller.sink.add(_enable);
    controller.removeListener(_listener);
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        const Icon(Icons.access_time),
        Expanded(
          child: Slider(
            value: val,
            onChangeStart: _onChangeStart,
            onChangeEnd: _onChangeEnd,
            onChanged: _onChanged,
          ),
        ),
      ],
    );
  }
}

class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider({Key key}) : super(key: key);

  @override
  _VolumeSliderState createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  static final MediaPlayerController _playerController =
      MediaPlayerController();

  double val = 0;

  _onChanged(final double newValue) {
    setState(() {
      _playerController.setVolume(newValue);
      return val = newValue;
    });
  }

  _onChangeStart(final double currentValue) {}

  _onChangeEnd(final double newValue) {}

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    val = _playerController.getVolume();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        const Icon(Icons.volume_up),
        Expanded(
          child: Slider(
            value: val,
            onChanged: _onChanged,
            onChangeEnd: _onChangeEnd,
            onChangeStart: _onChangeStart,
          ),
        ),
      ],
    );
  }
}

class _ListView extends StatefulWidget {
  const _ListView({Key key}) : super(key: key);

  @override
  _ListViewState createState() => _ListViewState();
}

class _ListViewState extends State<_ListView>
    with AutomaticKeepAliveClientMixin<_ListView> {
  ScrollController scrollController;

  _onChanged() async {
    setState(() {
      return children = _children;
    });
    await SchedulerBinding.instance.endOfFrame;
    _onCurrentChanged();
  }

  _onCurrentChanged() async {
    if (!scrollController.hasClients || !mounted) return;
    _highlight();

    final index = MediaPlayerController().currentIndex;
    final key = GlobalObjectKey(children[index].key);
    final context = key.currentContext;

    await SchedulerBinding.instance.endOfFrame;
    final RenderObject contextObject = context?.findRenderObject();
    if (contextObject == null) return;
    final RenderAbstractViewport viewport =
        RenderAbstractViewport.of(contextObject);
    if (viewport == null) return;

    final double offset = min(scrollController.position.maxScrollExtent,
        viewport.getOffsetToReveal(contextObject, 0.5).offset);

    scrollController.position.animateTo(offset,
        duration: const Duration(milliseconds: 800),
        curve: Curves.fastOutSlowIn);
  }

  _highlight() async {
    if (!mounted) return;
    final lastIndex = _lastIndex;
    if (lastIndex != null)
      setState(() {
        children[lastIndex] = children.builder(children.parent[lastIndex]);
      });

    await AnimationStream().idle();

    if (!mounted) return;
    final currentIndex = MediaPlayerController().currentIndex;
    setState(() {
      children[currentIndex] =
          children.builder(children.parent[currentIndex], highlight: true);
    });
  }

  static int get _lastIndex {
    final log = RecentLog.log;
    if (log.length < 2) return null;
    final lastLog = log[log.length - 2];
    return MediaPlayerController().indexOf(lastLog.songInfo);
  }

  PlayListChildren children;

  static get _children {
    final value = MediaPlayerController().currentPlayList.value;
    if (value == null)
      return PlayListChildren(parent: const <SongInfoProvider>[]);
    return PlayListChildren(parent: value);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    scrollController = ScrollController();
    MediaPlayerController().currentPlayList.addListener(_onChanged);
    MediaPlayerController().current.addListener(_onCurrentChanged);
    children = _children;
  }

  @override
  void dispose() {
    // TODO: implement dispose
    MediaPlayerController().currentPlayList.removeListener(_onChanged);
    MediaPlayerController().current.removeListener(_onCurrentChanged);
    scrollController.dispose();
    children = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    super.build(context);
    if (children.isEmpty) return Container();
    final protect = MediaQuery.of(context).size.width / 10;
    return SingleChildScrollView(
      physics: Constants.physics,
      scrollDirection: axis,
      controller: scrollController,
      child: RawReorderableListView(
        header: const SizedBox(width: 50),
        end: const SizedBox(width: 50),
        onReorder: _onReorder,
        scrollController: scrollController,
        scrollDirection: axis,
        children: children,
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 2),
        protectAreaTopLeft: protect,
        protectAreaBottomRight: protect,
      ),
    );
  }

  static Function(int, int) get _onReorder {
    final value = MediaPlayerController().currentPlayList.value;
    return PlayListRegister(value).onReorder;
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}

class PlayListChildren extends WidgetMapList<SongInfoProvider> {
  PlayListChildren({@required List<SongInfoProvider> parent})
      : super(parent: parent);

  static const highlightDecoration = BoxDecoration(color: Colors.transparent);
  static const notHighlightDecoration = BoxDecoration(color: Colors.black38);

  final Map<SongInfoProvider, Key> keys = Map();

  @override
  Widget builder(SongInfoProvider p, {bool highlight = false}) {
    // TODO: implement builder
    keys[p] ??= ValueKey(p);
    return _ListItem(
      key: keys[p],
      highlight: highlight,
      songInfo: p,
    );
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({Key key, this.highlight, this.songInfo}) : super(key: key);
  final bool highlight;
  final SongInfoProvider songInfo;

  static const highlightDecoration = BoxDecoration(color: Colors.transparent);
  static const notHighlightDecoration = BoxDecoration(
    gradient: const LinearGradient(
      colors: const [
        Colors.black38,
        Colors.black54,
      ],
      stops: const [0.0, 0.9],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
  static const _duration = Duration(milliseconds: 800);
  static const shape = RoundedRectangleBorder();

  static const _key0 = ValueKey(false);
  static const _key1 = ValueKey(true);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return AspectRatio(
      aspectRatio: 1.0,
      child: AnimatedSwitcher(
        duration: _duration,
        child: highlight
            ? Stack(
                key: _key0,
                fit: StackFit.loose,
                children: <Widget>[
                  Container(
                    foregroundDecoration: highlightDecoration,
                    child: ArtworkListView(
                      shape: shape,
                      artwork: songInfo.artwork,
                    ),
                  ),
                ],
              )
            : Stack(
                key: _key1,
                children: <Widget>[
                  Container(
                    foregroundDecoration: notHighlightDecoration,
                    child: ArtworkListView(
                      shape: shape,
                      artwork: songInfo.artwork,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onTap,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            songInfo.title,
                            style: TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  _onTap() {
    MediaPlayerController.setTrack(songInfo: songInfo);
    if (MediaPlayerController().state.value != MediaPlayerStatus.started) {
      MediaPlayerController().start();
    }
  }
}

const double PanelHeight = 100;

const SliverBottomPadding = const SliverToBoxAdapter(
  child: const SizedBox(height: PanelHeight),
);
