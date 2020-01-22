// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Feature with onDragStart and onDragEnd callback
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:music/component/SingleTouchRecognizer.dart';

/// The callback used by [CustomReorderableListView] to move an item to a new
/// position in a list.
///
/// Implementations should remove the corresponding list item at [oldIndex]
/// and reinsert it at [newIndex].
///
/// If [oldIndex] is before [newIndex], removing the item at [oldIndex] from the
/// list will reduce the list's length by one. Implementations used by
/// [CustomReorderableListView] will need to account for this when inserting before
/// [newIndex].
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=3fB1mxOsqJE}
///
/// {@tool sample}
///
/// ```dart
/// final List<MyDataObject> backingList = <MyDataObject>[/* ... */];
///
/// void handleReorder(int oldIndex, int newIndex) {
///   if (oldIndex < newIndex) {
///     // removing the item at oldIndex will shorten the list by 1.
///     newIndex -= 1;
///   }
///   final MyDataObject element = backingList.removeAt(oldIndex);
///   backingList.insert(newIndex, element);
/// }
/// ```
/// {@end-tool}
typedef ReorderCallback = void Function(int oldIndex, int newIndex);

/// A list whose items the user can interactively reorder by dragging.
///
/// This class is appropriate for views with a small number of
/// children because constructing the [List] requires doing work for every
/// child that could possibly be displayed in the list view instead of just
/// those children that are actually visible.
///
/// All [children] must have a key.
class CustomReorderableListView extends StatefulWidget {
  /// Creates a reorderable list.
  CustomReorderableListView({
    Key key,
    this.header,
    this.end,
    @required this.children,
    @required this.onReorder,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.reverse = false,
    this.onDragStart,
    this.onDragEnd,
  })  : assert(scrollDirection != null),
        assert(onReorder != null),
        assert(children != null),
        assert(
          children.every((Widget w) => w.key != null),
          'All children of this widget must have a key.',
        ),
        super(key: key);

  // new feature: onDragStart, onDragEnd
  final Function() onDragStart;
  final Function() onDragEnd;

  /// A non-reorderable header widget to show before the list.
  ///
  /// If null, no header will appear before the list.
  final Widget header;
  final Widget end;

  /// The widgets to display.
  final List<Widget> children;

  /// The [Axis] along which the list scrolls.
  ///
  /// List [children] can only drag along this [Axis].
  final Axis scrollDirection;

  /// The amount of space by which to inset the [children].
  final EdgeInsets padding;

  /// Whether the scroll view scrolls in the reading direction.
  ///
  /// For example, if the reading direction is left-to-right and
  /// [scrollDirection] is [Axis.horizontal], then the scroll view scrolls from
  /// left to right when [reverse] is false and from right to left when
  /// [reverse] is true.
  ///
  /// Similarly, if [scrollDirection] is [Axis.vertical], then the scroll view
  /// scrolls from top to bottom when [reverse] is false and from bottom to top
  /// when [reverse] is true.
  ///
  /// Defaults to false.
  final bool reverse;

  /// Called when a list child is dropped into a new position to shuffle the
  /// underlying list.
  ///
  /// This [CustomReorderableListView] calls [onReorder] after a list child is dropped
  /// into a new position.
  final ReorderCallback onReorder;

  @override
  _CustomReorderableListViewState createState() =>
      _CustomReorderableListViewState();
}

// This top-level state manages an Overlay that contains the list and
// also any Draggables it creates.
//
// _ReorderableListContent manages the list itself and reorder operations.
//
// The Overlay doesn't properly keep state by building new overlay entries,
// and so we cache a single OverlayEntry for use as the list layer.
// That overlay entry then builds a _ReorderableListContent which may
// insert Draggables into the Overlay above itself.
class _CustomReorderableListViewState extends State<CustomReorderableListView> {
  ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      child: _RawReorderableListContent(
          header: widget.header,
          end: widget.end,
          children: widget.children,
          scrollDirection: widget.scrollDirection,
          onReorder: widget.onReorder,
          reverse: widget.reverse,
          onDragStart: widget.onDragStart,
          onDragEnd: widget.onDragEnd,
          scrollController: _controller,
          itemElevation: _elevation,
          shape: _shape,
          padding: _padding,
          protectAreaTopLeft: _protectAreaTopLeft,
          protectAreaBottomRight: _protectAreaBottomRight),
    );
  }
}

/// Additional Extend
/// add [SliverReorderableListView] and [RawReorderableListView]
const _elevation = 4.0;
const _shape =
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)));

const _padding = EdgeInsets.all(2.0);

class SliverReorderableListView extends StatelessWidget {
  SliverReorderableListView.builder({
    Key key,
    this.header,
    this.end,
    @required this.onReorder,
    @required this.scrollController,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.onDragStart,
    this.onDragEnd,
    this.shape,
    @required this.constraints,
    @required this.itemBuilder,
    @required this.count,
  })  : children = null,
        _lazyBuilder = true;

  final bool _lazyBuilder;
  final Widget Function(BuildContext, int) itemBuilder;
  final int count;
  final BoxConstraints constraints;

  SliverReorderableListView({
    Key key,
    this.header,
    this.end,
    @required this.children,
    @required this.onReorder,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.onDragStart,
    this.onDragEnd,
    this.shape,
    @required this.scrollController,
  })  : _lazyBuilder = false,
        itemBuilder = null,
        count = null,
        constraints = null,
        assert(scrollDirection != null),
        assert(onReorder != null),
        assert(children != null),
        assert(
          children.every((Widget w) => w.key != null),
          'All children of this widget must have a Key.',
        ),
        super(key: key);

  // new feature: onDragStart, onDragEnd
  final Function() onDragStart;
  final Function() onDragEnd;

  /// A non-reorderable header widget to show before the list.
  ///
  /// If null, no header will appear before the list.
  final Widget header;
  final Widget end;

  /// The widgets to display.
  final List<Widget> children;

  /// The [Axis] along which the list scrolls.
  ///
  /// List [children] can only drag along this [Axis].
  final Axis scrollDirection;

  /// Whether the scroll view scrolls in the reading direction.
  ///
  /// For example, if the reading direction is left-to-right and
  /// [scrollDirection] is [Axis.horizontal], then the scroll view scrolls from
  /// left to right when [reverse] is false and from right to left when
  /// [reverse] is true.
  ///
  /// Similarly, if [scrollDirection] is [Axis.vertical], then the scroll view
  /// scrolls from top to bottom when [reverse] is false and from bottom to top
  /// when [reverse] is true.
  ///
  /// Defaults to false.
  final bool reverse;

