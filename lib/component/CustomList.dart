import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

typedef VoidCallback = void Function();

class BaseList<T> extends ListBase<T> {
  BaseList([int length]) : innerList = length == null ? List() : List(length);

  @protected
  List<T> innerList;

  @override
  int get length => innerList.length;

  @override
  set length(int newLength) {
    innerList.length = newLength;
  }

  @override
  T operator [](int index) {
    return innerList[index];
  }

  @override
  void operator []=(int index, T value) {
    if (innerList[index] != value) {
      innerList[index] = value;
    }
  }
}

mixin Reorderable<T> on ListBase<T> {

  /// AtomOperation for [ListNotify]
  void reorder(int oldIndex, int newIndex) {
    _rawReorder(int oldIndex, int newIndex) {
      (oldIndex < newIndex)
          ? insert(newIndex - 1, removeAt(oldIndex))
          : insert(newIndex, removeAt(oldIndex));
    }

    _notifyReorder(int oldIndex, int newIndex) {
      final clone = this as ListNotify;
      clone.notifyCritical = true;
      (oldIndex < newIndex)
          ? insert(newIndex - 1, removeAt(oldIndex))
          : insert(newIndex, removeAt(oldIndex));
      clone.notifyCritical = false;
      clone.notifyListeners();
    }

    if (this is ListNotify) return _notifyReorder(oldIndex, newIndex);
    else return _rawReorder(oldIndex, newIndex);
  }
}

mixin BaseListDebug<T> on BaseList<T> {
  @override
  set innerList(List _innerList) {
    // TODO: implement innerList
    debugPrint('${this.runtimeType}: innerList');
    super.innerList = _innerList;
  }

  @override
  void add(element) {
    // TODO: implement add
    debugPrint('${this.runtimeType}: add');
    super.add(element);
  }

  @override
  void addAll(Iterable iterable) {
    // TODO: implement addAll
    debugPrint('${this.runtimeType}: addAll');
    super.addAll(iterable);
  }

  @override
  void insert(int index, element) {
    // TODO: implement insert
    debugPrint('${this.runtimeType}: insert');
    super.insert(index, element);
  }

  @override
  void insertAll(int index, Iterable iterable) {
    // TODO: implement insertAll
    debugPrint('${this.runtimeType}: insertAll');
    super.insertAll(index, iterable);
  }

  @override
  bool remove(Object element) {
    // TODO: implement remove
    debugPrint('${this.runtimeType}: remove');
    return super.remove(element);
  }

  @override
  removeAt(int index) {
    // TODO: implement removeAt
    debugPrint('${this.runtimeType}: removeAt');
    return super.removeAt(index);
  }

  @override
  removeLast() {
    // TODO: implement removeLast
    debugPrint('${this.runtimeType}: removeLast');
    return super.removeLast();
  }

  @override
  void removeRange(int start, int end) {
    // TODO: implement removeRange
    debugPrint('${this.runtimeType}: removeRange');
    super.removeRange(start, end);
  }

  @override
  void replaceRange(int start, int end, Iterable newContents) {
    // TODO: implement replaceRange
    debugPrint('${this.runtimeType}: replaceRange');
    super.replaceRange(start, end, newContents);
  }
}

class GeneralEnhancedList<T> extends BaseList<T> with Reorderable<T> {
  GeneralEnhancedList([int length]) : super(length);
}

