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
import 'package:musicx/component/SingleTouchRecognizer.dart';

//import 'debug.dart';
//import 'material.dart';
//import 'material_localizations.dart';

// Examples can assume:
// class MyDataObject { }

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
  // We use an inner overlay so that the dragging list item doesn't draw outside of the list itself.
  final GlobalKey _overlayKey =
      GlobalKey(debugLabel: '$CustomReorderableListView overlay key');

  // This entry contains the scrolling list itself.
  OverlayEntry _listOverlayEntry;

  @override
  void initState() {
    super.initState();
    _listOverlayEntry = OverlayEntry(
      maintainState: true,
      opaque: true,
      builder: (BuildContext context) {
        return _ReorderableListContent(
          header: widget.header,
          end: widget.end,
          children: widget.children,
          scrollDirection: widget.scrollDirection,
          onReorder: widget.onReorder,
          padding: widget.padding,
          reverse: widget.reverse,
          onDragStart: widget.onDragStart,
          onDragEnd: widget.onDragEnd,
        );
      },
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _listOverlayEntry.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(key: _overlayKey, initialEntries: <OverlayEntry>[
      _listOverlayEntry,
    ]);
  }
}

// This widget is responsible for the inside of the Overlay in the
// ReorderableListView.
class _ReorderableListContent extends StatefulWidget {
  const _ReorderableListContent({
    @required this.header,
    @required this.end,
    @required this.children,
    @required this.scrollDirection,
    @required this.padding,
    @required this.onReorder,
    @required this.reverse,
    @required this.onDragStart,
    @required this.onDragEnd,
  });

  final Widget header;
  final Widget end;
  final List<Widget> children;
  final Axis scrollDirection;
  final EdgeInsets padding;
  final ReorderCallback onReorder;
  final bool reverse;
  final Function() onDragStart;
  final Function() onDragEnd;

  @override
  _ReorderableListContentState createState() => _ReorderableListContentState();
}