  /// Called when a list child is dropped into a new position to shuffle the
  /// underlying list.
  ///
  /// This [SliverReorderableListView] calls [onReorder] after a list child is dropped
  /// into a new position.
  final ReorderCallback onReorder;

  final ShapeBorder shape;

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    if (_lazyBuilder != null && _lazyBuilder)
      return _RawReorderableListLazyContent(
          header: header,
          end: end,
          itemBuilder: itemBuilder,
          count: count,
          scrollDirection: scrollDirection,
          onReorder: onReorder,
          reverse: reverse,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
          scrollController: scrollController,
          itemElevation: _elevation,
          shape: _shape,
          padding: _padding,
          constraints: constraints,
          protectAreaTopLeft: _protectAreaTopLeft,
          protectAreaBottomRight: _protectAreaBottomRight);

    return SliverToBoxAdapter(
      child: Material(
        shape: shape,
        child: _RawReorderableListContent(
          header: header,
          end: end,
          children: children,
          scrollDirection: scrollDirection,
          onReorder: onReorder,
          reverse: reverse,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
          scrollController: scrollController,
          itemElevation: _elevation,
          shape: _shape,
          padding: _padding,
          protectAreaTopLeft: _protectAreaTopLeft,
          protectAreaBottomRight: _protectAreaBottomRight,
        ),
      ),
    );
  }
}

class RawReorderableListView extends StatelessWidget {
  RawReorderableListView({
    Key key,
    this.header,
    this.end,
    @required this.children,
    @required this.onReorder,
    @required this.scrollController,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.onDragStart,
    this.onDragEnd,
    this.protectAreaTopLeft,
    this.protectAreaBottomRight,
    final EdgeInsets padding,
    final double itemElevation,
    final ShapeBorder shape,
  })  : assert(scrollDirection != null),
        assert(onReorder != null),
        assert(children != null),
        assert(
          children.every((Widget w) => w.key != null),
          'All children of this widget must have a Key.',
        ),
        padding = padding ?? _padding,
        itemElevation = itemElevation ?? _elevation,
        shape = shape ?? _shape,
        super(key: key);

  // new feature: onDragStart, onDragEnd
  final Function() onDragStart;
  final Function() onDragEnd;

  /// A non-reorderable header widget to show before the list.
  ///
  /// If null, no header will appear before the list.
  final Widget header;
  final Widget end;

  /// The widgets to display.
  final List<Widget> children;

  /// The [Axis] along which the list scrolls.
  ///
  /// List [children] can only drag along this [Axis].
  final Axis scrollDirection;

  /// Whether the scroll view scrolls in the reading direction.
  ///
  /// For example, if the reading direction is left-to-right and
  /// [scrollDirection] is [Axis.horizontal], then the scroll view scrolls from
  /// left to right when [reverse] is false and from right to left when
  /// [reverse] is true.
  ///
  /// Similarly, if [scrollDirection] is [Axis.vertical], then the scroll view
  /// scrolls from top to bottom when [reverse] is false and from bottom to top
  /// when [reverse] is true.
  ///
  /// Defaults to false.
  final bool reverse;

  /// Called when a list child is dropped into a new position to shuffle the
  /// underlying list.
  ///
  /// This [SliverReorderableListView] calls [onReorder] after a list child is dropped
  /// into a new position.
  final ReorderCallback onReorder;

  final ScrollController scrollController;
  final double protectAreaTopLeft;
  final double protectAreaBottomRight;
  final EdgeInsets padding;
  final double itemElevation;
  final ShapeBorder shape;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return _RawReorderableListContent(
      header: header,
      end: end,
      children: children,
      scrollDirection: scrollDirection,
      onReorder: onReorder,
      reverse: reverse,
      onDragStart: onDragStart,
      onDragEnd: onDragEnd,
      scrollController: scrollController,
      itemElevation: itemElevation,
      shape: shape,
      padding: padding,
      protectAreaTopLeft: protectAreaTopLeft ?? _protectAreaTopLeft,
      protectAreaBottomRight: protectAreaBottomRight ?? _protectAreaBottomRight,
    );
  }
}

const double _protectAreaTopLeft = 80;
const double _protectAreaBottomRight = 80;

// This widget is responsible for the inside of the Overlay in the
// ReorderableListView.
class _RawReorderableListContent extends StatefulWidget {
  const _RawReorderableListContent({
    @required this.header,
    @required this.end,
    @required this.children,
    @required this.scrollDirection,
    @required this.onReorder,
    @required this.reverse,
    @required this.onDragStart,
    @required this.onDragEnd,
    @required this.scrollController,
    @required this.itemElevation,
    @required this.shape,
    @required this.padding,
    @required this.protectAreaTopLeft,
    @required this.protectAreaBottomRight,
  });

  final Widget header;
  final Widget end;
  final List<Widget> children;
  final Axis scrollDirection;
  final ReorderCallback onReorder;
  final bool reverse;
  final Function() onDragStart;
  final Function() onDragEnd;
  final ScrollController scrollController;
  final double itemElevation;
  final ShapeBorder shape;
  final EdgeInsets padding;
  final double protectAreaTopLeft;
  final double protectAreaBottomRight;

  @override
  _RawReorderableListContentState createState() =>
      _RawReorderableListContentState();
}

