import 'shared_map_base.dart';
import 'shared_map_cached.dart';

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
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    final notSharedMap = _notSharedMap;
    var o = notSharedMap?.id == id
        ? notSharedMap as SharedMap<K, V>
        : NotSharedMap<K, V>();

    o.setCallbacksDynamic<K, V>(onPut: onPut, onRemove: onRemove);

    return o;
  }

  NotSharedStoreReference? _sharedReference;

  @override
  SharedStoreReference sharedReference() =>
      _sharedReference ??= NotSharedStoreReference(this);
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

  late final _NotSharedMapCache<K, V> _cached = _NotSharedMapCache(this);

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) => _cached;

  @override
  V? get(K key) => _entries[key];

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
  V? put(K key, V? value) {
    if (value == null) {
      _entries.remove(key);
      return null;
    }

    _entries[key] = value;

    final onPut = this.onPut;
    if (onPut != null) {
      onPut(key, value);
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

      final onPut = this.onPut;
      if (onPut != null) {
        onPut(key, absentValue);
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
      final onRemove = this.onRemove;
      if (onRemove != null) {
        onRemove(key, v);
      }
    }
    return v;
  }

  @override
  List<V?> removeAll(List<K> keys) {
    var values = keys.map((k) => _entries.remove(k)).toList();
    return values;
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

    if (onRemove != null) {
      for (var e in removedEntries!) {
        onRemove(e.key, e.value);
      }
    }

    return lng;
  }

  NotSharedMapReference? _sharedReference;

  @override
  SharedMapReference sharedReference() =>
      _sharedReference ??= NotSharedMapReference(this);
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
      'SharedMapCachedGeneric[$id@${sharedStore.id}]{timeout: $timeout}->$_sharedMap';
}

class NotSharedStoreField extends SharedObject implements SharedStoreField {
  final NotSharedStore _notSharedStore;

  NotSharedStoreField(this._notSharedStore);

  @override
  SharedStore get sharedStore => _notSharedStore;

  @override
  String get sharedStoreID => _notSharedStore.id;
}

class NotSharedMapField<K, V> extends SharedObject
    implements SharedMapField<K, V> {
  final NotSharedMap<K, V> _notSharedMap;

  NotSharedMapField(this._notSharedMap);

  @override
  String get sharedMapID => _notSharedMap.id;

  @override
  NotSharedStore get sharedStore => _notSharedMap.sharedStore;

  @override
  SharedMap<K, V> get sharedMap => _notSharedMap;

  @override
  SharedMap<K, V> get sharedMapSync => _notSharedMap;

  @override
  SharedMap<K, V>? get trySharedMapSync => _notSharedMap;

  @override
  SharedMap<K, V> sharedMapCached({Duration? timeout}) =>
      _notSharedMap.cached();
}
