import 'not_shared_map.dart';
import 'shared_map_base.dart';
import 'shared_map_cached.dart';
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
  SharedMap<K, V>? getSharedMap<K, V>(
    String id, {
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    var o = createSharedMap<K, V>(sharedStore: this, id: id);
    o.setCallbacksDynamic<K, V>(onPut: onPut, onRemove: onRemove);
    return o;
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
  SharedMapEntryCallback<K, V>? onPut;

  @override
  SharedMapEntryCallback<K, V>? onRemove;

  @override
  void setCallbacks(
      {SharedMapEntryCallback<K, V>? onPut,
      SharedMapEntryCallback<K, V>? onRemove}) {
    if (onPut != null) {
      this.onPut ??= onPut;
    }

    if (onRemove != null) {
      this.onRemove ??= onRemove;
    }
  }

  @override
  void setCallbacksDynamic<K1, V1>(
      {SharedMapEntryCallback<K1, V1>? onPut,
      SharedMapEntryCallback<K1, V1>? onRemove}) {
    if (onPut is SharedMapEntryCallback<K, V>) {
      this.onPut ??= onPut as SharedMapEntryCallback<K, V>;
    }

    if (onRemove is SharedMapEntryCallback<K, V>) {
      this.onRemove ??= onRemove as SharedMapEntryCallback<K, V>;
    }
  }

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

    onPut.callback(key, value);

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

      onPut.callback(key, absentValue);

      return absentValue;
    } else {
      return prev;
    }
  }

  @override
  V? remove(K key) {
    var v = _entries.remove(key);
    if (v != null) {
      onRemove.callback(key, v);
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
  void setCallbacks(
          {SharedMapEntryCallback<K, V>? onPut,
          SharedMapEntryCallback<K, V>? onRemove}) =>
      _sharedMap.setCallbacks(onPut: onPut, onRemove: onRemove);

  @override
  void setCallbacksDynamic<K1, V1>(
          {SharedMapEntryCallback<K1, V1>? onPut,
          SharedMapEntryCallback<K1, V1>? onRemove}) =>
      _sharedMap.setCallbacksDynamic(onPut: onPut, onRemove: onRemove);

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

  if (sharedStore is! SharedStoreGeneric) {
    throw StateError("`sharedStore` not a `SharedStoreGeneric`: $sharedStore");
  }

  var prev = sharedStore._sharedMaps[id];
  if (prev != null) return prev as SharedMap<K, V>;

  var sharedMap = SharedMapGeneric<K, V>(sharedStore, id!);
  sharedStore._sharedMaps[id] = sharedMap;
  return sharedMap;
}