class _RawReorderableListContentState extends State<_RawReorderableListContent>
    with TickerProviderStateMixin<_RawReorderableListContent> {
  static const double _extraElevation = 4.0;

  // The extent along the [widget.scrollDirection] axis to allow a child to
  // drop into when the user reorders list children.
  //
  // This value is used when the extents haven't yet been calculated from
  // the currently dragging widget, such as when it first builds.
  static const double _defaultDropAreaExtent = 150.0;

  // The additional margin to place around a computed drop area.
  static const double _dropAreaMargin = 0.0;

  // How long an animation to reorder an element in the list takes.
  static const Duration _reorderAnimationDuration =
      const Duration(milliseconds: 200);

  // How long an animation to scroll to an off-screen element in the
  // list takes.
  static const Duration _scrollAnimationDuration =
      const Duration(milliseconds: 200);

  // This controls the entrance of the dragging widget into a new place.
  AnimationController _entranceController;

  // This controls the 'ghost' of the dragging widget, which is left behind
  // where the widget used to be.
  AnimationController _ghostController;

  AnimationController _dragCompleteController;

  Map<int, bool> _animations;

  // The member of widget.children currently being dragged.
  //
  // Null if no drag is underway.
  Key _dragging;

  // The last computed size of the feedback widget being dragged.
  Size _draggingFeedbackSize;

  // The location that the dragging widget occupied before it started to drag.
  int _dragStartIndex = 0;

  // The index that the dragging widget most recently left.
  // This is used to show an animation of the widget's position.
  int _ghostIndex = 0;

  // The index that the dragging widget currently occupies.
  int _currentIndex = 0;

  // The widget to move the dragging widget too after the current index.
  int _nextIndex = 0;

  // Whether or not we are currently scrolling this view to show a widget.
  bool _scrolling = false;

  StreamController<AnimationStatus> _streamController;

  double get _dropAreaExtent {
    if (_draggingFeedbackSize == null) {
      return _defaultDropAreaExtent;
    }
    double dropAreaWithoutMargin;
    switch (widget.scrollDirection) {
      case Axis.horizontal:
        dropAreaWithoutMargin = _draggingFeedbackSize.width;
        break;
      case Axis.vertical:
      default:
        dropAreaWithoutMargin = _draggingFeedbackSize.height;
        break;
    }
    switch (widget.scrollDirection) {
      case Axis.horizontal:
        return dropAreaWithoutMargin +
            _dropAreaMargin +
            widget.padding.left +
            widget.padding.right;
      case Axis.vertical:
        return dropAreaWithoutMargin +
            _dropAreaMargin +
            widget.padding.top +
            widget.padding.bottom;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    assert(widget.scrollController != null);
    _streamController = StreamController.broadcast();
    _entranceController =
        AnimationController(vsync: this, duration: _reorderAnimationDuration);
    _ghostController =
        AnimationController(vsync: this, duration: _reorderAnimationDuration);
    _animations = {
      _ghostController.hashCode: false,
      _entranceController.hashCode: false,
    };

    _ghostController.addStatusListener((AnimationStatus status) {
      _animations[_ghostController.hashCode] =
          status == AnimationStatus.forward ||
              status == AnimationStatus.reverse;
      _streamController.sink.add(status);
    });
    _entranceController.addStatusListener((AnimationStatus status) {
      _animations[_entranceController.hashCode] =
          status == AnimationStatus.forward ||
              status == AnimationStatus.reverse;
      _streamController.sink.add(status);
      if (status == AnimationStatus.completed)
        setState(() {
          _requestAnimationToNextIndex();
        });
    });

    _dragCompleteController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _streamController.close();
    _entranceController.dispose();
    _ghostController.dispose();
    _dragCompleteController.dispose();
    super.dispose();
  }

  // Animates the droppable space from _currentIndex to _nextIndex.
  Future<void> _requestAnimationToNextIndex() async {
    if (_entranceController.isCompleted) {
      _ghostIndex = _currentIndex;
      if (_nextIndex == _currentIndex) {
        return;
      }
      _currentIndex = _nextIndex;
      await Future.wait([
        _ghostController.reverse(from: 1.0),
        _entranceController.forward(from: 0.0),
      ]);
    }
  }

  Future<void> _animation() async {
    if (!_entranceController.isAnimating) return;
    await _streamController.stream.firstWhere((status) =>
        !_animations[_ghostController.hashCode] &&
        !_animations[_entranceController.hashCode]);
    // await the frame finished that the widgets' positions actually settle down.
    await SchedulerBinding.instance.endOfFrame;
  }

  // Scrolls to a target context if that context is not on the screen.
  void _scrollTo(BuildContext context) {
    if (_scrolling) return;
    final RenderObject contextObject = context.findRenderObject();
    final RenderAbstractViewport viewport =
        RenderAbstractViewport.of(contextObject);
    assert(viewport != null);
    // If and only if the current scroll offset falls in-between the offsets
    // necessary to reveal the selected context at the top or bottom of the
    // screen, then it is already on-screen.

    final double scrollOffset = widget.scrollController.offset;
    final double topOffset = max(
        widget.scrollController.position.minScrollExtent,
        viewport.getOffsetToReveal(contextObject, 0.0).offset -
            widget.protectAreaTopLeft);
    final double bottomOffset = min(
        widget.scrollController.position.maxScrollExtent,
        viewport.getOffsetToReveal(contextObject, 1.0).offset +
            widget.protectAreaBottomRight);
    final bool onScreen =
        scrollOffset <= topOffset && scrollOffset >= bottomOffset;

    // If the context is off screen, then we request a scroll to make it visible.
    if (!onScreen) {
      _scrolling = true;
      widget.scrollController.position
          .animateTo(
        scrollOffset < bottomOffset ? bottomOffset : topOffset,
        duration: _scrollAnimationDuration,
        curve: Curves.easeInOut,
      )
          .then((void value) {
        setState(() {
          _scrolling = false;
        });
      });
    }
  }

  // Wraps children in Row or Column, so that the children flow in
  // the widget's scrollDirection.
  Widget _buildContainerForScrollDirection({List<Widget> children, Key key}) {
    switch (widget.scrollDirection) {
      case Axis.horizontal:
        return Row(
            key: key, mainAxisSize: MainAxisSize.min, children: children);
      case Axis.vertical:
      default:
        return Column(
            key: key, mainAxisSize: MainAxisSize.min, children: children);
    }
  }

  // Places the value from startIndex one space before the element at endIndex.
  void reorder(int startIndex, int endIndex) {
    setState(() {
      if (startIndex != endIndex) widget.onReorder(startIndex, endIndex);
      // Animates leftover space in the drop area closed.
      // TODO(djshuckerow): bring the animation in line with the Material
      // specifications.
      _ghostController.reset();
      _entranceController.reset();
      _dragging = null;
    });
  }

  // For get entrance location.
  GlobalKey _entranceKey;

  _feedback() {
    return Feedback.forLongPress(context);
  }

  OverlayEntry _currentOverlayEntry;

  _releaseDraggableAnimation(
      final BoxConstraints constraints
      /*For Limit the widget size*/,
      final Velocity velocity) async {
    final GlobalObjectKey draggingKey = GlobalObjectKey(_dragging);
    final RenderBox startRenderBox =
        draggingKey.currentContext?.findRenderObject();
    if (startRenderBox == null) return;
    final start = startRenderBox.localToGlobal(Offset.zero) -
        Offset(widget.padding.left, widget.padding.top);

    Animation<Offset> _offsetAnimation = AlwaysStoppedAnimation<Offset>(start);
    Animation<double> _elevationAnimation =
        AlwaysStoppedAnimation(widget.itemElevation + _extraElevation);
    // If something was release from dragging during other release dragging animation
    // Remove the former one and insert the new one
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = OverlayEntry(builder: (BuildContext context) {
      return Stack(
        children: <Widget>[
          // Protect Layout changed by user
          Positioned.fill(child: AbsorbPointer(absorbing: true)),
          AnimatedBuilder(
            animation: _dragCompleteController,
            builder: (BuildContext context, Widget child) {
              final offset = _offsetAnimation.value;
              return Container(
                alignment: Alignment.topLeft,
                constraints: constraints,
                transform: Matrix4.translationValues(offset.dx, offset.dy, 0.0),
                child: Padding(
                  padding: widget.padding,
                  child: Material(
                      elevation: _elevationAnimation.value,
                      shape: widget.shape,
                      clipBehavior: Clip.hardEdge,
                      animationDuration: Duration.zero,
                      child: child),
                ),
              );
            },
            child: draggingKey.currentWidget,
          ),
        ],
      );
    });
    Overlay.of(context).insert(_currentOverlayEntry);

    // wait for entrance animation completed
    _requestAnimationToNextIndex();
    await _animation();

    // get the end point Offset
    final RenderBox endRenderBox =
        _entranceKey.currentContext.findRenderObject();
    if (endRenderBox == null) {
      _currentOverlayEntry.remove();
      _currentOverlayEntry = null;
    }
    final end = endRenderBox.localToGlobal(Offset.zero);

    _offsetAnimation =
        Tween(begin: start, end: end).animate(_dragCompleteController);
    _elevationAnimation =
        Tween(begin: _elevationAnimation.value, end: widget.itemElevation)
            .animate(_dragCompleteController);

    final screen = MediaQuery.of(context).size;
    final dis = end - start;
    final stiffness = 10 * (dis.distance / screen.height);
    final spring = SpringDescription(
      mass: 30,
      stiffness: stiffness <= 0.1 ? 0.1 : stiffness,
      damping: 1,
    );
    if (velocity != null)
      switch (widget.scrollDirection) {
        case Axis.horizontal:
          // TODO: Handle this case.
          final double vel =
              dis.dx.isNegative == velocity.pixelsPerSecond.dx.isNegative
                  ? -velocity.pixelsPerSecond.dx / screen.width
                  : velocity.pixelsPerSecond.dx / screen.width;
          final simulation = SpringSimulation(spring, 0, 1, vel);
          await _dragCompleteController.animateWith(simulation);
          break;
        case Axis.vertical:
          // TODO: Handle this case.
          final double vel =
              dis.dy.isNegative == velocity.pixelsPerSecond.dy.isNegative
                  ? -velocity.pixelsPerSecond.dy / screen.height
                  : velocity.pixelsPerSecond.dy / screen.height;
          final simulation = SpringSimulation(spring, 0, 1, vel);
          await _dragCompleteController.animateWith(simulation);
          break;
      }
    else {
      final simulation = SpringSimulation(spring, 0, 1, 0);
      await _dragCompleteController.animateWith(simulation);
    }

    _currentOverlayEntry.remove();
    _currentOverlayEntry = null;
  }

  // Wraps one of the widget's children in a DragTarget and Draggable.
  // Handles up the logic for dragging and reordering items in the list.
  Widget _wrap(BuildContext context, Widget toWrap, int index,
      BoxConstraints constraints) {
    assert(toWrap.key != null);
    final GlobalObjectKey keyIndexGlobalKey = GlobalObjectKey(toWrap.key);
    // We pass the toWrapWithGlobalKey into the Draggable so that when a list
    // item gets dragged, the accessibility framework can preserve the selected
    // state of the dragging item.
    // Starts dragging toWrap.
    void onDragStarted() {
      Future(_feedback);
      setState(() {
        _dragging = toWrap.key;
        _dragStartIndex = index;
        _ghostIndex = index;
        _currentIndex = index;
        _entranceController.value = 1.0;
        _draggingFeedbackSize = keyIndexGlobalKey.currentContext.size;
        if (widget?.onDragStart != null) widget?.onDragStart();
      });
    }

    // Drops toWrap into the last position it was hovering over.
    void onDragEnded({final Velocity velocity}) async {
      await _releaseDraggableAnimation(constraints, velocity);
      // Animation finished
      reorder(_dragStartIndex, _currentIndex);
      if (widget.onDragEnd != null) widget.onDragEnd();
    }

    Widget wrapWithSemantics() {
      // First, determine which semantics actions apply.
      final Map<CustomSemanticsAction, VoidCallback> semanticsActions =
          <CustomSemanticsAction, VoidCallback>{};

      // Create the appropriate semantics actions.
      void moveToStart() => reorder(index, 0);
      void moveToEnd() => reorder(index, widget.children.length);
      void moveBefore() => reorder(index, index - 1);
      // To move after, we go to index+2 because we are moving it to the space
      // before index+2, which is after the space at index+1.
      void moveAfter() => reorder(index, index + 2);

      final MaterialLocalizations localizations =
          MaterialLocalizations.of(context);

      // If the item can move to before its current position in the list.
      if (index > 0) {
        semanticsActions[CustomSemanticsAction(
            label: localizations.reorderItemToStart)] = moveToStart;
        String reorderItemBefore = localizations.reorderItemUp;
        if (widget.scrollDirection == Axis.horizontal) {
          reorderItemBefore = Directionality.of(context) == TextDirection.ltr
              ? localizations.reorderItemLeft
              : localizations.reorderItemRight;
        }
        semanticsActions[CustomSemanticsAction(label: reorderItemBefore)] =
            moveBefore;
      }

      // If the item can move to after its current position in the list.
      if (index < widget.children.length - 1) {
        String reorderItemAfter = localizations.reorderItemDown;
        if (widget.scrollDirection == Axis.horizontal) {
          reorderItemAfter = Directionality.of(context) == TextDirection.ltr
              ? localizations.reorderItemRight
              : localizations.reorderItemLeft;
        }
        semanticsActions[CustomSemanticsAction(label: reorderItemAfter)] =
            moveAfter;
        semanticsActions[
                CustomSemanticsAction(label: localizations.reorderItemToEnd)] =
            moveToEnd;
      }

      // We pass toWrap with a GlobalKey into the Draggable so that when a list
      // item gets dragged, the accessibility framework can preserve the selected
      // state of the dragging item.
      //
      // We also apply the relevant custom accessibility actions for moving the item
      // up, down, to the start, and to the end of the list.
      return KeyedSubtree(
        key: keyIndexGlobalKey,
        child: MergeSemantics(
          child: Semantics(
            customSemanticsActions: semanticsActions,
            child: toWrap,
          ),
        ),
      );
    }

    Widget buildDragTarget(BuildContext context, List<Key> acceptedCandidates,
        List rejectedCandidates) {
      final Widget toWrapWithSemantics = wrapWithSemantics();

      // We build the draggable inside of a layout builder so that we can
      // constrain the size of the feedback dragging widget.
      Widget child = LongPressDraggable<Key>(
        maxSimultaneousDrags: 1,
        axis: widget.scrollDirection,
        data: toWrap.key,
        ignoringFeedbackSemantics: false,
        feedback: Container(
          alignment: Alignment.topLeft,
          // These constraints will limit the cross axis of the drawn widget.
          constraints: constraints,
          child: Padding(
              padding: widget.padding,
              child: Material(
                  elevation: widget.itemElevation + _extraElevation,
                  shape: widget.shape,
                  clipBehavior: Clip.hardEdge,
                  child: toWrapWithSemantics)),
        ),
        childWhenDragging: const SizedBox(),
        dragAnchor: DragAnchor.child,
        onDragStarted: onDragStarted,
        onDragCompleted: onDragEnded,
        onDraggableCanceled: (Velocity velocity, Offset offset) {
          onDragEnded(velocity: velocity);
        },
        child: _dragging == toWrap.key
            ? const SizedBox()
            : Padding(
                padding: widget.padding,
                child: Material(
                    elevation: widget.itemElevation,
                    shape: widget.shape,
                    clipBehavior: Clip.hardEdge,
                    child: toWrapWithSemantics)),
      );

      // The target for dropping at the end of the list doesn't need to be
      // draggable.
      if (index >= widget.children.length) {
        child = toWrap;
      }

      // Determine the size of the drop area to show under the dragging widget.
      Widget spacing;
      switch (widget.scrollDirection) {
        case Axis.horizontal:
          spacing = SizedBox(width: _dropAreaExtent);
          break;
        case Axis.vertical:
        default:
          spacing = SizedBox(height: _dropAreaExtent);
          break;
      }

      // We open up a space under where the dragging widget currently is to
      // show it can be dropped.
      if (_currentIndex == index) {
        _entranceKey = GlobalKey();
        return _buildContainerForScrollDirection(
            key: _entranceKey,
            children: <Widget>[
              SizeTransition(
                sizeFactor: _entranceController,
                axis: widget.scrollDirection,
                child: spacing,
              ),
              child,
            ]);
      }
      // We close up the space under where the dragging widget previously was
      // with the ghostController animation.
      if (_ghostIndex == index) {
        return _buildContainerForScrollDirection(children: <Widget>[
          SizeTransition(
            sizeFactor: _ghostController,
            axis: widget.scrollDirection,
            child: spacing,
          ),
          child,
        ]);
      }
      return child;
    }

    // We wrap the drag target in a Builder so that we can scroll to its specific context.
    return RepaintBoundary(
      child: Builder(builder: (BuildContext context) {
        return DragTarget<Key>(
          builder: buildDragTarget,
          onWillAccept: (Key toAccept) {
            setState(() {
              _nextIndex = index;
              _requestAnimationToNextIndex();
            });
            _scrollTo(context);
            // If the target is not the original starting point, then we will accept the drop.
            return _dragging == toAccept && toAccept != toWrap.key;
          },
          onAccept: (Key accepted) {
            //TODO: animation onAccept
          },
          onLeave: (final leaving) {},
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    // We use the layout builder to constrain the cross-axis size of dragging child widgets.
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final List<Widget> wrappedChildren = <Widget>[];
      if (widget.header != null) wrappedChildren.add(widget.header);
      for (int i = 0; i < widget.children.length; i += 1) {
        wrappedChildren.add(_wrap(context, widget.children[i], i, constraints));
      }
      const Key endWidgetKey = Key('DraggableList - End Widget');
      Widget finalDropArea;
      switch (widget.scrollDirection) {
        case Axis.horizontal:
          finalDropArea = SizedBox(
            key: endWidgetKey,
            width: _defaultDropAreaExtent,
            height: constraints.maxHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: widget.end,
            ),
          );
          break;
        case Axis.vertical:
        default:
          finalDropArea = SizedBox(
            key: endWidgetKey,
            width: constraints.maxWidth ?? MediaQuery.of(context).size.width,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Align(
                alignment: Alignment.topCenter,
                child: widget.end,
              ),
            ),
          );
          break;
      }
      if (widget.reverse) {
        wrappedChildren.insert(
          0,
          _wrap(context, finalDropArea, widget.children.length, constraints),
        );
      } else {
        wrappedChildren.add(
          _wrap(context, finalDropArea, widget.children.length, constraints),
        );
      }

      return SingleTouchRecognizer(
          child: _buildContainerForScrollDirection(children: wrappedChildren));
    });
  }
}

class _RawReorderableListLazyContent extends StatefulWidget {
  const _RawReorderableListLazyContent({
    @required this.header,
    @required this.end,
    @required this.itemBuilder,
    @required this.count,
    @required this.scrollDirection,
    @required this.onReorder,
    @required this.reverse,
    @required this.onDragStart,
    @required this.onDragEnd,
    @required this.scrollController,
    @required this.itemElevation,
    @required this.shape,
    @required this.padding,
    @required this.protectAreaTopLeft,
    @required this.protectAreaBottomRight,
    @required this.constraints,
  });

  final Widget Function(BuildContext, int) itemBuilder;
  final int count;
  final Widget header;
  final Widget end;
  final Axis scrollDirection;
  final ReorderCallback onReorder;
  final bool reverse;
  final Function() onDragStart;
  final Function() onDragEnd;
  final ScrollController scrollController;
  final double itemElevation;
  final ShapeBorder shape;
  final EdgeInsets padding;
  final BoxConstraints constraints;
  final double protectAreaTopLeft;
  final double protectAreaBottomRight;

  @override
  _RawReorderableListLazyContentState createState() =>
      _RawReorderableListLazyContentState();
}

class _RawReorderableListLazyContentState
    extends State<_RawReorderableListLazyContent>
    with TickerProviderStateMixin<_RawReorderableListLazyContent> {
  static const double _extraElevation = 4.0;

  // The extent along the [widget.scrollDirection] axis to allow a child to
  // drop into when the user reorders list children.
  //
  // This value is used when the extents haven't yet been calculated from
  // the currently dragging widget, such as when it first builds.
  static const double _defaultDropAreaExtent = 150.0;

  // The additional margin to place around a computed drop area.
  static const double _dropAreaMargin = 0.0;

  // How long an animation to reorder an element in the list takes.
  static const Duration _reorderAnimationDuration =
      const Duration(milliseconds: 200);

  // How long an animation to scroll to an off-screen element in the
  // list takes.
  static const Duration _scrollAnimationDuration =
      const Duration(milliseconds: 200);

  // This controls the entrance of the dragging widget into a new place.
  AnimationController _entranceController;

  // This controls the 'ghost' of the dragging widget, which is left behind
  // where the widget used to be.
  AnimationController _ghostController;

  AnimationController _dragCompleteController;

  Map<int, bool> _animations;

  // The member of widget.children currently being dragged.
  //
  // Null if no drag is underway.
  Key _dragging;

  // The last computed size of the feedback widget being dragged.
  Size _draggingFeedbackSize;

  // The location that the dragging widget occupied before it started to drag.
  int _dragStartIndex = 0;

  // The index that the dragging widget most recently left.
  // This is used to show an animation of the widget's position.
  int _ghostIndex = 0;

  // The index that the dragging widget currently occupies.
  int _currentIndex = 0;

  // The widget to move the dragging widget too after the current index.
  int _nextIndex = 0;

  // Whether or not we are currently scrolling this view to show a widget.
  bool _scrolling = false;

  StreamController<AnimationStatus> _streamController;

  double get _dropAreaExtent {
    if (_draggingFeedbackSize == null) {
      return _defaultDropAreaExtent;
    }
    double dropAreaWithoutMargin;
    switch (widget.scrollDirection) {
      case Axis.horizontal:
        dropAreaWithoutMargin = _draggingFeedbackSize.width;
        break;
      case Axis.vertical:
      default:
        dropAreaWithoutMargin = _draggingFeedbackSize.height;
        break;
    }
    switch (widget.scrollDirection) {
      case Axis.horizontal:
        return dropAreaWithoutMargin +
            _dropAreaMargin +
            widget.padding.left +
            widget.padding.right;
      case Axis.vertical:
        return dropAreaWithoutMargin +
            _dropAreaMargin +
            widget.padding.top +
            widget.padding.bottom;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    assert(widget.scrollController != null);
    _streamController = StreamController.broadcast();
    _entranceController =
        AnimationController(vsync: this, duration: _reorderAnimationDuration);
    _ghostController =
        AnimationController(vsync: this, duration: _reorderAnimationDuration);
    _animations = {
      _ghostController.hashCode: false,
      _entranceController.hashCode: false,
    };

    _ghostController.addStatusListener((AnimationStatus status) {
      _animations[_ghostController.hashCode] =
          status == AnimationStatus.forward ||
              status == AnimationStatus.reverse;
      _streamController.sink.add(status);
    });
    _entranceController.addStatusListener((AnimationStatus status) {
      _animations[_entranceController.hashCode] =
          status == AnimationStatus.forward ||
              status == AnimationStatus.reverse;
      _streamController.sink.add(status);
      if (status == AnimationStatus.completed)
        setState(() {
          _requestAnimationToNextIndex();
        });
    });

    _dragCompleteController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _streamController.close();
    _entranceController.dispose();
    _ghostController.dispose();
    _dragCompleteController.dispose();
    super.dispose();
  }

  // Animates the droppable space from _currentIndex to _nextIndex.
  Future<void> _requestAnimationToNextIndex() async {
    if (_entranceController.isCompleted) {
      _ghostIndex = _currentIndex;
      if (_nextIndex == _currentIndex) {
        return;
      }
      _currentIndex = _nextIndex;
      await Future.wait([
        _ghostController.reverse(from: 1.0),
        _entranceController.forward(from: 0.0),
      ]);
    }
  }

  Future<void> _animation() async {
    if (!_entranceController.isAnimating) return;
    await _streamController.stream.firstWhere((status) =>
        !_animations[_ghostController.hashCode] &&
        !_animations[_entranceController.hashCode]);
    // await the frame finished that the widgets' positions actually settle down.
    await SchedulerBinding.instance.endOfFrame;
  }

  // Scrolls to a target context if that context is not on the screen.
  void _scrollTo(BuildContext context) {
    if (_scrolling) return;
    final RenderObject contextObject = context.findRenderObject();
    final RenderAbstractViewport viewport =
        RenderAbstractViewport.of(contextObject);
    assert(viewport != null);
    // If and only if the current scroll offset falls in-between the offsets
    // necessary to reveal the selected context at the top or bottom of the
    // screen, then it is already on-screen.

    final double scrollOffset = widget.scrollController.offset;
    final double topOffset = max(
        widget.scrollController.position.minScrollExtent,
        viewport.getOffsetToReveal(contextObject, 0.0).offset -
            widget.protectAreaTopLeft);
    final double bottomOffset = min(
        widget.scrollController.position.maxScrollExtent,
        viewport.getOffsetToReveal(contextObject, 1.0).offset +
            widget.protectAreaBottomRight);
    final bool onScreen =
        scrollOffset <= topOffset && scrollOffset >= bottomOffset;

    // If the context is off screen, then we request a scroll to make it visible.
    if (!onScreen) {
      _scrolling = true;
      widget.scrollController.position
          .animateTo(
        scrollOffset < bottomOffset ? bottomOffset : topOffset,
        duration: _scrollAnimationDuration,
        curve: Curves.easeInOut,
      )
          .then((void value) {
        setState(() {
          _scrolling = false;
        });
      });
    }
  }

  // Wraps children in Row or Column, so that the children flow in
  // the widget's scrollDirection.
  Widget _buildContainerForScrollDirection({List<Widget> children, Key key}) {
    switch (widget.scrollDirection) {
      case Axis.horizontal:
        return Row(
            key: key, mainAxisSize: MainAxisSize.min, children: children);
      case Axis.vertical:
      default:
        return Column(
            key: key, mainAxisSize: MainAxisSize.min, children: children);
    }
  }

  // Places the value from startIndex one space before the element at endIndex.
  void reorder(int startIndex, int endIndex) {
    debugPrint('startIndex: $startIndex \nendIndex: $endIndex');
    setState(() {
      if (startIndex != endIndex) widget.onReorder(startIndex, endIndex);
      // Animates leftover space in the drop area closed.
      // TODO(djshuckerow): bring the animation in line with the Material
      // specifications.
      _ghostController.reset();
      _entranceController.reset();
      _dragging = null;
    });
  }

  // For get entrance location.
  GlobalKey _entranceKey;

  _feedback() {
    return Feedback.forLongPress(context);
  }

  OverlayEntry _currentOverlayEntry;

  _releaseDraggableAnimation(
      final BoxConstraints constraints
      /*For Limit the widget size*/,
      final Velocity velocity) async {
    final GlobalObjectKey draggingKey = GlobalObjectKey(_dragging);
    final RenderBox startRenderBox =
        draggingKey.currentContext?.findRenderObject();
    if (startRenderBox == null) return;
    final start = startRenderBox.localToGlobal(Offset.zero) -
        Offset(widget.padding.left, widget.padding.top);

    Animation<Offset> _offsetAnimation = AlwaysStoppedAnimation<Offset>(start);
    Animation<double> _elevationAnimation =
        AlwaysStoppedAnimation(widget.itemElevation + _extraElevation);
    // If something was release from dragging during other release dragging animation
    // Remove the former one and insert the new one
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = OverlayEntry(builder: (BuildContext context) {
      return Stack(
        children: <Widget>[
          // Protect Layout changed by user
          Positioned.fill(child: AbsorbPointer(absorbing: true)),
          AnimatedBuilder(
            animation: _dragCompleteController,
            builder: (BuildContext context, Widget child) {
              final offset = _offsetAnimation.value;
              return Container(
                alignment: Alignment.topLeft,
                constraints: constraints,
                transform: Matrix4.translationValues(offset.dx, offset.dy, 0.0),
                child: Padding(
                  padding: widget.padding,
                  child: Material(
                      elevation: _elevationAnimation.value,
                      shape: widget.shape,
                      clipBehavior: Clip.hardEdge,
                      animationDuration: Duration.zero,
                      child: child),
                ),
              );
            },
            child: draggingKey.currentWidget,
          ),
        ],
      );
    });
    Overlay.of(context).insert(_currentOverlayEntry);

    // wait for entrance animation completed
    _requestAnimationToNextIndex();
    await _animation();

    // get the end point Offset
    final RenderBox endRenderBox =
        _entranceKey.currentContext.findRenderObject();
    if (endRenderBox == null) {
      _currentOverlayEntry.remove();
      _currentOverlayEntry = null;
    }
    final end = endRenderBox.localToGlobal(Offset.zero);

    _offsetAnimation =
        Tween(begin: start, end: end).animate(_dragCompleteController);
    _elevationAnimation =
        Tween(begin: _elevationAnimation.value, end: widget.itemElevation)
            .animate(_dragCompleteController);

    final screen = MediaQuery.of(context).size;
    final dis = end - start;
    final stiffness = 10 * (dis.distance / screen.height);
    final spring = SpringDescription(
      mass: 30,
      stiffness: stiffness <= 0.1 ? 0.1 : stiffness,
      damping: 1,
    );
    if (velocity != null)
      switch (widget.scrollDirection) {
        case Axis.horizontal:
          // TODO: Handle this case.
          final double vel =
              dis.dx.isNegative == velocity.pixelsPerSecond.dx.isNegative
                  ? -velocity.pixelsPerSecond.dx / screen.width
                  : velocity.pixelsPerSecond.dx / screen.width;
          final simulation = SpringSimulation(spring, 0, 1, vel);
          await _dragCompleteController.animateWith(simulation);
          break;
        case Axis.vertical:
          // TODO: Handle this case.
          final double vel =
              dis.dy.isNegative == velocity.pixelsPerSecond.dy.isNegative
                  ? -velocity.pixelsPerSecond.dy / screen.height
                  : velocity.pixelsPerSecond.dy / screen.height;
          final simulation = SpringSimulation(spring, 0, 1, vel);
          await _dragCompleteController.animateWith(simulation);
          break;
      }
    else {
      final simulation = SpringSimulation(spring, 0, 1, 0);
      await _dragCompleteController.animateWith(simulation);
    }

    _currentOverlayEntry.remove();
    _currentOverlayEntry = null;
  }

  // Wraps one of the widget's children in a DragTarget and Draggable.
  // Handles up the logic for dragging and reordering items in the list.
  Widget _wrap(BuildContext context, Widget toWrap, int index,
      BoxConstraints constraints) {
    assert(toWrap.key != null);
    final GlobalObjectKey keyIndexGlobalKey = GlobalObjectKey(toWrap.key);
    // We pass the toWrapWithGlobalKey into the Draggable so that when a list
    // item gets dragged, the accessibility framework can preserve the selected
    // state of the dragging item.
    // Starts dragging toWrap.
    void onDragStarted() {
      Future(_feedback);
      setState(() {
        _dragging = toWrap.key;
        _dragStartIndex = index;
        _ghostIndex = index;
        _currentIndex = index;
        _entranceController.value = 1.0;
        _draggingFeedbackSize = keyIndexGlobalKey.currentContext.size;
        if (widget?.onDragStart != null) widget?.onDragStart();
      });
    }

    // Drops toWrap into the last position it was hovering over.
    void onDragEnded({final Velocity velocity}) async {
      await _releaseDraggableAnimation(constraints, velocity);
      // Animation finished
      reorder(_dragStartIndex, _currentIndex);
      if (widget.onDragEnd != null) widget.onDragEnd();
    }

    Widget wrapWithSemantics() {
      // First, determine which semantics actions apply.
      final Map<CustomSemanticsAction, VoidCallback> semanticsActions =
          <CustomSemanticsAction, VoidCallback>{};

      // Create the appropriate semantics actions.
      void moveToStart() => reorder(index, 0);
      void moveToEnd() => reorder(index, widget.count);
      void moveBefore() => reorder(index, index - 1);
      // To move after, we go to index+2 because we are moving it to the space
      // before index+2, which is after the space at index+1.
      void moveAfter() => reorder(index, index + 2);

      final MaterialLocalizations localizations =
          MaterialLocalizations.of(context);

      // If the item can move to before its current position in the list.
      if (index > 0) {
        semanticsActions[CustomSemanticsAction(
            label: localizations.reorderItemToStart)] = moveToStart;
        String reorderItemBefore = localizations.reorderItemUp;
        if (widget.scrollDirection == Axis.horizontal) {
          reorderItemBefore = Directionality.of(context) == TextDirection.ltr
              ? localizations.reorderItemLeft
              : localizations.reorderItemRight;
        }
        semanticsActions[CustomSemanticsAction(label: reorderItemBefore)] =
            moveBefore;
      }

      // If the item can move to after its current position in the list.
      if (index < widget.count - 1) {
        String reorderItemAfter = localizations.reorderItemDown;
        if (widget.scrollDirection == Axis.horizontal) {
          reorderItemAfter = Directionality.of(context) == TextDirection.ltr
              ? localizations.reorderItemRight
              : localizations.reorderItemLeft;
        }
        semanticsActions[CustomSemanticsAction(label: reorderItemAfter)] =
            moveAfter;
        semanticsActions[
                CustomSemanticsAction(label: localizations.reorderItemToEnd)] =
            moveToEnd;
      }

      // We pass toWrap with a GlobalKey into the Draggable so that when a list
      // item gets dragged, the accessibility framework can preserve the selected
      // state of the dragging item.
      //
      // We also apply the relevant custom accessibility actions for moving the item
      // up, down, to the start, and to the end of the list.
      return KeyedSubtree(
        key: keyIndexGlobalKey,
        child: MergeSemantics(
          child: Semantics(
            customSemanticsActions: semanticsActions,
            child: toWrap,
          ),
        ),
      );
    }

    Widget buildDragTarget(BuildContext context, List<Key> acceptedCandidates,
        List rejectedCandidates) {
      final Widget toWrapWithSemantics = wrapWithSemantics();

      // We build the draggable inside of a layout builder so that we can
      // constrain the size of the feedback dragging widget.
      Widget child = LongPressDraggable<Key>(
        maxSimultaneousDrags: 1,
        axis: widget.scrollDirection,
        data: toWrap.key,
        ignoringFeedbackSemantics: false,
        feedback: Container(
          alignment: Alignment.topLeft,
          // These constraints will limit the cross axis of the drawn widget.
          constraints: constraints,
          child: Padding(
              padding: widget.padding,
              child: Material(
                  elevation: widget.itemElevation + _extraElevation,
                  shape: widget.shape,
                  clipBehavior: Clip.hardEdge,
                  child: toWrapWithSemantics)),
        ),
        childWhenDragging: const SizedBox(),
        dragAnchor: DragAnchor.child,
        onDragStarted: onDragStarted,
        onDragCompleted: onDragEnded,
        onDraggableCanceled: (Velocity velocity, Offset offset) {
          onDragEnded(velocity: velocity);
        },
        child: _dragging == toWrap.key
            ? const SizedBox()
            : Padding(
                padding: widget.padding,
                child: Material(
                    elevation: widget.itemElevation,
                    shape: widget.shape,
                    clipBehavior: Clip.hardEdge,
                    child: toWrapWithSemantics)),
      );

      // The target for dropping at the end of the list doesn't need to be
      // draggable.
      if (index >= widget.count) {
        child = toWrap;
      }

      // Determine the size of the drop area to show under the dragging widget.
      Widget spacing;
      switch (widget.scrollDirection) {
        case Axis.horizontal:
          spacing = SizedBox(width: _dropAreaExtent);
          break;
        case Axis.vertical:
        default:
          spacing = SizedBox(height: _dropAreaExtent);
          break;
      }

      // We open up a space under where the dragging widget currently is to
      // show it can be dropped.
      if (_currentIndex == index) {
        _entranceKey = GlobalKey();
        return _buildContainerForScrollDirection(
            key: _entranceKey,
            children: <Widget>[
              SizeTransition(
                sizeFactor: _entranceController,
                axis: widget.scrollDirection,
                child: spacing,
              ),
              child,
            ]);
      }
      // We close up the space under where the dragging widget previously was
      // with the ghostController animation.
      if (_ghostIndex == index) {
        return _buildContainerForScrollDirection(children: <Widget>[
          SizeTransition(
            sizeFactor: _ghostController,
            axis: widget.scrollDirection,
            child: spacing,
          ),
          child,
        ]);
      }
      return child;
    }

    // We wrap the drag target in a Builder so that we can scroll to its specific context.
    return Builder(builder: (BuildContext context) {
      return DragTarget<Key>(
        builder: buildDragTarget,
        onWillAccept: (Key toAccept) {
          setState(() {
            _nextIndex = index;
            _requestAnimationToNextIndex();
          });
          _scrollTo(context);
          // If the target is not the original starting point, then we will accept the drop.
          return _dragging == toAccept && toAccept != toWrap.key;
        },
        onAccept: (Key accepted) {
          //TODO: animation onAccept
        },
        onLeave: (final leaving) {},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    // We use the layout builder to constrain the cross-axis size of dragging child widgets.

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          if (index == 0)
            return widget.header;
          else if (index == widget.count + 1) {
            const Key endWidgetKey = Key('DraggableList - End Widget');
            Widget finalDropArea;
            switch (widget.scrollDirection) {
              case Axis.horizontal:
                finalDropArea = SizedBox(
                  key: endWidgetKey,
                  width: _defaultDropAreaExtent,
                  height: widget.constraints.maxHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: widget.end,
                  ),
                );
                break;
              case Axis.vertical:
              default:
                finalDropArea = SizedBox(
                  key: endWidgetKey,
                  width: widget.constraints.maxWidth ??
                      MediaQuery.of(context).size.width,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: widget.end,
                    ),
                  ),
                );
                break;
            }
            return _wrap(context, finalDropArea, index - 1, widget.constraints);
          } else if (index > widget.count + 1)
            return null;
          else
            return _wrap(context, widget.itemBuilder(context, index - 1),
                index - 1, widget.constraints);
        },
        addAutomaticKeepAlives: true,
        childCount: widget.count + 2,
      ),
    );
  }
}
