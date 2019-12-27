import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static Database database;

  static Future<Database> easeDatabase(String name) async =>
      openDatabase(path.join(await getDatabasesPath(), '$name.db'));
}

class DatabaseKey<T> {
  const DatabaseKey({@required this.keyName});

  final keyName;


  static final typeMap = {
    const DatabaseKey<String>(keyName: null).runtimeType: 'TEXT',
    const DatabaseKey<int>(keyName: null).runtimeType: 'INTEGER',
    const DatabaseKey<bool>(keyName: null).runtimeType: 'BIT',
    const DatabaseKey<double>(keyName: null).runtimeType: 'REAL',
    const DatabaseKey(keyName: null).runtimeType: 'BLOB',

    //Uint8List
    const DatabaseKey<Uint8List>(keyName: null).runtimeType: 'BLOB',
  };

  dataDecode(dynamic data) {
    return data;
  }

  dataEncode(dynamic data) {
    return data;
  }

  @override
  String toString() {
    return ', ' + keyName + ' ' + typeMap[this.runtimeType];
  }

  String toPrimaryString() {
    return keyName +
        ' ' +
        typeMap[this.runtimeType] +
        ' PRIMARY KEY NOT NULL UNIQUE';
  }

  String toWhereString() {
    return keyName + ' = ?';
  }
}

class LinkedList<T> extends ChangeNotifier implements ValueListenable<List<T>> {
  LinkedList({this.database, this.table, Future<Database> databaseAsync}) {
    if (database == null)
      this.databaseAsync = Future(() async => database = await databaseAsync)
        ..then((_) {
          assert(database != null);
        });
  }

  Future databaseAsync;
  Database database;
  final String table;
  List<T> list;

  final DatabaseKey primaryKey = DatabaseKey<T>(keyName: 'filePath');
  final DatabaseKey previousKey = DatabaseKey<T>(keyName: 'previous');
  final DatabaseKey nextKey = DatabaseKey<T>(keyName: 'next');

  static const previousIndex = 0;
  static const nextIndex = 1;

  static String generateStructure(List<DatabaseKey> keys) {
    String res = "(";
    res += keys[0].toPrimaryString();
    res += keys[1].toString();
    res += keys[2].toString();
    return res + ")";
  }

  static Future<LinkedList<T>> easeLinkedList<T>({
    @required String database,
    @required String table,
    bool drop = false,
  }) async =>
      await LinkedList<T>(
              database: await DatabaseHelper.easeDatabase(database),
              table: table)
          .bindTable(drop);

  static LinkedList<T> easeLinkedListSync<T>({
    @required String database,
    @required String table,
  }) =>
      LinkedList<T>(
          databaseAsync: DatabaseHelper.easeDatabase(database), table: table);

  Future<LinkedList<T>> bindTable(bool drop) async {
    /// [drop] whether drop the existing table
    if (this.databaseAsync != null) await databaseAsync;
    if (drop) await database.execute("drop table if exists $table");

    await database.execute("CREATE TABLE IF NOT EXISTS $table" +
        generateStructure([primaryKey, previousKey, nextKey]));
    await _initialize();
    return this;
  }

  _initialize() async {
    List<Map<String, dynamic>> maps = await this.maps;
    Map primaryKeyMap = Map<dynamic, List<dynamic>>();
    T first;
    T last;
    if (maps == null || maps.length == 0) {
      list = List<T>();
      notifyListeners();
      return;
    }
    for (final map in maps) {
      primaryKeyMap[map[primaryKey.keyName]] = [
        map[previousKey.keyName],
        map[nextKey.keyName]
      ];
      if (map[previousKey.keyName] == null) {
        first = map[primaryKey.keyName];
      }
      if (map[nextKey.keyName] == null) {
        last = map[primaryKey.keyName];
      }
    }
    list = List<T>();
    if (first != null) {
      T current = first;
      while (current != null) {
        list.add(current);
        final source = primaryKeyMap[current];
        if (source == null) {
          // data have some error
          debugPrint(
              "${this.table} has some error. Data lose [end]. Try to recovery data!");
          this[this.length - 1] = current;
          break;
        }
        current = source[nextIndex];
        if (list.contains(current)) break;
      }
    } else if (last != null) {
      T current = last;
      while (current != null) {
        list.insert(0, current);
        final source = primaryKeyMap[current];
        if (source == null) {
          debugPrint(
              "${this.table} has some error. Data lose [begin]. Try to recovery data!");
          this[0] = current;
          break;
        }
        current = source[previousIndex];
        if (list.contains(current)) break;
      }
    } else {
      assert(false);
    }
    notifyListeners();
  }