class _ReorderableListContentState extends State<_ReorderableListContent>
    with TickerProviderStateMixin<_ReorderableListContent> {
  // The extent along the [widget.scrollDirection] axis to allow a child to
  // drop into when the user reorders list children.
  //
  // This value is used when the extents haven't yet been calculated from
  // the currently dragging widget, such as when it first builds.
  static const double _defaultDropAreaExtent = 150.0;

  // The additional margin to place around a computed drop area.
  static const double _dropAreaMargin = 4.0;

  // How long an animation to reorder an element in the list takes.
  static const Duration _reorderAnimationDuration =
      const Duration(milliseconds: 200);

  // How long an animation to scroll to an off-screen element in the
  // list takes.
  static const Duration _scrollAnimationDuration =
      const Duration(milliseconds: 200);

  // Controls scrolls and measures scroll progress.
  ScrollController _scrollController;

  // This controls the entrance of the dragging widget into a new place.
  AnimationController _entranceController;

  // This controls the 'ghost' of the dragging widget, which is left behind
  // where the widget used to be.
  AnimationController _ghostController;

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
    return dropAreaWithoutMargin + _dropAreaMargin;
  }

  @override
  void initState() {
    super.initState();
    _entranceController =
        AnimationController(vsync: this, duration: _reorderAnimationDuration);
    _ghostController =
        AnimationController(vsync: this, duration: _reorderAnimationDuration);
    _entranceController.addStatusListener(_onEntranceStatusChanged);
  }

  @override
  void didChangeDependencies() {
    _scrollController =
        PrimaryScrollController.of(context) ?? ScrollController();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ghostController.dispose();
    super.dispose();
  }

  // Animates the droppable space from _currentIndex to _nextIndex.
  void _requestAnimationToNextIndex() {
    if (_entranceController.isCompleted) {
      _ghostIndex = _currentIndex;
      if (_nextIndex == _currentIndex) {
        return;
      }
      _currentIndex = _nextIndex;
      _ghostController.reverse(from: 1.0);
      _entranceController.forward(from: 0.0);
    }
  }

  // Requests animation to the latest next index if it changes during an animation.
  void _onEntranceStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _requestAnimationToNextIndex();
      });
    }
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
    final double margin = _dropAreaExtent;
    final double scrollOffset = _scrollController.offset;
    final double topOffset = max(
      _scrollController.position.minScrollExtent,
      viewport.getOffsetToReveal(contextObject, 0.0).offset - margin,
    );
    final double bottomOffset = min(
      _scrollController.position.maxScrollExtent,
      viewport.getOffsetToReveal(contextObject, 1.0).offset + margin,
    );
    final bool onScreen =
        scrollOffset <= topOffset && scrollOffset >= bottomOffset;

    // If the context is off screen, then we request a scroll to make it visible.
    if (!onScreen) {
      _scrolling = true;
      _scrollController.position
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
  Widget _buildContainerForScrollDirection({List<Widget> children}) {
    switch (widget.scrollDirection) {
      case Axis.horizontal:
        return Row(children: children);
      case Axis.vertical:
      default:
        return Column(children: children);
    }
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
    void onDragStarted() => setState(() {
          Feedback.forLongPress(context);
          _dragging = toWrap.key;
          _dragStartIndex = index;
          _ghostIndex = index;
          _currentIndex = index;
          _entranceController.value = 1.0;
          _draggingFeedbackSize = keyIndexGlobalKey.currentContext.size;
          if (widget?.onDragStart != null) widget?.onDragStart();
        });

    // Places the value from startIndex one space before the element at endIndex.
    void reorder(int startIndex, int endIndex) => setState(() {
          if (startIndex != endIndex) widget.onReorder(startIndex, endIndex);
          // Animates leftover space in the drop area closed.
          // TODO(djshuckerow): bring the animation in line with the Material
          // specifications.
          _ghostController.reverse(from: 0.1);
          _entranceController.reverse(from: 0.1);
          _dragging = null;
        });

    // Drops toWrap into the last position it was hovering over.
    void onDragEnded() {
      reorder(_dragStartIndex, _currentIndex);
      if (widget?.onDragEnd != null) widget.onDragEnd();
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
        List<dynamic> rejectedCandidates) {
      final Widget toWrapWithSemantics = wrapWithSemantics();

      // We build the draggable inside of a layout builder so that we can
      // constrain the size of the feedback dragging widget.
      Widget child = LongPressDraggable<Key>(
        hapticFeedbackOnStart: true,
        maxSimultaneousDrags: 1,
        axis: widget.scrollDirection,
        data: toWrap.key,
        ignoringFeedbackSemantics: false,
        feedback: Container(
          alignment: Alignment.topLeft,
          // These constraints will limit the cross axis of the drawn widget.
          constraints: constraints,
          child: Material(
            elevation: 6.0,
            child: toWrapWithSemantics,
          ),
        ),
        child: _dragging == toWrap.key ? const SizedBox() : toWrapWithSemantics,
        childWhenDragging: const SizedBox(),
        dragAnchor: DragAnchor.child,
        onDragStarted: onDragStarted,
        // When the drag ends inside a DragTarget widget, the drag
        // succeeds, and we reorder the widget into position appropriately.
        onDragCompleted: onDragEnded,
        // When the drag does not end inside a DragTarget widget, the
        // drag fails, but we still reorder the widget to the last position it
        // had been dragged to.
        onDraggableCanceled: (Velocity velocity, Offset offset) {
          onDragEnded();
        },
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
        return _buildContainerForScrollDirection(children: <Widget>[
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
        onAccept: (Key accepted) {},
        onLeave: (Key leaving) {},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    // We use the layout builder to constrain the cross-axis size of dragging child widgets.
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      final List<Widget> wrappedChildren = <Widget>[];
      if (widget.header != null) {
        wrappedChildren.add(widget.header);
      }
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
            child: Align(
              alignment: Alignment.topCenter,
              child: widget.end,
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

      return SingleChildScrollView(
        scrollDirection: widget.scrollDirection,
        child: _buildContainerForScrollDirection(children: wrappedChildren),
        padding: widget.padding,
        controller: _scrollController,
        reverse: widget.reverse,
      );
    });
  }
}

/// Additional Extend
/// add [SliverReorderableListView] and [RawReorderableListView]
const _elevation = 4.0;
const _shape =
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)));

const _padding = EdgeInsets.all(2.0);

class SliverReorderableListView extends StatelessWidget {
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
  })  : assert(scrollDirection != null),
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
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.onDragStart,
    this.onDragEnd,
    @required this.scrollController,
  })  : assert(scrollDirection != null),
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

  final ScrollController scrollController;

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
      itemElevation: _elevation,
      shape: _shape,
      padding: _padding,
    );
  }
}

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
        // TODO: Handle this case.
        return dropAreaWithoutMargin +
            _dropAreaMargin +
            widget.padding.left +
            widget.padding.right;
      case Axis.vertical:
        // TODO: Handle this case.
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
    const double protectAreaTopLeft = 70;
    const double protectAreaBottomRight = 30;

    final double margin = _dropAreaExtent;
    final double scrollOffset = widget.scrollController.offset;
    final double topOffset = max(
        widget.scrollController.position.minScrollExtent,
        viewport.getOffsetToReveal(contextObject, 0.0).offset -
            margin -
            protectAreaTopLeft);
    final double bottomOffset = min(
        widget.scrollController.position.maxScrollExtent,
        viewport.getOffsetToReveal(contextObject, 1.0).offset +
            margin +
            protectAreaBottomRight);
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
        onLeave: (Key leaving) {},
      );
    });
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
