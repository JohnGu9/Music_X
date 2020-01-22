import 'package:flutter/material.dart';

class Constants {
  static const physics = BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  static const Radius radius = Radius.elliptical(40, 30);

  static reorder(List list, int oldIndex, int newIndex) {
    return (oldIndex < newIndex)
        ? list.insert(newIndex - 1, list.removeAt(oldIndex))
        : list.insert(newIndex, list.removeAt(oldIndex));
  }

  static Widget expandedLayoutBuilder(Widget currentChild, List<Widget> previousChildren) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ...previousChildren,
        if (currentChild != null) currentChild,
      ],
      alignment: Alignment.center,
    );
  }
}
