import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'CustomList.dart';

class DatabaseHelper {
  static Database database;

  static Future<Database> easeDatabase(String name) async =>
      openDatabase(path.join(await getDatabasesPath(), '$name.db'));

  static String generateStructure(List<DatabaseKey> structure) {
    String res = "(";
    res += structure.first.toPrimaryString();
    for (final key in structure.sublist(1)) {
      res += key.toString();
    }
    return res + ")";
  }
}

class DatabaseKey<T> {
  const DatabaseKey({@required this.keyName, this.unique = false});

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

  final bool unique;

  String toPrimaryString() {
    final res =
        keyName + ' ' + typeMap[this.runtimeType] + ' PRIMARY KEY NOT NULL';
    return unique ? res + ' UNIQUE ' : res;
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

  final DatabaseKey primaryKey = DatabaseKey<T>(keyName: 'id');
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
  }) {
    /// this function don't bind table, need to call [bindTable] manual
    return LinkedList<T>(
        databaseAsync: DatabaseHelper.easeDatabase(database), table: table);
  }

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

final nullFuture = Future.delayed(Duration.zero);

mixin DataBaseExtendList<T> on BaseList<T> {
  Database get database => _database;
  @protected
  Database _database;

  String get table => _table;
  @protected
  String _table;

  List<DatabaseKey> get structure;

  DatabaseKey get primaryKey => structure.first;

  /// just database name without .db
  /// table name
  /// the database table data structure
  @protected
  Future bind(
      {@required final String database, @required final String table}) async {
    _database = await DatabaseHelper.easeDatabase(database);
    _table = table;
    await this.database.execute("CREATE TABLE IF NOT EXISTS $table" +
        DatabaseHelper.generateStructure(structure));
    innerList = await recoverToList();
  }

  Future dropTable() {
    return database.execute('drop table if exists $table');
  }

  @protected
  Future<List<Map>> get maps async => await database.query('$table');

  @protected
  Future<List> recoverToList();

  @protected
  Map<String, T> elementToMap({int index, T element});

  @protected
  Future batchDatabaseUpdate(Set<int> indexes) {
    return Future.wait([
      for (final int index in indexes)
        if (index >= 0 && index < length)
          database.insert(
            table,
            elementToMap(index: index),
            conflictAlgorithm: ConflictAlgorithm.replace,
          )
        else
          nullFuture,
    ]);
  }

  @protected
  Future batchDatabaseDelete(Set<int> indexes) {
    return Future.wait([
      for (final int index in indexes)
        if (index >= 0 && index < length)
          database.delete(
            table,
            where: primaryKey.toWhereString(),
            whereArgs: [this[index]],
          )
        else
          nullFuture,
    ]);
  }

  @protected
  Future refreshAll() async {
    await database.delete(table);
    await Future.wait([
      for (int i = 0; i < length; i++)
        database.delete(
          table,
          where: primaryKey.toWhereString(),
          whereArgs: [this[i]],
        )
    ]);
  }

  @override
  bool remove(Object element) {
    // TODO: implement remove
    database.delete(
      table,
      where: primaryKey.toWhereString(),
      whereArgs: [element],
    );
    return super.remove(element);
  }

  @override
  T removeAt(int index) {
    // TODO: implement removeAt
    database.delete(
      table,
      where: primaryKey.toWhereString(),
      whereArgs: [this[index]],
    );
    return super.removeAt(index);
  }

  @override
  T removeLast() {
    // TODO: implement removeLast
    database.delete(
      table,
      where: primaryKey.toWhereString(),
      whereArgs: [this.last],
    );
    return super.removeLast();
  }

  @override
  void removeRange(int start, int end) {
    // TODO: implement removeRange
    final Set<int> _set = List.generate(end - start, (int value) {
      return value + start;
    }).toSet();
    batchDatabaseDelete(_set);
    super.removeRange(start, end);
  }

  @override
  void removeWhere(bool Function(T element) test) {
    // TODO: implement removeWhere
    Set<int> _set = Set();
    for (int i = 0; i < length; i++) if (test(this[i])) _set.add(i);
    batchDatabaseDelete(_set);
    super.removeWhere(test);
  }

  @override
  void add(element) {
    // TODO: implement add
    super.add(element);
    database.insert(table, elementToMap(element: element),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  void addAll(Iterable<T> iterable) {
    // TODO: implement addAll
    final int start = length;
    super.addAll(iterable);
    final int end = length;
    final Set<int> _set = List.generate(end - start, (int value) {
      return value + start;
    }).toSet();
    batchDatabaseUpdate(_set);
  }

  @override
  void insert(int index, T element) {
    // TODO: implement insert
    super.insert(index, element);
    database.insert(table, elementToMap(element: element),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  void insertAll(int index, Iterable<T> iterable) {
    // TODO: implement insertAll
    super.insertAll(index, iterable);
    for (final element in iterable)
      database.insert(table, elementToMap(element: element),
          conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  void retainWhere(bool Function(T element) test) {
    // TODO: implement retainWhere
    super.retainWhere(test);
    refreshAll();
  }

  @override
  void replaceRange(int start, int end, Iterable<T> newContents) {
    // TODO: implement replaceRange
    super.replaceRange(start, end, newContents);
    final Set<int> _set = List.generate(end - start, (int value) {
      return value + start;
    }).toSet();
    batchDatabaseUpdate(_set);
  }

  @override
  void sort([int Function(T a, T b) compare]) {
    // TODO: implement sort
    super.sort(compare);
    refreshAll();
  }

  @override
  void setAll(int index, Iterable<T> iterable) {
    // TODO: implement setAll
    super.setAll(index, iterable);
    final Set<int> _set = List.generate(iterable.length, (int value) {
      return value + index;
    }).toSet();
    batchDatabaseUpdate(_set);
  }

  @override
  void setRange(int start, int end, Iterable<T> iterable, [int skipCount = 0]) {
    // TODO: implement setRange
    super.setRange(start, end, iterable, skipCount);
    final Set<int> _set =
        List.generate(min(iterable.length, end - start), (int value) {
      return value + start;
    }).toSet();
    batchDatabaseUpdate(_set);
  }

  @override
  void fillRange(int start, int end, [fill]) {
    // TODO: implement fillRange
    super.fillRange(start, end, fill);
    final Set<int> _set = List.generate(end - start, (int value) {
      return value + start;
    }).toSet();
    batchDatabaseUpdate(_set);
  }

  @override
  void shuffle([Random random]) {
    super.shuffle(random);
    refreshAll();
  }

  @override
  void clear() {
    // TODO: implement clear
    super.clear();
    refreshAll();
  }
}

mixin DataBaseExtendLinkedList<T> on DataBaseExtendList<T> {
  final DatabaseKey primaryKey = DatabaseKey<T>(keyName: 'id');
  final DatabaseKey previousKey = DatabaseKey<T>(keyName: 'previous');
  final DatabaseKey nextKey = DatabaseKey<T>(keyName: 'next');

  @override
  // TODO: implement structure
  List<DatabaseKey> structure;

  @override
  Future bind({@required final String database, @required final String table}) {
    // TODO: implement bind
    this.structure = [primaryKey, previousKey, nextKey];
    return super.bind(database: database, table: table);
  }

  @override
  Future<List> recoverToList() async {
    Iterable<Map> _maps = await maps;
    final Map<T, Map> _map = Map();
    T _first;
    T _last;
    for (final subMap in _maps) {
      if (subMap[previousKey.keyName] == null) {
        _first = subMap[primaryKey.keyName];
      } else if (subMap[nextKey.keyName] == null) {
        _last = subMap[primaryKey.keyName];
      }
      _map[subMap[primaryKey.keyName]] = {
        previousKey.keyName: subMap[previousKey.keyName],
        nextKey.keyName: subMap[nextKey.keyName]
      };
    }

    final List<T> _list = List();

    if (_map.isEmpty)
      return _list;
    else if (_first != null) {
      T _current = _first;
      for (int i = 0; i < _map.length && _current != null; i++) {
        _list.add(_current);
        if(!_map.containsKey(_current)) return _list;
        _current = _map[_current][nextKey.keyName];
      }
    } else if (_last != null) {
      T _current = _last;
      for (int i = 0; i < _map.length && _current != null; i++) {
        _list.insert(0, _current);
        if(!_map.containsKey(_current)) return _list;
        _current = _map[_current][previousKey.keyName];
      }
    } else {
      debugPrint('Database table data has broken. \nClear the data...\n');
      await database.execute("drop table if exists $table");
      await this.database.execute("CREATE TABLE IF NOT EXISTS $table " +
          DatabaseHelper.generateStructure(structure));
      debugPrint('Reconstructed the database table: $table');
    }

    return _list;
  }

  @override
  Map<String, T> elementToMap({int index, final T element}) {
    if (index == null) index = indexOf(element);
    return {
      primaryKey.keyName: this[index],
      previousKey.keyName: index > 0 ? this[index - 1] : null,
      nextKey.keyName: index < length - 1 ? this[index + 1] : null,
    };
  }

  @override
  bool remove(Object element) {
    // TODO: implement remove
    final index = indexOf(element);
    final res = super.remove(element);
    batchDatabaseUpdate({index - 1, index}); // linked the break point
    return res;
  }

  @override
  T removeAt(int index) {
    // TODO: implement removeAt
    final res = super.removeAt(index);
    batchDatabaseUpdate({index - 1, index}); // linked the break point
    return res;
  }

  @override
  T removeLast() {
    // TODO: implement removeLast
    final res = super.removeLast();
    if (isNotEmpty)
      database.insert(table, elementToMap(element: last),
          conflictAlgorithm: ConflictAlgorithm.replace); // clear the end
    return res;
  }

  @override
  void removeRange(int start, int end) {
    // TODO: implement removeRange
    super.removeRange(start, end);
    batchDatabaseUpdate({start - 1, start}); // linked the break point
  }

  @override
  void removeWhere(bool Function(T element) test) {
    // TODO: implement removeWhere
    final Iterable<T> removed = takeWhile(test);
    if (removed.length == 0) {
      super.removeWhere(test);
      return;
    } else if (removed.length == 1) {
      final index = indexOf(removed.first);
      super.removeWhere(test);
      batchDatabaseUpdate({index - 1, index});
      return;
    }
    debugPrint(
        'Warning: [removeWhere] is not a effective function. It will refresh the entire database');
    super.removeWhere(test);
    refreshAll();
  }

  @override
  void add(element) {
    // TODO: implement add
    super.add(element);
    final index = indexOf(element) - 1;
    batchDatabaseUpdate({index});
  }

  @override
  void addAll(Iterable<T> iterable) {
    // TODO: implement addAll
    super.addAll(iterable);
    if(iterable.isNotEmpty) {
      final index = indexOf(iterable.first) - 1;
      batchDatabaseUpdate({index});
    }

  }

  @override
  void insert(int index, T element) {
    // TODO: implement insert
    super.insert(index, element);
    batchDatabaseUpdate({index - 1, index + 1});
  }

  @override
  void insertAll(int index, Iterable<T> iterable) {
    // TODO: implement insertAll
    super.insertAll(index, iterable);
    batchDatabaseUpdate({index - 1, index + iterable.length});
  }

  @override
  void replaceRange(int start, int end, Iterable<T> newContents) {
    // TODO: implement replaceRange
    super.replaceRange(start, end, newContents);
    batchDatabaseUpdate({start - 1, end});
  }

  @override
  void setRange(int start, int end, Iterable<T> iterable, [int skipCount = 0]) {
    // TODO: implement setRange
    super.setRange(start, end, iterable, skipCount);
    batchDatabaseUpdate({start - 1, end});
  }

  @override
  void setAll(int index, Iterable<T> iterable) {
    // TODO: implement setAll
    super.setAll(index, iterable);

    batchDatabaseUpdate(
        {index - 1, index + iterable.length, index + iterable.length + 1});
  }

  @override
  void fillRange(int start, int end, [fill]) {
    // TODO: implement fillRange
    super.fillRange(start, end, fill);
    batchDatabaseUpdate({start - 1, end});
  }
}

mixin DatabaseListDebug<T> on DataBaseExtendList<T> {
  @override
  Future bind(
      {@required final String database,
      @required final String table,
      final List<DatabaseKey> structure}) async {
    // TODO: implement bind
    await (await DatabaseHelper.easeDatabase(database))
        .execute('drop table if exists $table');
    return super.bind(database: database, table: table);
  }

  @override
  Future batchDatabaseUpdate(Set<int> indexes) async {
    // TODO: implement batchDatabaseUpdate
    await super.batchDatabaseUpdate(indexes);
    debugPrint();
  }

  @override
  Future batchDatabaseDelete(Set<int> indexes) async {
    // TODO: implement batchDatabaseDelete
    await super.batchDatabaseDelete(indexes);
    debugPrint();
  }

  void debugPrint() async {
    final list = await maps;
    print('${runtimeType.toString()}');
    print('->Database side');
    print(list);
    print('->own side');
    print(innerList);
  }
}
