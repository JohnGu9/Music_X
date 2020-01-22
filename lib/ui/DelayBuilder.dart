import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:music/component.dart';
import 'package:music/unit/Streams.dart';

typedef DelayValueWidgetBuilder<T> = Widget Function(
    BuildContext context, T value, Widget child);

class DelayValueListenableBuilder<T> extends StatefulWidget {
  const DelayValueListenableBuilder(
      {Key key, @required this.listenable, @required this.builder, this.child})
      : assert(builder != null),
        super(key: key);

  /// [listenable] is safe if it is nullptr
  /// the value will return null if [listenable] is nullptr
  final ValueListenable<T> listenable;
  final Widget child;
  final DelayValueWidgetBuilder<T> builder;

  @override
  _DelayValueListenableBuilderState<T> createState() =>
      _DelayValueListenableBuilderState<T>();
}

class _DelayValueListenableBuilderState<T>
    extends State<DelayValueListenableBuilder<T>> {
  static final RebuildManager rebuildManager = RebuildManager();

  T _value;

  void _listener() {
    rebuildManager.runTask(_onChanged, AsyncTaskPriority.MIN);
  }

 String _onChanged() {
    if (mounted) {
      setState(() {
        _value = widget.listenable?.value;
      });
    }
    return null;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _onChanged();
    widget.listenable?.addListener(_listener);
  }

  @override
  void didUpdateWidget(DelayValueListenableBuilder oldWidget) {
    // TODO: implement didUpdateWidget
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable?.removeListener(_listener);
      widget.listenable?.addListener(_listener);
      _value = widget.listenable?.value;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    // TODO: implement dispose
    widget.listenable?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return widget.builder(context, _value, widget.child);
  }
}

typedef RebuildTask = String Function();

class RebuildManager extends AsyncTaskManager<RebuildTask> {
  @override
  Stream<RebuildTask> run() async* {
    await for (final RebuildTask fn in controller.stream) {
      await AnimationStream.instance.idle();
      await SchedulerBinding.instance.scheduleTask(fn, Priority.animation);
      yield fn;
    }
  }
}
