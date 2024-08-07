import 'dart:async';

import 'not_shared_map.dart';
import 'shared_map_base.dart';
import 'shared_map_cached.dart';
import 'shared_reference.dart';
import 'utils.dart';

class SharedStoreGeneric implements SharedStore {
  static final Map<String, WeakReference<SharedStoreGeneric>> _instances = {};

  @override
  final String id;

  SharedStoreGeneric._(this.id) {
    _instances[id] = WeakReference(this);
  }

  factory SharedStoreGeneric(String id) {
    var prev = SharedStoreGeneric._instances[id]?.target;
    if (prev != null) return prev;

    return SharedStoreGeneric._(id);
  }

  factory SharedStoreGeneric.from(
      {SharedStoreReference? reference, String? id}) {
    if (reference != null) {
      return SharedStoreGeneric(reference.id);
    }

    if (id != null) {
      return SharedStoreGeneric(id);
    }

    throw MultiNullArguments(['reference', 'id']);
  }

  final Map<String, SharedMapGeneric> _sharedMaps = {};

  @override
  SharedMap<K, V> getSharedMap<K, V>(
    String id, {
    SharedMapEventCallback? onInitialize,
    SharedMapKeyCallback<K, V>? onAbsent,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    var prev = _sharedMaps[id];
    if (prev != null) {
      return prev as SharedMap<K, V>;
    }

    var o = createSharedMap<K, V>(sharedStore: this, id: id);

    o.setCallbacksDynamic<K, V>(
        onInitialize: onInitialize,
        onAbsent: onAbsent,
        onPut: onPut,
        onRemove: onRemove);

    return o;
  }

  final Map<Type, Map<String, WeakReference<ReferenceableType>>>
      _typesSharedObjects = {};

  @override
  O? getSharedObject<O extends ReferenceableType>(String id, {Type? t}) {
    t ??= O;

    var sharedObjects = _typesSharedObjects[t];
    if (sharedObjects == null || sharedObjects.isEmpty) return null;

    var ref = sharedObjects[id];

    if (ref != null) {
      var prev = ref.target;
      if (prev == null) {
        sharedObjects.remove(id);
      } else {
        return prev as O;
      }
    }

    return null;
  }

  @override
  FutureOr<R?> getSharedObjectReference<O extends ReferenceableType,
      R extends SharedReference>(String id, {Type? t}) {
    t ??= O;
    var o = getSharedObject(id, t: t);
    return o?.sharedReference() as R?;
  }

  @override
  void registerSharedObject<O extends ReferenceableType>(O o) {
    if (o is SharedMap) {
      throw StateError("Can't register a `SharedMap`: $o");
    }

    var sharedObjects = _typesSharedObjects[O] ??= <String, WeakReference<O>>{};

    var id = o.id;

    var ref = sharedObjects[id];
    if (ref != null) {
      var prev = ref.target;
      if (prev == null) {
        sharedObjects.remove(id);
      } else {
        if (identical(prev, o)) {
          return;
        }

        throw StateError(
            "Shared object (`$O`) with id `$id` already registered: $prev != $o");
      }
    }

    sharedObjects[id] = WeakReference(o);
  }

  @override
  SharedStoreReference sharedReference() => SharedStoreReferenceGeneric(id);

  @override
  String toString() =>
      'SharedStoreGeneric[$id]{sharedMaps: ${_sharedMaps.length}}';
}

class SharedMapGeneric<K, V> implements SharedMapSync<K, V> {
  @override
  final SharedStore sharedStore;

  @override
  final String id;

  final Map<K, V> _entries = {};

  SharedMapGeneric(this.sharedStore, this.id);

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
  FutureOr<V?> put(K key, V? value) {
    if (value == null) {
      remove(key);
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

  @override
  SharedMapReference sharedReference() =>
      SharedMapReferenceGeneric(id, sharedStore.sharedReference());

  late final SharedMapCached<K, V> _cached = SharedMapCacheGeneric<K, V>(this);

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) => _cached;

  @override
  String toString() {
    return 'SharedMapGeneric<$K,$V>[$id@${sharedStore.id}]{entries: ${_entries.length}}';
  }
}

/// A fake implementation (not cached) of [SharedMapCached].
class SharedMapCacheGeneric<K, V> implements SharedMapCached<K, V> {
  final SharedMapSync<K, V> _sharedMap;
  @override
  final Duration timeout;

  SharedMapCacheGeneric(this._sharedMap) : timeout = Duration.zero;

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
      'SharedMapCachedGeneric<$K,$V>[$id@${sharedStore.id}]{timeout: $timeout}->$_sharedMap';
}

class SharedStoreReferenceGeneric extends SharedStoreReference {
  SharedStoreReferenceGeneric(super.id);

  SharedStoreReferenceGeneric.fromJson(Map<String, dynamic> json)
      : this(json['id']);
}

class SharedMapReferenceGeneric extends SharedMapReference {
  SharedMapReferenceGeneric(super.id, super.sharedStoreReference);

  SharedMapReferenceGeneric.fromJson(Map<String, dynamic> json)
      : this(json['id'],
            SharedStoreReferenceGeneric.fromJson(json['sharedStore']));
}

SharedStoreReference createSharedStoreReference({Map<String, dynamic>? json}) {
  return SharedStoreReferenceGeneric(json!['id']);
}

SharedMapReference createSharedMapReference({Map<String, dynamic>? json}) {
  return SharedMapReferenceGeneric(
      json!['id'], SharedStoreReferenceGeneric.fromJson(json['sharedStore']));
}

SharedStore createSharedStore(
    {String? id, SharedStoreReference? sharedReference}) {
  if (sharedReference != null) {
    if (sharedReference is NotSharedStoreReference) {
      return sharedReference.notSharedStore;
    }

    id ??= sharedReference.id;
  }

  return SharedStoreGeneric(id!);
}

SharedMap<K, V> createSharedMap<K, V>(
    {SharedStore? sharedStore,
    String? id,
    SharedMapReference? sharedReference}) {
  if (sharedReference != null) {
    if (sharedReference is NotSharedMapReference) {
      return sharedReference.notSharedMap as SharedMap<K, V>;
    }

    sharedStore ??= SharedStoreGeneric
        ._instances[sharedReference.sharedStoreReference.id]?.target;

    id ??= sharedReference.id;
  }

  if (id == null) {
    throw ArgumentError.notNull('id');
  }

  if (sharedStore == null) {
    throw ArgumentError.notNull('sharedStore');
  }

  if (sharedStore is NotSharedStore) {
    return sharedStore.getSharedMap<K, V>(id)!;
  }

  if (sharedStore is! SharedStoreGeneric) {
    throw StateError("`sharedStore` not a `SharedStoreGeneric`: $sharedStore");
  }

  var prev = sharedStore._sharedMaps[id];
  if (prev != null) return prev as SharedMap<K, V>;

  var sharedMap = SharedMapGeneric<K, V>(sharedStore, id);
  sharedStore._sharedMaps[id] = sharedMap;
  return sharedMap;
}

FutureOr<SharedMap<K, V>> createSharedMapAsync<K, V>(
        {SharedStore? sharedStore,
        String? id,
        SharedMapReference? sharedReference}) =>
    createSharedMap(
        sharedStore: sharedStore, id: id, sharedReference: sharedReference);