mixin ListNotify<T> on BaseList<T>
    implements ChangeNotifier, ValueListenable<List<T>> {
  ObserverList<VoidCallback> _listeners = ObserverList<VoidCallback>();

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_listeners == null) {
        throw FlutterError('A $runtimeType was used after being disposed.\n'
            'Once you have called dispose() on a $runtimeType, it can no longer be used.');
      }
      return true;
    }());
    return true;
  }

  @override
  set innerList(List<T> list) {
    super.innerList = list;
    notifyListeners();
  }

  @override
  void operator []=(int index, value) {
    // TODO: implement []=
    final current = super[index];
    super[index] = value;

    if (current != value) notifyListeners();
  }

  @override
  @protected
  bool get hasListeners {
    assert(_debugAssertNotDisposed());
    return _listeners.isNotEmpty;
  }

  @override
  void addListener(VoidCallback listener) {
    assert(_debugAssertNotDisposed());
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    assert(_debugAssertNotDisposed());
    _listeners?.remove(listener);
  }

  @override
  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    _listeners = null;
  }

  bool get disposed {
    return _listeners == null;
  }

  /// if [notifyCritical] is [true],  notifyListeners will be disabled,
  /// otherwise notifyListeners will be enabled.
  @protected
  bool notifyCritical = false;

  @override
  @protected
  @visibleForTesting
  void notifyListeners() {
    if (notifyCritical) return;
    assert(_debugAssertNotDisposed());
    if (_listeners != null) {
      final List<VoidCallback> localListeners =
          List<VoidCallback>.from(_listeners);
      for (VoidCallback listener in localListeners) {
        try {
          if (_listeners.contains(listener)) listener();
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'foundation library',
            context: ErrorDescription(
                'while dispatching notifications for $runtimeType'),
            informationCollector: () sync* {
              yield DiagnosticsProperty<ChangeNotifier>(
                'The $runtimeType sending notification was',
                this,
                style: DiagnosticsTreeStyle.errorProperty,
              );
            },
          ));
        }
      }
    }
  }

  @override
  void sort([int compare(T a, T b)]) {
    super.sort(compare);
    notifyListeners();
  }

  @override
  void clear() {
    super.clear();
    notifyListeners();
  }

  @override
  void replaceRange(int start, int end, Iterable<T> newContents) {
    super.replaceRange(start, end, newContents);
    notifyListeners();
  }

  @override
  void shuffle([Random random]) {
    super.shuffle(random);
    notifyListeners();
  }

  @override
  void add(T element) {
    super.add(element);
    notifyListeners();
  }

  @override
  T removeLast() {
    final res = super.removeLast();
    notifyListeners();
    return res;
  }

  @override
  void fillRange(int start, int end, [T fill]) {
    super.fillRange(start, end, fill);
    notifyListeners();
  }

  @override
  void removeRange(int start, int end) {
    super.removeRange(start, end);
    notifyListeners();
  }

  @override
  void removeWhere(bool test(T element)) {
    super.removeWhere(test);
    notifyListeners();
  }

  @override
  Iterable<T> followedBy(Iterable<T> other) {
    final res = super.followedBy(other);
    notifyListeners();
    return res;
  }

  @override
  void addAll(Iterable<T> iterable) {
    super.addAll(iterable);
    notifyListeners();
  }

  @override
  T reduce(T combine(T previousValue, T element)) {
    final res = super.reduce(combine);
    notifyListeners();
    return res;
  }

  @override
  void insertAll(int index, Iterable<T> iterable) {
    super.insertAll(index, iterable);
    notifyListeners();
  }

  @override
  void setRange(int start, int end, Iterable<T> iterable, [int skipCount = 0]) {
    super.setRange(start, end, iterable, skipCount);
    notifyListeners();
  }

  @override
  void retainWhere(bool test(T element)) {
    super.retainWhere(test);
    notifyListeners();
  }

  @override
  void setAll(int index, Iterable<T> iterable) {
    super.setAll(index, iterable);
    notifyListeners();
  }

  @override
  void insert(int index, T element) {
    super.insert(index, element);
    notifyListeners();
  }

  @override
  T removeAt(int index) {
    final res = super.removeAt(index);
    notifyListeners();
    return res;
  }

  @override
  bool remove(Object element) {
    final res = super.remove(element);
    notifyListeners();
    return res;
  }

  @override
  List<T> get value => this;
}

