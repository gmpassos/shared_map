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

class SharedMapGeneric<K, V> implements SharedMapSync<K, V> {
  @override
  final SharedStore sharedStore;

  @override
  final String id;

  final Map<K, V> _entries = {};

  SharedMapGeneric(this.sharedStore, this.id);

  @override
  OnSharedMapPut<K, V>? onSharedMapPut;

  @override
  OnSharedMapRemove<K, V>? onSharedMapRemove;

  @override
  V? get(K key) {
    return _entries[key];
  }

  @override
  V? put(K key, V? value) {
    if (value == null) {
      remove(key);
      return null;
    }

    _entries[key] = value;

    final onSharedMapPut = this.onSharedMapPut;
    if (onSharedMapPut != null) {
      onSharedMapPut(key, value);
    }

    return value;
  }

  @override
  V? putIfAbsent(K key, V? absentValue) {
    var prev = _entries[key];
    if (prev == null) {
      if (absentValue == null) {
        return null;
      }

      _entries[key] = absentValue;

      final onSharedMapPut = this.onSharedMapPut;
      if (onSharedMapPut != null) {
        onSharedMapPut(key, absentValue);
      }

      return absentValue;
    } else {
      return prev;
    }
  }

  @override
  V? remove(K key) {
    var v = _entries.remove(key);
    if (v != null) {
      final onSharedMapRemove = this.onSharedMapRemove;
      if (onSharedMapRemove != null) {
        onSharedMapRemove(key, v);
      }
    }
    return v;
  }

  @override
  List<V?> removeAll(List<K> keys) =>
      keys.map((k) => _entries.remove(k)).toList();

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

    final onSharedMapRemove = this.onSharedMapRemove;
    if (onSharedMapRemove != null) {
      removedEntries = _entries.entries.toList();
    }

    _entries.clear();

    if (onSharedMapRemove != null) {
      for (var e in removedEntries!) {
        onSharedMapRemove(e.key, e.value);
      }
    }

    return lng;
  }

  @override
  SharedMapReference sharedReference() =>
      SharedMapReferenceGeneric(id, sharedStore.sharedReference());

  late final SharedMapCached<K, V> _cached = SharedMapCacheGeneric<K, V>(this);

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) => _cached;
}

/// A fake implementation (not cached) of [SharedMapCached].
class SharedMapCacheGeneric<K, V> implements SharedMapCached<K, V> {
  final SharedMapSync<K, V> _sharedMap;
  @override
  final Duration timeout;

  SharedMapCacheGeneric(this._sharedMap) : timeout = Duration.zero;

  @override
  OnSharedMapPut<K, V>? get onSharedMapPut => _sharedMap.onSharedMapPut;

  @override
  set onSharedMapPut(OnSharedMapPut<K, V>? callback) =>
      _sharedMap.onSharedMapPut = callback;

  @override
  OnSharedMapRemove<K, V>? get onSharedMapRemove =>
      _sharedMap.onSharedMapRemove;

  @override
  set onSharedMapRemove(OnSharedMapRemove<K, V>? callback) =>
      _sharedMap.onSharedMapRemove = callback;

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
  V? put(K key, V? value) => _sharedMap.put(key, value);

  @override
  V? putIfAbsent(K key, V? absentValue) =>
      _sharedMap.putIfAbsent(key, absentValue);

  @override
  V? remove(K key) => _sharedMap.remove(key);

  @override
  List<V?> removeAll(List<K> keys) => _sharedMap.removeAll(keys);

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
