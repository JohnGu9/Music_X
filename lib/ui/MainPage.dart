import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:musicx/component.dart';
import 'package:musicx/ui/ListBuilder.dart';
import 'package:musicx/unit.dart';
import 'package:musicx/unit/Streams.dart';

class MainPage extends StatelessWidget {
  const MainPage({Key key, this.animation, this.secondaryAnimation})
      : super(key: key);
  final Animation animation;
  final Animation secondaryAnimation;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return _SecondaryTransitionBuilder(
      animation: secondaryAnimation,
      child: _PrimaryTransitionBuilder(
        animation: animation,
        colors: [
          Theme.of(context).primaryColor.withOpacity(0.4),
          Theme.of(context).primaryColor.withOpacity(0.7),
          Theme.of(context).primaryColor,
        ],
      ),
    );
  }
}

class _SecondaryTransitionBuilder extends AnimatedWidget {
  const _SecondaryTransitionBuilder({Key key, this.child, this.animation})
      : super(key: key, listenable: animation);
  final Widget child;
  final Animation<double> animation;
  static final _tween = Tween(begin: 1.0, end: 0.8);

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    final double scaleValue = _tween.evaluate(animation);
    final Matrix4 transform = Matrix4.identity()
      ..scale(scaleValue, scaleValue, 1.0);
    return Transform(
      transform: transform,
      alignment: Alignment.center,
      child: child,
    );
  }
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
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.all(30.0),
              title: FadeTransition(
                  opacity: delayAnimation, child: Text('Music X')),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _onRefresh,
          ),
          SliverToBoxAdapter(
            child: FractionalTranslation(
              translation: Tween(begin: Offset(0, 1), end: Offset.zero)
                  .evaluate(delayAnimation),
              child: MainList(controller: controller),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 2));
    return;
  }
}

class MainList extends StatefulWidget {
  MainList({Key key, this.controller})
      : listenable = LibraryListViewChildrenBuilder(),
        super(key: key);
  final ScrollController controller;
  final ValueListenable listenable;

  @override
  _MainListState createState() => _MainListState();
}

class _MainListState extends State<MainList>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Offset> _position;
  var _value;

  _listener() async {
    await AnimationStream().idle();
    if (mounted) {
      setState(() {
        _value = widget.listenable.value;
      });
      if (_value == null || _value.isEmpty) {
        _controller.animateBack(0.0, curve: Curves.fastOutSlowIn);
      } else {
        _controller.animateTo(1.0, curve: Curves.fastOutSlowIn);
      }
    }
  }

  _controllerListener(AnimationStatus status) {
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
    widget.listenable.addListener(_listener);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    widget.listenable.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return _builder(context, _value);
  }

  void _onReorder(int oldIndex, int newIndex) {
    (widget.listenable as LibraryListViewChildrenBuilder)
        .reorder(oldIndex, newIndex);
  }

  Widget _builder(BuildContext context, List<Widget> children) {
    if (children == null || children.isEmpty)
      return const Center(
          child: Padding(
        padding: const EdgeInsets.all(50.0),
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.white)),
      ));

    return FadeTransition(
      opacity: _controller,
      child: SlideTransition(
        position: _position,
        child: Material(
          borderRadius: const BorderRadius.all(Constants.radius),
          child: RawReorderableListView(
              header: const _ListHeader(),
              end: SizedBox(
                height: Constants.radius.y,
              ),
              onDragStart: _onDragStart,
              onDragEnd: _onDragEnd,
              children: children,
              onReorder: _onReorder,
              scrollController: widget.controller),
        ),
      ),
    );
  }

  _onDragStart() {
    AnimationStream.instance.addAnimation(hashCode);
  }

  _onDragEnd() {
    AnimationStream.instance.removeAnimation(hashCode);
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
          const VerticalDivider(width: 20),
          BorderTextButton(
            color: Theme.of(context).primaryColor,
            paddingColor: Theme.of(context).primaryColor,
            text: 'PLAY',
            textColor: Colors.white,
            fontSize: 16,
            icon: Icons.play_arrow,
          ),
          const VerticalDivider(width: 10),
          BorderTextButton(
            color: Theme.of(context).primaryColor,
            paddingColor: Theme.of(context).primaryColor,
            text: 'SHUFFLE',
            textColor: Colors.white,
            fontSize: 16,
            icon: Icons.shuffle,
          ),
        ],
      ),
    );
  }
}