mixin Updatable<T> on ListBase<T> {
  // The elements that was add lately
  Iterable<T> newCollection;

  // The elements that was disposed lately
  Iterable<T> disposedCollection;

  /// When [newCollection] and [disposedCollection] become useless,
  /// call [ void gc()] to release resource.
  @mustCallSuper
  void gc() {
    newCollection = null;
    disposedCollection = null;
  }

  /// If something disposed or added, return [true];
  @mustCallSuper
  bool sync(Iterable<T> iterable,
      {final bool addNewElement = true, final bool disposeOldElement = true}) {
    final _newCollection = List<T>();
    final _disposedCollection = List<T>.from(this);
    for (final T element in iterable) {
      if (!this.contains(element))
        _newCollection.add(element);
      else
        _disposedCollection.remove(element);

      /// drop that all ready exist from [disposedCollection]
      /// and keep that don't exist in the new iterable
    }
    newCollection = addNewElement ? _newCollection : const [];
    disposedCollection = disposeOldElement ? _disposedCollection : const [];
    final updated = newCollection.isNotEmpty || disposedCollection.isNotEmpty;
    super.removeWhere((T element) => _disposedCollection.contains(element));
    super.addAll(_newCollection);

    return updated;
  }

  @override
  bool remove(Object element) {
    // TODO: implement remove
    newCollection = null;
    (contains(element))
        ? disposedCollection = [element]
        : disposedCollection = [];
    return super.remove(element);
  }

  @override
  T removeAt(int index) {
    // TODO: implement removeAt
    assert(index < this.length, 'access overflow');
    newCollection = null;
    disposedCollection = [this[index]];
    return super.removeAt(index);
  }

  @override
  T removeLast() {
    // TODO: implement removeLast
    assert(this.isNotEmpty, 'access overflow, there is no element');
    newCollection = null;
    disposedCollection = [last];
    return super.removeLast();
  }

  @override
  void removeRange(int start, int end) {
    // TODO: implement removeRange
    newCollection = null;
    disposedCollection = this.sublist(start, end);
    super.removeRange(start, end);
  }

  @override
  void removeWhere(bool Function(T element) test) {
    // TODO: implement removeWhere
    newCollection = null;
    disposedCollection = this.takeWhile(test);
    super.removeWhere(test);
  }

  @override
  void add(element) {
    // TODO: implement add
    newCollection = [element];
    disposedCollection = null;
    super.add(element);
  }

  @override
  void addAll(Iterable<T> iterable) {
    // TODO: implement addAll
    newCollection = iterable;
    disposedCollection = null;
    super.addAll(iterable);
  }

  @override
  void insert(int index, T element) {
    // TODO: implement insert
    newCollection = [element];
    disposedCollection = null;
    super.insert(index, element);
  }

  @override
  void insertAll(int index, Iterable<T> iterable) {
    // TODO: implement insertAll
    newCollection = iterable;
    disposedCollection = null;
    super.insertAll(index, iterable);
  }

  @override
  void clear() {
    // TODO: implement clear
    disposedCollection = List<T>.from(this);
    newCollection = null;
    super.clear();
  }

  @override
  void setAll(int index, Iterable<T> iterable) {
    // TODO: implement setAll
    newCollection = iterable;
    disposedCollection = List.generate(index + iterable.length, (int i) {
      return this[i + index];
    });
    super.setAll(index, iterable);
  }

  @override
  void setRange(int start, int end, Iterable<T> iterable, [int skipCount = 0]) {
    // TODO: implement setRange
    newCollection = iterable;
    disposedCollection = List.generate(end - start, (int index) {
      return this[start + index];
    });
    super.setRange(start, end, iterable, skipCount);
  }

  @override
  void replaceRange(int start, int end, Iterable<T> newContents) {
    // TODO: implement replaceRange
    newCollection = newContents;
    disposedCollection = List.generate(end - start, (int index) {
      return this[start + index];
    });
    super.replaceRange(start, end, newContents);
  }

  @override
  void fillRange(int start, int end, [fill]) {
    // TODO: implement fillRange
    newCollection = List.generate(end - start, (int index) {
      return fill;
    });
    disposedCollection = List.generate(end - start, (int index) {
      return this[start + index];
    });
    super.fillRange(start, end, fill);
  }

  @override
  void retainWhere(bool Function(T element) test) {
    // TODO: implement retainWhere
    newCollection = null;
    disposedCollection = takeWhile(test);
    super.retainWhere(test);
  }

  @override
  void sort([int Function(T a, T b) compare]) {
    // TODO: implement sort
    gc();
    super.sort(compare);
  }

  @override
  void shuffle([Random random]) {
    // TODO: implement shuffle
    gc();
    super.shuffle(random);
  }
}

