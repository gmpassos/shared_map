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
  SharedMap<K, V>? getSharedMap<K, V>(String id) {
    final notSharedMap = _notSharedMap;
    return notSharedMap?.id == id
        ? notSharedMap as SharedMap<K, V>
        : NotSharedMap<K, V>();
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
  int length() => _entries.length;

  @override
  V? put(K key, V? value) {
    if (value == null) {
      _entries.remove(key);
      return null;
    }
    return _entries[key] = value;
  }

  @override
  V? putIfAbsent(K key, V? absentValue) {
    var prev = _entries[key];
    if (prev == null) {
      if (absentValue == null) {
        return null;
      }
      return _entries[key] = absentValue;
    } else {
      return prev;
    }
  }

  @override
  V? remove(K key) => _entries.remove(key);

  @override
  List<V?> removeAll(List<K> keys) {
    var values = keys.map((k) => _entries.remove(k)).toList();
    return values;
  }

  @override
  int clear() {
    var lng = _entries.length;
    _entries.clear();
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
