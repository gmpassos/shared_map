import 'dart:async';

import 'shared_map_base.dart';
import 'shared_map_cached.dart';
import 'shared_object.dart';
import 'shared_object_field.dart';
import 'shared_reference.dart';

/// NOT shared implementation of [SharedStore].
class NotSharedStore implements SharedStore {
  static int _notSharedIDCount = 0;

  @override
  final String id;

  final NotSharedMap? _notSharedMap;

  NotSharedStore([this._notSharedMap])
      : id = 'NotSharedStore#${++_notSharedIDCount}';

  @override
  SharedMap<K, V>? getSharedMap<K, V>(
    String id, {
    SharedMapEventCallback? onInitialize,
    SharedMapKeyCallback<K, V>? onAbsent,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    final notSharedMap = _notSharedMap;
    var o = notSharedMap?.id == id
        ? notSharedMap as SharedMap<K, V>
        : NotSharedMap<K, V>();

    o.setCallbacksDynamic<K, V>(
        onInitialize: onInitialize,
        onAbsent: onAbsent,
        onPut: onPut,
        onRemove: onRemove);

    return o;
  }

  NotSharedStoreReference? _sharedReference;

  @override
  SharedStoreReference sharedReference() =>
      _sharedReference ??= NotSharedStoreReference(this);

  @override
  O? getSharedObject<O extends ReferenceableType>(String id, {Type? t}) => null;

  @override
  R? getSharedObjectReference<O extends ReferenceableType,
          R extends SharedReference>(String id, {Type? t}) =>
      null;

  @override
  void registerSharedObject<O extends ReferenceableType>(O o) {
    if (o is SharedMap) {
      throw StateError("Can't register a `SharedMap`: $o");
    }
  }
}

/// NOT shared implementation of [SharedMap].
class NotSharedMap<K, V> implements SharedMapSync<K, V> {
  static int _notSharedIDCount = 0;

  @override
  final String id;

  @override
  late NotSharedStore sharedStore = NotSharedStore(this);

  final Map<K, V> _entries = {};

  NotSharedMap() : id = 'NotSharedMap#${++_notSharedIDCount}';

  @override
  SharedMapEventCallback? onInitialize;

  @override
  SharedMapKeyCallback<K, V>? onAbsent;

  @override
  SharedMapEntryCallback<K, V>? onPut;

  @override
  SharedMapEntryCallback<K, V>? onRemove;

  @override
  FutureOr<SharedMap<K, V>> setCallbacks(
      {SharedMapEventCallback? onInitialize,
      SharedMapKeyCallback<K, V>? onAbsent,
      SharedMapEntryCallback<K, V>? onPut,
      SharedMapEntryCallback<K, V>? onRemove}) {
    SharedMapEventCallback? callOnInitialize;
    if (onInitialize != null && this.onInitialize == null) {
      this.onInitialize = onInitialize;
      callOnInitialize = onInitialize;
    }

    if (onAbsent != null) {
      this.onAbsent ??= onAbsent;
    }

    if (onPut != null) {
      this.onPut ??= onPut;
    }

    if (onRemove != null) {
      this.onRemove ??= onRemove;
    }

    if (callOnInitialize != null) {
      var r = callOnInitialize(this);
      if (r is Future) {
        return r.then((_) => this);
      }
    }

    return this;
  }

  @override
  FutureOr<SharedMap<K1, V1>> setCallbacksDynamic<K1, V1>(
      {SharedMapEventCallback? onInitialize,
      SharedMapKeyCallback<K1, V1>? onAbsent,
      SharedMapEntryCallback<K1, V1>? onPut,
      SharedMapEntryCallback<K1, V1>? onRemove}) {
    SharedMapEventCallback? callOnInitialize;
    if (onInitialize != null && this.onInitialize == null) {
      this.onInitialize = onInitialize;
      callOnInitialize = onInitialize;
    }

    if (onAbsent is SharedMapKeyCallback<K, V>) {
      this.onAbsent ??= onAbsent as SharedMapKeyCallback<K, V>;
    }

    if (onPut is SharedMapEntryCallback<K, V>) {
      this.onPut ??= onPut as SharedMapEntryCallback<K, V>;
    }

    if (onRemove is SharedMapEntryCallback<K, V>) {
      this.onRemove ??= onRemove as SharedMapEntryCallback<K, V>;
    }

    if (callOnInitialize != null) {
      var r = callOnInitialize(this);
      if (r is Future) {
        return r.then((_) => this as SharedMap<K1, V1>);
      }
    }

    return this as SharedMap<K1, V1>;
  }

  late final _NotSharedMapCache<K, V> _cached = _NotSharedMapCache(this);

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) => _cached;

  @override
  V? get(K key) {
    var value = _entries[key];

    if (value == null) {
      var onAbsent = this.onAbsent;
      if (onAbsent != null) {
        value = onAbsent(key);
        if (value != null) {
          _entries[key] = value;
        }
      }
    }

    return value;
  }

