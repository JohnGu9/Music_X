import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum Themes {
  Blue,
  Purple,
  Indigo,
  Black,
  White,
}

final _name = {
  Themes.Blue: 'Blue',
  Themes.Purple: 'Purple',
  Themes.Indigo: 'Indigo',
  Themes.Black: 'Black',
  Themes.White: 'White',
};

final themes = {
  Themes.Blue: ThemeData(
    primarySwatch: Colors.blue,
  ),
  Themes.Purple: ThemeData(
    primarySwatch: Colors.purple,
  ),
  Themes.Indigo: ThemeData(
    primarySwatch: Colors.indigo,
  ),
  Themes.Black: ThemeData(
    brightness: Brightness.dark,
    sliderTheme: const SliderThemeData(
      trackHeight: 2,
      trackShape: RoundedRectSliderTrackShape(),
      activeTrackColor: Colors.white30,
      inactiveTrackColor: Colors.black54,
      tickMarkShape: RoundSliderTickMarkShape(tickMarkRadius: 0.0),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0.0),
    ),
  ),
  Themes.White: ThemeData(
      primarySwatch: Colors.grey,
      backgroundColor: Colors.grey[100],
      brightness: Brightness.light),
};

class ThemeHeritage extends Heritage<ThemeData> {
  static String toName({Themes theme, ThemeData themeData}) {
    return _name[theme];
  }

  static ThemeHeritage of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeHeritage>();
  }

  ThemeHeritage({
    @required HeritageBuilder<ThemeData> heritageBuilder,
    Themes theme = Themes.Black,
  }) : super(
            controller: ValueNotifier(themes[theme]),
            heritageBuilder: heritageBuilder);

  void changeTheme({ThemeData themeData, Themes theme}) {
    if (themeData != null)
      super.change(themeData);
    else if (theme != null) super.change(themes[theme]);
  }
}

typedef HeritageBuilder<T> = Widget Function(BuildContext context, T value);

class Heritage<T> extends InheritedWidget {
  Heritage(
      {Key key,
      @required this.controller,
      @required HeritageBuilder<T> heritageBuilder})
      : super(
            key: key,
            child: ValueListenableBuilder(
                builder: (BuildContext context, T value, Widget child) {
                  return heritageBuilder(context, value);
                },
                valueListenable: controller));

  final ValueNotifier<T> controller;

  T get value => controller.value;

  void change(T v) {
    controller.value = v;
  }

  @override
  bool updateShouldNotify(Heritage oldWidget) {
    // TODO: implement updateShouldNotify
    return oldWidget.controller != controller;
  }
}