/// This is a toxic protect.
mixin UniqueList<T> on ListBase<T> {
  static const UniqueListWarning =
      'UniqueListWarning: element must be unique in this list';

//  @override
//  set length(int l) {
//    if (l > length) assert(false, UniqueListWarning);
//    length = l;
//  }

  @override
  void add(element) {
    // TODO: implement add
    assert(!contains(element), UniqueListWarning);
    super.add(element);
  }

  @override
  void addAll(Iterable<T> iterable) {
    // TODO: implement addAll
    assert(iterable.every((T element) {
      return !contains(element);
    }), UniqueListWarning);
    assert(iterable.toSet().length == iterable.length, UniqueListWarning);
    super.addAll(iterable);
  }

  @override
  void insert(int index, element) {
    // TODO: implement insert
    assert(!contains(element), UniqueListWarning);
    super.insert(index, element);
  }

  @override
  void insertAll(int index, Iterable<T> iterable) {
    // TODO: implement insertAll
    assert(iterable.every((T element) {
      return !contains(element);
    }), UniqueListWarning);
    assert(iterable.toSet().length == iterable.length, UniqueListWarning);
    super.insertAll(index, iterable);
  }

  @override
  void setAll(int index, Iterable<T> iterable) {
    // TODO: implement setAll
    assert(iterable.every((T element) {
      return !contains(element);
    }), UniqueListWarning);
    assert(iterable.toSet().length == iterable.length, UniqueListWarning);
    super.setAll(index, iterable);
  }

  @override
  void setRange(int start, int end, Iterable<T> iterable, [int skipCount = 0]) {
    // TODO: implement setRange
    assert(iterable.every((T element) {
      return !contains(element);
    }), UniqueListWarning);
    assert(iterable.toSet().length == iterable.length, UniqueListWarning);
    super.setRange(start, end, iterable, skipCount);
  }

  @override
  void fillRange(int start, int end, [fill]) {
    // TODO: implement fillRange
    assert(false, UniqueListWarning);
    super.fillRange(start, end, fill);
  }
}

abstract class PluginDataModel<T, E> extends BaseList<E>
    with Updatable<E>, ListNotify<E> {
  PluginDataModel({this.parent})
      : assert(isAdvancedList(parent),
            'This parent must with Updatable and ListNotify'),
        pluginData = Map() {
    fullConvert();
    (parent as ListNotify).addListener(listener);
  }

  static bool isAdvancedList(List list) {
    return list is Updatable && list is ListNotify;
  }

  Map<T, E> pluginData;

  E dataConvert(T source);

  void fullConvert() {
    for (int i = 0; i < parent.length; i++) {
      final E converted = dataConvert(parent[i]);
      super[i] = converted;
      pluginData[parent[i]] = converted;
    }
  }

  List<E> batchConvert(Iterable<T> iterable) {
    final _list = List<E>();
    for (final T item in iterable) {
      _list.add(dataConvert(item));
    }
    return _list;
  }

  final List<T> parent;

  @override
  void operator []=(int index, E value) {
    // TODO: implement []=
    assert(false, "PluginDataModel can't assign value");
  }

  @protected
  void listener() {
    final disposed = (parent as Updatable).disposedCollection;
    if (disposed != null) {
      final _disposedCollection = List<E>();
      for (final T element in disposed) {
        final E converted = pluginData.remove(element);
        innerList.remove(converted);
        _disposedCollection.add(converted);
      }
      disposedCollection = _disposedCollection;
    }

    final newc = (parent as Updatable).newCollection;
    if (newc != null) {
      final _newCollection = List<E>();
      for (final T element in newc) {
        final E converted = dataConvert(element);
        innerList.insert(parent.indexOf(element), converted);
        pluginData[element] = converted;
        _newCollection.add(converted);
      }
      newCollection = _newCollection;
    }

    notifyListeners();
  }

  @mustCallSuper
  @override
  void dispose() {
    // TODO: implement dispose
    (parent as ListNotify).removeListener(listener);
    super.dispose();
  }
}

enum SubscribeMode {
  addAndDisposeWhileSync,
  onlyDisposeWhileSync,
}