  @override
  List<K> keys() => _entries.keys.toList();

  @override
  List<V> values() => _entries.values.toList();

  @override
  List<MapEntry<K, V>> entries() => _entries.entries.toList();

  @override
  List<MapEntry<K, V>> where(bool Function(K key, V value) test) =>
      _entries.entries.where((e) => test(e.key, e.value)).toList();

  @override
  int length() => _entries.length;

  @override
  FutureOr<V?> put(K key, V? value) {
    if (value == null) {
      _entries.remove(key);
      return null;
    }

    _entries[key] = value;

    return onPut.callback(key, value);
  }

  @override
  FutureOr<V?> putIfAbsent(K key, V? absentValue) {
    var prev = _entries[key];

    if (prev == null) {
      var onAbsent = this.onAbsent;
      if (onAbsent != null) {
        prev = onAbsent(key);
        if (prev != null) {
          _entries[key] = prev;
        }
      }
    }

    if (prev == null) {
      if (absentValue == null) {
        return null;
      }

      _entries[key] = absentValue;

      return onPut.callback(key, absentValue);
    } else {
      return prev;
    }
  }

  @override
  FutureOr<V?> update(K key, SharedMapUpdater<K, V> updater) {
    var prev = _entries[key];

    if (prev == null) {
      var onAbsent = this.onAbsent;
      if (onAbsent != null) {
        prev = onAbsent(key);
        if (prev != null) {
          _entries[key] = prev;
        }
      }
    }

    var value = updater(key, prev);
    return put(key, value);
  }

  @override
  FutureOr<V?> remove(K key) {
    var v = _entries.remove(key);

    if (v == null) {
      var onAbsent = this.onAbsent;
      if (onAbsent != null) {
        v = onAbsent(key);
      }
    }

    if (v != null) {
      return onRemove.callback(key, v);
    }

    return v;
  }

  @override
  FutureOr<List<V?>> removeAll(List<K> keys) {
    var list = keys.map(remove).toList();

    if (list.every((e) => e is! Future)) {
      return list.cast<V?>();
    }

    var futures = list.map((e) => e is Future<V?> ? e : Future<V?>.value(e));

    return Future.wait(futures);
  }

  @override
  int clear() {
    var lng = _entries.length;

    List<MapEntry<K, V>>? removedEntries;

    final onRemove = this.onRemove;
    if (onRemove != null) {
      removedEntries = _entries.entries.toList();
    }

    _entries.clear();

    if (removedEntries != null) {
      onRemove!.callbackAll(removedEntries);
    }

    return lng;
  }

  NotSharedMapReference? _sharedReference;

  @override
  SharedMapReference sharedReference() =>
      _sharedReference ??= NotSharedMapReference(this);

  @override
  String toString() {
    return 'NotSharedMap<$K,$V>[$id@${sharedStore.id}]{entries: ${_entries.length}}';
  }
}

class NotSharedStoreReference extends SharedStoreReference {
  final NotSharedStore notSharedStore;

  NotSharedStoreReference(this.notSharedStore) : super(notSharedStore.id);
}

class NotSharedMapReference extends SharedMapReference {
  final NotSharedMap notSharedMap;

  NotSharedMapReference(this.notSharedMap)
      : super(notSharedMap.id, notSharedMap.sharedStore.sharedReference());
}

class _NotSharedMapCache<K, V> implements SharedMapCached<K, V> {
  final NotSharedMap<K, V> _sharedMap;
  @override
  final Duration timeout;

  _NotSharedMapCache(this._sharedMap) : timeout = Duration.zero;

  @override
  SharedMapEventCallback? get onInitialize => _sharedMap.onInitialize;

  @override
  set onInitialize(SharedMapEventCallback? callback) =>
      _sharedMap.onInitialize = callback;

  @override
  SharedMapKeyCallback<K, V>? get onAbsent => _sharedMap.onAbsent;

  @override
  set onAbsent(SharedMapKeyCallback<K, V>? callback) =>
      _sharedMap.onAbsent = callback;

  @override
  SharedMapEntryCallback<K, V>? get onPut => _sharedMap.onPut;

  @override
  set onPut(SharedMapEntryCallback<K, V>? callback) =>
      _sharedMap.onPut = callback;

  @override
  SharedMapEntryCallback<K, V>? get onRemove => _sharedMap.onRemove;

  @override
  set onRemove(SharedMapEntryCallback<K, V>? callback) =>
      _sharedMap.onRemove = callback;

  @override
  FutureOr<SharedMap<K, V>> setCallbacks(
          {SharedMapEventCallback? onInitialize,
          SharedMapKeyCallback<K, V>? onAbsent,
          SharedMapEntryCallback<K, V>? onPut,
          SharedMapEntryCallback<K, V>? onRemove}) =>
      _sharedMap.setCallbacks(
          onInitialize: onInitialize,
          onAbsent: onAbsent,
          onPut: onPut,
          onRemove: onRemove);

