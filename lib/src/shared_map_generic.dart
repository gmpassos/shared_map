import 'dart:async';

import 'shared_map_base.dart';
import 'shared_map_cached.dart';

class SharedStoreGeneric implements SharedStore {
  static final Map<String, WeakReference<SharedStoreGeneric>> _instances = {};

  @override
  final String id;

  SharedStoreGeneric(this.id) {
    _instances[id] = WeakReference(this);
  }

  final Map<String, SharedMapGeneric> _sharedMaps = {};

  @override
  FutureOr<SharedMap<K, V>?> getSharedMap<K, V>(String id) {
    return createSharedMap(sharedStore: this, id: id);
  }

  @override
  SharedStoreReference sharedReference() => SharedStoreReferenceGeneric(id);

  @override
  String toString() =>
      'SharedStoreGeneric[$id]{sharedMaps: ${_sharedMaps.length}}';
}

class SharedMapGeneric<K, V> implements SharedMap<K, V> {
  @override
  final SharedStore sharedStore;

  @override
  final String id;

  final Map<K, V?> _entries;

  SharedMapGeneric(this.sharedStore, this.id) : _entries = {};

  @override
  FutureOr<V?> get(K key) {
    return _entries[key];
  }

  @override
  FutureOr<V?> put(K key, V? value) {
    return _entries[key] = value;
  }

  @override
  FutureOr<V?> putIfAbsent(K key, V? absentValue) {
    var prev = _entries[key];
    if (prev == null) {
      return _entries[key] = absentValue;
    } else {
      return prev;
    }
  }

  @override
  SharedMapReference sharedReference() =>
      SharedMapReferenceGeneric(id, sharedStore.sharedReference());

  SharedMapCached<K, V>? _cached;

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) =>
      _cached ??= SharedMapCached<K, V>(this, timeout: timeout);
}

class SharedMapCacheGeneric<K, V> implements SharedMapCached<K, V> {
  final SharedMap<K, V> _sharedMap;
  @override
  final Duration timeout;

  SharedMapCacheGeneric(this._sharedMap,
      {Duration? timeout = const Duration(seconds: 1)})
      : timeout = const Duration(seconds: 1);

  @override
  String get id => _sharedMap.id;

  @override
  SharedStore get sharedStore => _sharedMap.sharedStore;

  @override
  Map<K, V> get cachedEntries => {};

  @override
  void clearCache() {}

  @override
  FutureOr<V?> get(K key, {Duration? timeout, bool refresh = false}) =>
      _sharedMap.get(key);

  @override
  FutureOr<V?> put(K key, V? value) => _sharedMap.put(key, value);

  @override
  FutureOr<V?> putIfAbsent(K key, V? absentValue) =>
      _sharedMap.putIfAbsent(key, absentValue);

  @override
  SharedMapReference sharedReference() => _sharedMap.sharedReference();

  SharedMapCacheGeneric<K, V>? _cached;

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) =>
      _cached ??= SharedMapCacheGeneric(this, timeout: timeout);

  @override
  String toString() =>
      'SharedMapCachedGeneric[$id@${sharedStore.id}]{timeout: $timeout}->$_sharedMap';
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
    id ??= sharedReference.id;
  }

  var prev = SharedStoreGeneric._instances[id!]?.target;
  if (prev != null) return prev;

  return SharedStoreGeneric(id);
}

SharedMap<K, V> createSharedMap<K, V>(
    {SharedStore? sharedStore,
    String? id,
    SharedMapReference? sharedReference}) {
  if (sharedReference != null) {
    sharedStore ??= SharedStoreGeneric
        ._instances[sharedReference.sharedStoreReference.id]?.target;
    id ??= sharedReference.id;
  }

  if (sharedStore is! SharedStoreGeneric) {
    throw StateError("`sharedStore` not a `SharedStoreGeneric`: $sharedStore");
  }

  var prev = sharedStore._sharedMaps[id];
  if (prev != null) return prev as SharedMap<K, V>;

  var sharedMap = SharedMapGeneric<K, V>(sharedStore, id!);
  sharedStore._sharedMaps[id] = sharedMap;
  return sharedMap;
}
