import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:musicx/unit/Streams.dart';

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
  T _value;

  void _listener() async {
    await AnimationStream.instance.idle();
    if (mounted) setState(_onChanged);
  }

  void _onChanged() {
    _value = widget.listenable?.value;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    widget.listenable.addListener(_listener);
  }

  @override
  void didUpdateWidget(DelayValueListenableBuilder oldWidget) {
    // TODO: implement didUpdateWidget
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_listener);
      widget.listenable.addListener(_listener);
      _onChanged();
    }
    super.didUpdateWidget(oldWidget);
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
    return widget.builder(context, _value, widget.child);
  }
}