  @override
  FutureOr<SharedMap<K1, V1>> setCallbacksDynamic<K1, V1>(
          {SharedMapEventCallback? onInitialize,
          SharedMapKeyCallback<K1, V1>? onAbsent,
          SharedMapEntryCallback<K1, V1>? onPut,
          SharedMapEntryCallback<K1, V1>? onRemove}) =>
      _sharedMap.setCallbacksDynamic(
          onInitialize: onInitialize,
          onAbsent: onAbsent,
          onPut: onPut,
          onRemove: onRemove);

  @override
  String get id => _sharedMap.id;

  @override
  SharedStore get sharedStore => _sharedMap.sharedStore;

  @override
  Map<K, V> get cachedEntries => {};

  @override
  void clearCache() {}

  @override
  V? get(K key, {Duration? timeout, bool refresh = false}) =>
      _sharedMap.get(key);

  @override
  FutureOr<V?> put(K key, V? value) => _sharedMap.put(key, value);

  @override
  FutureOr<V?> putIfAbsent(K key, V? absentValue) =>
      _sharedMap.putIfAbsent(key, absentValue);

  @override
  FutureOr<V?> update(K key, SharedMapUpdater<K, V> updater) =>
      _sharedMap.update(key, updater);

  @override
  V? removeFromCache(K key) => null;

  @override
  FutureOr<V?> remove(K key) => _sharedMap.remove(key);

  @override
  FutureOr<List<V?>> removeAll(List<K> keys) => _sharedMap.removeAll(keys);

  @override
  SharedMapReference sharedReference() => _sharedMap.sharedReference();

  @override
  List<K> keys({Duration? timeout, bool refresh = false}) => _sharedMap.keys();

  @override
  List<V> values({Duration? timeout, bool refresh = false}) =>
      _sharedMap.values();

  @override
  List<MapEntry<K, V>> entries({Duration? timeout, bool refresh = false}) =>
      _sharedMap.entries();

  @override
  List<MapEntry<K, V>> where(bool Function(K key, V value) test) =>
      _sharedMap.where(test);

  @override
  int length({Duration? timeout, bool refresh = false}) => _sharedMap.length();

  @override
  int clear() => _sharedMap.clear();

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) => this;

  @override
  String toString() =>
      'SharedMapCachedGeneric[$id@${sharedStore.id}]{timeout: $timeout}->$_sharedMap';
}

class NotSharedStoreField extends NotSharedObject implements SharedStoreField {
  final NotSharedStore _notSharedStore;

  NotSharedStoreField(this._notSharedStore);

  @override
  SharedStore get sharedStore => _notSharedStore;

  @override
  String get sharedStoreID => _notSharedStore.id;

  @override
  String get runtimeTypeName => 'NotSharedStoreField';

  @override
  SharedStore get sharedObject => sharedStore;

  @override
  SharedStore get sharedObjectAsync => sharedStore;

  @override
  bool get isResolvingReference => false;

  @override
  String get sharedObjectID => sharedStoreID;

  @override
  SharedStoreReference get sharedReference => _notSharedStore.sharedReference();

  @override
  SharedFieldInstanceHandler<SharedStoreReference, SharedStore,
          SharedStoreField>
      get instanceHandler => throw UnsupportedError(
          "A `NotSharedStoreField` doesn't have an `instanceHandler`");
}

class NotSharedMapField<K, V> extends NotSharedObject
    implements SharedMapField<K, V> {
  final NotSharedMap<K, V> _notSharedMap;

  NotSharedMapField(this._notSharedMap);

  @override
  String get runtimeTypeName => 'NotSharedMapField';

  @override
  SharedMap<K, V> get sharedObject => sharedMap;

  @override
  SharedMap<K, V> get sharedObjectAsync => sharedMap;

  @override
  bool get isResolvingReference => false;

  @override
  String get sharedObjectID => sharedMapID;

  @override
  SharedMapReference get sharedReference => sharedMap.sharedReference();

  @override
  String get sharedMapID => _notSharedMap.id;

  @override
  NotSharedStore get sharedStore => _notSharedMap.sharedStore;

  @override
  SharedMap<K, V> get sharedMap => _notSharedMap;

  @override
  SharedMap<K, V> get sharedMapAsync => _notSharedMap;

  @override
  SharedMap<K, V> sharedMapCached({Duration? timeout}) =>
      _notSharedMap.cached();

  @override
  SharedFieldInstanceHandler<SharedMapReference, SharedMap<K, V>,
          SharedMapField<K, V>>
      get instanceHandler => throw UnsupportedError(
          "A `NotSharedMapField` doesn't have an `instanceHandler`");
}