  Future<List> get maps async => await database.query('$table');

  get getMap async {
    List<Map<String, dynamic>> maps = await this.maps;
    Map primaryKeyMap = Map<dynamic, List<dynamic>>();
    if (maps == null || maps.length == 0) {
      return primaryKeyMap;
    }
    for (final map in maps) {
      primaryKeyMap[map[primaryKey.keyName]] = [
        map[previousKey.keyName],
        map[nextKey.keyName]
      ];
    }
    return primaryKeyMap;
  }

  Map<String, T> elementToMap(int index) {
    final map = Map<String, T>();
    map[primaryKey.keyName] = list[index];
    map[previousKey.keyName] = index == 0 ? null : list[index - 1];
    map[nextKey.keyName] = index == list.length - 1 ? null : list[index + 1];
    return map;
  }

  T operator [](int index) => list[index];

  operator []=(int index, T value) {
    list[index] = value;
    database.insert(
      table,
      elementToMap(index),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  int get length => list.length;

  add(T value) {
    if (list.contains(value)) {
      /// linked list can't contains two same value
      return;
    }
    list.add(value);
    if (list.length == 1) {
      database.insert(
        table,
        elementToMap(length - 1),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      database.update(
        table,
        elementToMap(length - 2),
        where: primaryKey.toWhereString(),
        whereArgs: [list[length - 2]],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      database.insert(
        table,
        elementToMap(length - 1),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    notifyListeners();
  }

  addAll(Iterable iterable) {
    if (iterable == null || iterable.length == 0) {
      return;
    }

    final lastPosition = list.length;
    for (final element in iterable) {
      if (!list.contains(element)) {
        list.add(element);
      }
    }
    if (lastPosition != 0) {
      database.update(
        table,
        elementToMap(lastPosition - 1),
        where: primaryKey.toWhereString(),
        whereArgs: [list[lastPosition - 1]],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (int index = lastPosition; index < list.length; index++) {
      database.insert(
        table,
        elementToMap(index),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    notifyListeners();
  }

  insert(int index, T element) {
    list.insert(index, element);
    if (index != 0) {
      database.update(
        table,
        elementToMap(index - 1),
        where: primaryKey.toWhereString(),
        whereArgs: [list[index - 1]],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (index != list.length - 1) {
      database.update(
        table,
        elementToMap(index + 1),
        where: primaryKey.toWhereString(),
        whereArgs: [list[index + 1]],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    database.insert(
      table,
      elementToMap(index),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  insertAll(Iterable iterable) {
    if (iterable == null || iterable.length == 0) {
      return;
    }

    int _length = 0;
    for (final element in iterable) {
      if (!list.contains(element)) {
        list.insert(0, element);
        _length++;
      }
    }

    for (int index = 0; index < _length; index++) {
      database.insert(
        table,
        elementToMap(index),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (list.length > _length) {
        database.update(table, elementToMap(_length),
            where: primaryKey.toWhereString(), whereArgs: [list[_length]]);
      }
    }
    notifyListeners();
  }

  T removeAt(int index) {
    database.delete(
      table,
      where: primaryKey.toWhereString(),
      whereArgs: [list[index]],
    );
    final res = list.removeAt(index);
    if (index > 0) {
      database.update(
        table,
        elementToMap(index - 1),
        where: primaryKey.toWhereString(),
        whereArgs: [list[index - 1]],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (index < length - 1) {
      database.update(
        table,
        elementToMap(index),
        where: primaryKey.toWhereString(),
        whereArgs: [list[index]],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    notifyListeners();
    return res;
  }

  indexOf(T element) => list.indexOf(element);

  reorder(int oldIndex, int newIndex) async {
    final set = Set<int>();
    set.add(oldIndex - 1);
    set.add(oldIndex);
    set.add(newIndex - 1);
    set.add(newIndex);
    set.add(newIndex + 1);

    (oldIndex < newIndex)
        ? list.insert(newIndex - 1, list.removeAt(oldIndex))
        : list.insert(newIndex, list.removeAt(oldIndex));
    _updateDatabase(set);
    notifyListeners();
  }

  sync(
    Iterable iterable, {
    bool shouldAdd =
        true, //whether add the element that don't exist in the list, if false, just delete elements not add elements
    Function
        compareSubElement, // control what sub element in class should be compare
    Function shouldUpdate, // callback once detect distinct
    Function updated, // callback after detect distinct and sync finish
  }) {
    /// delete all [list] elements that [iterable] don't contains
    /// insert all [iterable] elements that [list] don't contains
    final copy = Set();
    bool diff = false;

    compareSubElement ??= (Object element) => element;

    for (final element in iterable) {
      copy.add(compareSubElement(element));
    }

    int Function(int index) compare;
    int Function(int index) rawCompare = (int index) {
      if (!copy.contains(list[index])) {
        removeAt(index);
      } else {
        copy.remove(list[index++]);
      }
      return index;
    };

    compare = (int index) {
      if (!copy.contains(list[index])) {
        removeAt(index);
        shouldUpdate ??= () {};
        shouldUpdate();
        diff = true;
        // update compare function so that shouldUpdate function would just call once.
        compare = rawCompare;
      } else {
        copy.remove(list[index++]);
      }
      return index;
    };

    for (int index = 0; index < length;) {
      index = compare(index);
    }

    if (shouldAdd && copy.length != 0) {
      insertAll(copy);
      diff = true;
    }

    if (diff && updated != null) {
      updated();
    }
  }

  _updateDatabase(Iterable<int> indexes) {
    final set = indexes.toSet().toList();
    set.retainWhere((int e) => e >= 0 && e < length);
    for (final index in set) {
      database.insert(
        table,
        elementToMap(index),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  @override
  // TODO: implement value
  List<T> get value => list;
}

class ImageTable {
  ImageTable(
      this.database, this.table, this.primaryKey, this.keys, this.imagePath);

  final Database database;
  final String table;
  final DatabaseKey primaryKey;
  final List<DatabaseKey> keys;
  final String imagePath; // The parent path

  static Future<ImageTable> easeTable({
    @required String database,
    @required String table,
    @required DatabaseKey primaryKey,
    @required List<DatabaseKey<String>> keys,
    bool drop = false,
  }) async {
    final res = ImageTable(await DatabaseHelper.easeDatabase(database), table,
        primaryKey, keys, path.join(await getDatabasesPath(), 'images'));
    if (!await Directory(res.imagePath).exists())
      Directory(res.imagePath).create();

    await Future.wait(
        [Directory(res.imagePath).createTemp(), res.bindTable(drop: drop)]);
    return res;
  }

  String generateStructure() {
    String res = "(";
    res += primaryKey.toPrimaryString();
    for (final key in keys) {
      res += key.toString();
    }
    return res + ")";
  }

  Future bindTable({bool drop = false}) async {
    /// [drop] whether drop the table exists
    if (drop) {
      await database.execute("drop table if exists $table");
    }
    await database
        .execute("CREATE TABLE IF NOT EXISTS $table" + generateStructure());
  }

  dropTable() async {
    Stream list = Directory(imagePath).list();
    await for (final item in list) {
      await item.delete();
    }

    await database.execute("drop table if exists $table");
    await database
        .execute("CREATE TABLE IF NOT EXISTS $table" + generateStructure());
  }

  static const String fileFormat = '.jpg';

  Future<Map> setData(Map data) async {
    assert(data.containsKey(primaryKey.keyName));
    Map<String, String> _data = Map();
    _data[primaryKey.keyName] = data[primaryKey.keyName];
    for (final key in keys) {
      /// store image path
      String subName = _data[primaryKey.keyName].split('/').last;
      subName = subName.split('.').first + '-';
      _data[key.keyName] =
          path.join(imagePath, subName + key.keyName + fileFormat);

      /// store image as file (database can't store large image)
      await saveFile(
          filePath: _data[key.keyName], bytes: data[key.keyName]);
    }
    await database.insert(table, _data,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return _data;
  }

  @protected
  saveFile({final String filePath, final Uint8List bytes})async{
    assert(false);
  }

  Future<Map> getRawData(primaryKeyValue) async {
    // get just filePath without image data
    List<Map> _maps = await database.query(table,
        where: primaryKey.toWhereString(),
        whereArgs: [primaryKeyValue],
        limit: 1);
    return _maps.isNotEmpty ? _maps[0] : null;
  }

  Future<Map> convertToData(Map raw) async {
    Map map = Map();
    map[primaryKey.keyName] = primaryKey.dataDecode(raw[primaryKey.keyName]);
    for (final key in keys) {
      final file = File(raw[key.keyName]);
      if (!await file.exists()) {
        await database.delete(
          table,
          where: primaryKey.toWhereString(),
          whereArgs: [map[primaryKey.keyName]],
        );
        return null;
      }
      map[key.keyName] = await readFile(filePath: file.path);
    }
    return map;
  }

  @protected
  Future<Uint8List>readFile({final String filePath})async{
    assert(false);
    return null;
  }

  Future<Map> getData(primaryKeyValue) async {
    Map _map = await getRawData(primaryKeyValue);
    if (_map == null) return null;
    Map map = await convertToData(_map);
    return map;
  }

  removeData({primaryKeyValue}) async {
    List<Map> _maps = await database.query(table,
        where: primaryKey.toWhereString(),
        whereArgs: [primaryKeyValue],
        limit: 1);
    for (final key in keys) {
      final file = File(_maps[0][key.keyName]);
      file.delete();
    }
    await database.delete(
      table,
      where: primaryKey.toWhereString(),
      whereArgs: [primaryKeyValue],
    );
  }

  Future<int> getSize() async {
    int len = 0;
    Stream list = Directory(imagePath).list();
    await for (final FileSystemEntity file in list) {
      if (await FileSystemEntity.isFile(file.path))
        len += await File(file.path).length();
    }
    return len;
  }
}

class Table {
  Table(this.database, this.table, this.primaryKey, this.keys);

  final Database database;
  final String table;
  final DatabaseKey primaryKey;
  final List<DatabaseKey> keys;

  static Future<Table> easeTable({
    @required String database,
    @required String table,
    @required DatabaseKey primaryKey,
    @required List<DatabaseKey> keys,
    bool drop = false,
  }) async {
    final res = Table(
        await DatabaseHelper.easeDatabase(database), table, primaryKey, keys);
    await res.bindTable(drop: drop);
    return res;
  }

  String generateStructure() {
    String res = "(";
    res += primaryKey.toPrimaryString();
    for (final key in keys) {
      res += key.toString();
    }
    return res + ")";
  }

  bindTable({bool drop = false}) async {
    /// [drop] whether drop the table exists
    if (drop) {
      await database.execute("drop table if exists $table");
    }
    await database
        .execute("CREATE TABLE IF NOT EXISTS $table" + generateStructure());
  }

  dropTable() async {
    await database.execute("drop table if exists $table");
    await database
        .execute("CREATE TABLE IF NOT EXISTS $table" + generateStructure());
  }

  setData(Map data) async {
    assert(data.containsKey(primaryKey.keyName));
    Map<String, dynamic> _data = Map();
    _data[primaryKey.keyName] = primaryKey.dataEncode(data[primaryKey.keyName]);
    for (final key in keys) {
      _data[key.keyName] = key.dataEncode(data[key.keyName]);
    }
    await database.insert(table, _data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map> getData(primaryKeyValue) async {
    List<Map> _maps = await database.query(table,
        where: primaryKey.toWhereString(),
        whereArgs: [primaryKey.dataEncode(primaryKeyValue)],
        limit: 1);
    if (_maps.isEmpty) {
      return null;
    }
    Map map = Map();
    map[primaryKey.keyName] =
        primaryKey.dataDecode(_maps[0][primaryKey.keyName]);
    for (final key in keys) {
      map[key.keyName] = key.dataDecode(_maps[0][key.keyName]);
    }
    return map;
  }

  removeData({Map data, primaryKeyValue}) async {
    if (data != null) {
      await database.delete(
        table,
        where: primaryKey.toWhereString(),
        whereArgs: [primaryKey.dataEncode(data[primaryKey.keyName])],
      );
    } else if (primaryKeyValue != null) {
      await database.delete(
        table,
        where: primaryKey.toWhereString(),
        whereArgs: [primaryKey.dataEncode(primaryKeyValue)],
      );
    }
  }

  Future<int> getSize() async {
    return File(database.path).length();
  }
}

class SQLiteLinkedList<T> {
  SQLiteLinkedList(this.database);

  final Database database;
  String tableName;
  Map<T, List<T>> primaryKeyMap;
  List<T> list;
  T first;
  T last;

  final DatabaseKey primaryKey = DatabaseKey<T>(keyName: 'filePath');
  final DatabaseKey previousKey = DatabaseKey<T>(keyName: 'previous');
  final DatabaseKey nextKey = DatabaseKey<T>(keyName: 'next');

  static String generateStructure(List<DatabaseKey> keys) {
    String res = "(";
    res += keys[0].toPrimaryString();
    res += keys[1].toString();
    res += keys[2].toString();
    return res + ")";
  }

  static const previousIndex = 0;
  static const nextIndex = 1;

  static Future<SQLiteLinkedList<T>> easeLinkedList<T>({
    @required String database,
    @required String table,
    bool drop = false,
  }) async {
    final res =
        SQLiteLinkedList<T>(await DatabaseHelper.easeDatabase(database));
    await res.bindTable(table, drop: drop);
    return res;
  }

  Map<String, T> itemToMap(T key, List<T> value) {
    final map = Map<String, T>();
    map[primaryKey.keyName] = key;
    map[previousKey.keyName] = value[previousIndex];
    map[nextKey.keyName] = value[nextIndex];
    return map;
  }

  bindTable(String tableName, {bool drop = false}) async {
    this.tableName = tableName;

    /// [drop] whether drop the table exists
    if (drop) {
      await database.execute("drop table if exists $tableName");
    }
    await database.execute("CREATE TABLE IF NOT EXISTS $tableName" +
        generateStructure([primaryKey, previousKey, nextKey]));
    _initializeMap(await database.query('$tableName'));
    _initializeList();
  }

  /// initialize [primaryKeyMap] from [maps]
  /// call after query [maps] from database
  void _initializeMap(List<Map<String, dynamic>> maps) {
    primaryKeyMap = Map<T, List<T>>();
    if (maps == null || maps.length == 0) {
      return;
    }
    for (final map in maps) {
      primaryKeyMap[map[primaryKey.keyName]] = [
        map[previousKey.keyName],
        map[nextKey.keyName]
      ];
      if (map[previousKey.keyName] == null) {
        first = map[primaryKey.keyName];
      }
      if (map[nextKey.keyName] == null) {
        last = map[primaryKey.keyName];
      }
    }
    assert(first != null && last != null);
    return;
  }

  /// initialize [list] from [primaryKeyMap]
  /// call after [_initializeMap] return
  void _initializeList() {
    assert(primaryKeyMap != null);
    list = List();
    T index = first;
    while (index != null) {
      list.add(index);
      index = primaryKeyMap[index][nextIndex];
    }
  }

  add(T value) async {
    if (primaryKeyMap.containsKey(value)) {
      /// linked list don't contains two same values
      /// any value must be unique
      return;
    } else if (list.length == 0) {
      list.add(value);
      primaryKeyMap[value] = <T>[null, null];
      last = first = value;
      await database.insert(
        tableName,
        itemToMap(last, primaryKeyMap[last]),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }
    list.add(value);
    primaryKeyMap[last][nextIndex] = value;
    primaryKeyMap[value] = [last, null];
    final secondLast = last;
    last = value;
    await Future.wait([
      database.insert(
        tableName,
        itemToMap(secondLast, primaryKeyMap[secondLast]),
        conflictAlgorithm: ConflictAlgorithm.replace,
      ),
      database.insert(
        tableName,
        itemToMap(last, primaryKeyMap[last]),
        conflictAlgorithm: ConflictAlgorithm.replace,
      ),
    ]);
  }

  addAll(Iterable iterable) async {
    for (final item in iterable) {
      await add(item);
    }
  }

  sync(Iterable iterable) async {
    List copy = List.from(iterable);
    for (int i = 0; i < list.length;) {
      copy.contains(list[i]) ? copy.removeAt(i++) : await removeAt(i);
    }
    await addAll(copy);
  }

  insert(int index, T value) async {
    if (primaryKeyMap.containsKey(value)) {
      /// linked list don't contains two same values
      /// any value must be unique
      return;
    }

    Future future;

    if (index == 0) {
      primaryKeyMap[first][previousIndex] = value;
      primaryKeyMap[value] = [null, first];
      final secondFirst = first;
      first = value;
      future = Future.wait([
        database.insert(
          tableName,
          itemToMap(secondFirst, primaryKeyMap[secondFirst]),
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
        database.insert(
          tableName,
          itemToMap(first, primaryKeyMap[first]),
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ]);
    } else if (index == list.length) {
      primaryKeyMap[last][nextIndex] = value;
      primaryKeyMap[value] = [last, null];
      final secondLast = last;
      last = value;
      future = Future.wait([
        database.insert(
          tableName,
          itemToMap(secondLast, primaryKeyMap[secondLast]),
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
        database.insert(
          tableName,
          itemToMap(last, primaryKeyMap[last]),
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
      ]);
    } else {
      primaryKeyMap[list[index - 1]][nextIndex] = value;
      primaryKeyMap[list[index]][previousIndex] = value;
      primaryKeyMap[value] = [list[index - 1], list[index]];
      future = Future.wait([
        database.insert(
          tableName,
          itemToMap(value, primaryKeyMap[value]),
          conflictAlgorithm: ConflictAlgorithm.replace,
        ),
        database.update(
          tableName,
          itemToMap(list[index - 1], primaryKeyMap[list[index - 1]]),
          where: primaryKey.toWhereString(),
          whereArgs: [list[index - 1]],
        ),
        database.update(
          tableName,
          itemToMap(list[index], primaryKeyMap[list[index]]),
          where: primaryKey.toWhereString(),
          whereArgs: [list[index]],
        ),
      ]);
    }
    list.insert(index, value);
    await future;
  }

  dynamic removeAt(int index) async {
    Future future;
    T res;
    if (list.length == 1) {
      primaryKeyMap.remove(first);
      res = list.removeAt(index);
      future = database.delete(tableName,
          where: primaryKey.toWhereString(), whereArgs: [first]);
      first = last = null;
    } else if (index == 0) {
      primaryKeyMap[list[index + 1]][previousIndex] = null;
      future = Future.wait([
        database.delete(
          tableName,
          where: primaryKey.toWhereString(),
          whereArgs: [first],
        ),
        database.update(
          tableName,
          itemToMap(list[index + 1], primaryKeyMap[list[index + 1]]),
          where: primaryKey.toWhereString(),
          whereArgs: [list[index + 1]],
        )
      ]);
      primaryKeyMap.remove(first);
      res = list.removeAt(index);
      first = list[index + 1];
    } else if (index == list.length - 1) {
      primaryKeyMap[list[index - 1]][nextIndex] = null;
      future = Future.wait([
        database.delete(
          tableName,
          where: primaryKey.toWhereString(),
          whereArgs: [last],
        ),
        database.update(
          tableName,
          itemToMap(list[index - 1], primaryKeyMap[list[index - 1]]),
          where: primaryKey.toWhereString(),
          whereArgs: [list[index - 1]],
        )
      ]);
      primaryKeyMap.remove(last);
      res = list.removeAt(index);
      last = list[index - 1];
    } else {
      primaryKeyMap[list[index - 1]][nextIndex] = list[index + 1];
      primaryKeyMap[list[index + 1]][previousIndex] = list[index - 1];
      future = Future.wait([
        database.delete(
          tableName,
          where: primaryKey.toWhereString(),
          whereArgs: [list[index]],
        ),
        database.update(
          tableName,
          itemToMap(list[index - 1], primaryKeyMap[list[index - 1]]),
          where: primaryKey.toWhereString(),
          whereArgs: [list[index - 1]],
        ),
        database.update(
          tableName,
          itemToMap(list[index + 1], primaryKeyMap[list[index + 1]]),
          where: primaryKey.toWhereString(),
          whereArgs: [list[index + 1]],
        ),
      ]);
      primaryKeyMap.remove(list[index]);
      res = list.removeAt(index);
    }
    await future;
    return res;
  }

  reorder(int oldIndex, int newIndex) async {
    assert(oldIndex < list.length && newIndex < list.length);
    if (oldIndex == newIndex) {
      return;
    }
    if (oldIndex < newIndex) {
      await insert(newIndex - 1, await removeAt(oldIndex));
    } else {
      await insert(newIndex, await removeAt(oldIndex));
    }
  }
}
