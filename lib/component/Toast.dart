import 'dart:async';

import 'package:flutter/material.dart';


class Toast {
  static List<Future> removeTasks = List();
  static const standardAlignment = Alignment(0, 0.75);
  static const standardPadding =
      EdgeInsets.symmetric(vertical: 12, horizontal: 20);

  static _onRemoved(value) => removeTasks.clear();

  static easeMassage(
    BuildContext context, {
    final String text = 'EaseMassage',
    final Duration duration = const Duration(seconds: 2),
    final bool monopoly = true,
  }) async {
    final overlay = Overlay.of(context);
    if (monopoly)
      while (removeTasks.isNotEmpty)
        await Future.wait(removeTasks, cleanUp: _onRemoved);
    if (!overlay.mounted) return;

    final GlobalKey<ToastState> _key = GlobalKey();
    final _entry = OverlayEntry(
        builder: (BuildContext context) => EaseMassage(key: _key, text: text));
    overlay.insert(_entry);
    Future _toRemove;
    _toRemove = Future(() async {
      await Future.delayed(duration);
      await _key?.currentState?.remove();
      _entry.remove();
      removeTasks.remove(_toRemove);
    });
    removeTasks.add(_toRemove);
  }

  static massage(final BuildContext context, Widget child,
      {Duration duration = const Duration(seconds: 2),
      final bool monopoly = true}) async {
    assert(duration != null);
    if (monopoly)
      while (removeTasks.isNotEmpty)
        await Future.wait(removeTasks, cleanUp: _onRemoved);

    final _entry = OverlayEntry(builder: (BuildContext context) => child);
    Overlay.of(context).insert(_entry);
    Future _toRemove;
    _toRemove = Future(() async {
      await Future.delayed(duration);
      if (child?.key != null && child.key is GlobalKey<ToastState>)
        await (child.key as GlobalKey<ToastState>)?.currentState?.remove();
      _entry.remove();
      removeTasks.remove(_toRemove);
    });
    removeTasks.add(_toRemove);
  }
}

abstract class ToastState<T extends StatefulWidget> extends State<T> {
  @protected
  Future remove();
}

class EaseMassage extends StatefulWidget {
  const EaseMassage({Key key, this.text}) : super(key: key);
  final String text;

  @override
  _EaseMassageState createState() => _EaseMassageState();
}

class _EaseMassageState extends ToastState<EaseMassage>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  static const duration = const Duration(milliseconds: 500);

  @override
  Future remove() async {
    if (mounted) await _controller.animateTo(0.0, curve: Curves.easeInOutSine);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = AnimationController(vsync: this, duration: duration);
    _controller.animateTo(1.0, curve: Curves.fastOutSlowIn);
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
    return Align(
      alignment: Toast.standardAlignment,
      child: FadeTransition(
        opacity: _controller,
        child: Card(
            elevation: 6.0,
            child: Padding(
              padding: Toast.standardPadding,
              child: Text(
                widget.text,
                style: Theme.of(context).textTheme.body2,
              ),
            )),
      ),
    );
  }
}