abstract class Subscribeable<E /*self type*/, T /*parent type*/ >
    extends BaseList<E> with Updatable, ListNotify {
  Subscribeable({this.subscribeMode = SubscribeMode.onlyDisposeWhileSync}) {
    switch (subscribeMode) {
      case SubscribeMode.addAndDisposeWhileSync:
        // TODO: Handle this case.
        subscribe = _addAndDisposeWhileSync;
        listener = _addAndDisposeWhileSyncListener;
        break;
      case SubscribeMode.onlyDisposeWhileSync:
        // TODO: Handle this case.
        subscribe = _onlyDisposeWhileSync;
        listener = _onlyDisposeWhileSyncListener;
        break;
    }
  }

  final SubscribeMode subscribeMode;

  @protected
  Subscribeable<T, dynamic> _parent;

  @protected
  Subscribeable<T, dynamic> get parent => _parent;

  /// If no parent, this is a master node.

  bool get hasParent {
    return parent != null;
  }

  @protected
  E convertTo(T p);

  @protected
  Map<T, E> dataMap = Map();

  Function(Subscribeable<T, dynamic> subscribeable) subscribe;

  _addAndDisposeWhileSync(Subscribeable<T, dynamic> subscribeable) {
    if (hasParent) unSubscribe();
    _parent = subscribeable;

    for (final T element in parent) dataMap[element] = convertTo(element);
    final newList = dataMap.values.takeWhile((final element) {
      return !contains(element);
    });
    retainWhere((final element) {
      return dataMap.containsValue(element);
    });
    if (newList.isNotEmpty) addAll(newList);

    _parent.addListener(listener);
  }

  _addAndDisposeWhileSyncListener() {
    final _newCollection = List<E>();
    final _disposedCollection = List<E>();
    if (parent.disposedCollection != null) {
      for (final T element in parent.disposedCollection) {
        dataMap.remove(element);
        final E data = convertTo(element);
        if (contains(data)) {
          innerList.remove(data);
          _disposedCollection.add(data);
        }
      }
    }
    if (parent.newCollection != null) {
      for (final T element in parent.newCollection) {
        dataMap[element] = convertTo(element);
        innerList.insert(0, dataMap[element]);
        _newCollection.add(dataMap[element]);
      }
    }
    newCollection = _newCollection;
    disposedCollection = _disposedCollection;
    notifyListeners();
  }

  _onlyDisposeWhileSync(Subscribeable<T, dynamic> subscribeable) {
    if (hasParent) unSubscribe();
    _parent = subscribeable;

    for (final T element in parent) dataMap[element] = convertTo(element);
    removeWhere((final element) {
      return !dataMap.values.contains(element);
    });

    _parent.addListener(listener);
  }

  _onlyDisposeWhileSyncListener() {
    final _newCollection = List<E>();
    final _disposedCollection = List<E>();
    if (parent.disposedCollection != null) {
      for (final T element in parent.disposedCollection) {
        dataMap.remove(element);
        final E data = convertTo(element);
        if (contains(data)) {
          innerList.remove(data);
          _disposedCollection.add(data);
        }
      }
    }
    newCollection = _newCollection;
    disposedCollection = _disposedCollection;
    notifyListeners();
  }

  unSubscribe() {
    _parent.removeListener(listener);
    _parent = null;
  }

  @protected
  Function() listener;

  @mustCallSuper
  @override
  void dispose() {
    // TODO: implement dispose
    unSubscribe();
    super.dispose();
  }
}

abstract class EfficientMapList<E /*self*/, T /*parent*/ > extends ListBase<E> {
  EfficientMapList({@required this.parent}) : assert(parent != null);

  final List<T> parent;

  E convertTo(T p);

  T convertFrom(E e);

  @override
  int get length => parent.length;

  @override
  set length(int newLength) {
    // TODO: implement length
    parent.length = newLength;
  }

  @override
  E operator [](int index) {
    // TODO: implement []
    return convertTo(parent[index]);
  }

  @override
  operator []=(int index, E value) {
    // TODO: implement []=
    parent[index] = convertFrom(value);
  }
}
