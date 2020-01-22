import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music/component.dart';
import 'package:music/component/CustomList.dart';

const SettingDatabase = 'setting';

class SettingStorage extends BaseList<String> with DataBaseExtendList {
  static final SettingStorage instance = SettingStorage._internal();

  factory SettingStorage() {
    return instance;
  }

  SettingStorage._internal() {
    initialization = _init();
  }

  Future initialization;

  _init() async {
    await bind(database: SettingDatabase, table: 'normal');

    themeInit() async {
      if (getData(ThemeHeritage.storageKey) == null)
        await setData('ThemeHeritage.storageKey', themesName[Themes.Blue]);
    }

    await themeInit();
  }

  final DatabaseKey primaryKey = DatabaseKey<String>(keyName: 'id');
  final DatabaseKey dataKey = DatabaseKey<String>(keyName: 'data');

  final Map<String, String> dataMap = Map();

  getData(final String key) {
    return dataMap[key];
  }

  setData(final String key, final String data) async {
    if (!contains(key)) add(key);
    dataMap[key] = data;
    await batchDatabaseUpdate({indexOf(key)});
  }

  @override
  Map<String, String> elementToMap({int index, String element}) {
    // TODO: implement elementToMap
    if (index == null) index = indexOf(element);
    return {
      primaryKey.keyName: this[index],
      dataKey.keyName: dataMap[this[index]]
    };
  }

  @override
  Future<List> recoverToList() async {
    // TODO: implement recoverToList
    final Iterable<Map> _maps = await maps;
    final List<String> list = List();
    for (final Map e in _maps) {
      final key = e[primaryKey.keyName];
      list.add(key);
      dataMap[key] = e[dataKey.keyName];
    }
    return list;
  }

  @override
  // TODO: implement structure
  List<DatabaseKey> get structure => [primaryKey, dataKey];
}

enum Themes {
  Blue,
  Purple,
  Indigo,
  Black,
  White,
}

final themesName = {
  Themes.Blue: 'Blue',
  Themes.Purple: 'Purple',
  Themes.Indigo: 'Indigo',
  Themes.Black: 'Black',
  Themes.White: 'White',
};

final themesData = {
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
  static const String storageKey = 'Theme';

  static String toName({Themes theme, ThemeData themeData}) {
    return themesName[theme];
  }

  static Themes getThemes({final String name}) {
    Themes themes;
    themesName.forEach((final key, final value) {
      if (value == name) themes = key;
    });
    return themes;
  }

  static ThemeHeritage of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeHeritage>();
  }

  ThemeHeritage({
    @required HeritageBuilder<ThemeData> heritageBuilder,
    Themes theme = Themes.Black,
  }) : super(
            controller: ValueNotifier(themesData[theme]),
            heritageBuilder: heritageBuilder);

  void changeTheme({ThemeData themeData, Themes theme}) {
    if (themeData != null)
      super.change(themeData);
    else if (theme != null) {
      super.change(themesData[theme]);
      SettingStorage.instance.setData(storageKey, themesName[theme]);
    }
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
