import 'package:flutter/material.dart';

class Constants {
  static const physics = BouncingScrollPhysics();
  static const Radius radius = Radius.elliptical(50, 40);

  static reorder(List list, int oldIndex, int newIndex) {
    return (oldIndex < newIndex)
        ? list.insert(newIndex - 1, list.removeAt(oldIndex))
        : list.insert(newIndex, list.removeAt(oldIndex));
  }
}
